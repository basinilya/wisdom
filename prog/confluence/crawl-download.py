import os
import re
import sys
import json
import subprocess
import requests
from urllib.parse import urljoin

# Characters forbidden on Windows
INVALID_FILENAME_CHARS = r'<>:"/\\|?*'


def sanitize_filename(name):
    return re.sub(f'[{re.escape(INVALID_FILENAME_CHARS)}]', '_', name)


def extract_curl_details(curl_cmd):
    """Extracts the URL and cookies from a curl command copied from browser dev tools."""
    curl_parts = curl_cmd.split()
    url = None
    cookies = {}
    headers = {}
    for i, part in enumerate(curl_parts):
        if part.startswith("'http") or part.startswith('"http'):
            url = part.strip("'")
        elif part in ('-H', '--header') and i + 1 < len(curl_parts):
            header = curl_parts[i + 1].strip("'")
            if header.lower().startswith("cookie:"):
                cookie_str = header.split(": ", 1)[1]
                cookies = {k.strip(): v for k, v in (c.split("=") for c in cookie_str.split("; "))}
            else:
                key, value = header.split(": ", 1)
                headers[key] = value
    return url, cookies, headers


def get_child_pages(base_url, cookies, headers, parent_id):
    """Fetches child pages from the Confluence REST API."""
    api_url = urljoin(base_url, f"rest/api/content/{parent_id}/child/page?expand=title")
    response = requests.get(api_url, cookies=cookies, headers=headers)
    if response.status_code == 200:
        data = response.json()
        return [(p['id'], p['title']) for p in data.get('results', [])]
    return []


def download_export(url, cookies, headers, output_path):
    """Downloads the exported file from the given URL."""
    response = requests.get(url, cookies=cookies, headers=headers, stream=True)
    if response.status_code == 200:
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(1024):
                f.write(chunk)
        print(f"Downloaded: {output_path}")
    else:
        print(f"Failed to download: {url} (Status: {response.status_code})")


def crawl_and_download(base_url, page_id, page_title, cookies, headers):
    """Recursively crawls and downloads PDFs and DOCs for the given page and its children."""
    safe_title = sanitize_filename(page_title)
    os.makedirs(safe_title, exist_ok=True)
    pdf_url = urljoin(base_url, f"spaces/flyingpdf/pdfpageexport.action?pageId={page_id}")
    doc_url = urljoin(base_url, f"exportword?pageId={page_id}")
    
    download_export(pdf_url, cookies, headers, os.path.join(safe_title, f"{safe_title}.pdf"))
    download_export(doc_url, cookies, headers, os.path.join(safe_title, f"{safe_title}.doc"))
    
    # Get child pages and recurse
    for child_id, child_title in get_child_pages(base_url, cookies, headers, page_id):
        crawl_and_download(base_url, child_id, child_title, cookies, headers)


def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py '<CURL_COMMAND>'")
        sys.exit(1)

    curl_cmd = sys.argv[1]
    base_url, cookies, headers = extract_curl_details(curl_cmd)
    if not base_url:
        print("Failed to extract base URL from curl command.")
        sys.exit(1)

    match = re.search(r'pageId=(\d+)', base_url)
    if not match:
        print("Failed to extract page ID from URL.")
        sys.exit(1)

    page_id = match.group(1)
    response = requests.get(base_url, cookies=cookies, headers=headers)
    if response.status_code != 200:
        print(f"Failed to access page: {base_url} (Status: {response.status_code})")
        sys.exit(1)

    page_title_match = re.search(r'<title>(.*?)</title>', response.text, re.IGNORECASE)
    if not page_title_match:
        print("Failed to extract page title.")
        sys.exit(1)

    page_title = page_title_match.group(1).split(' - ')[0].strip()
    crawl_and_download(base_url, page_id, page_title, cookies, headers)


if __name__ == "__main__":
    main()
