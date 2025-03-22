import os
import re
import sys
import requests
from urllib.parse import urljoin

INVALID_FILENAME_CHARS = r'<>:"/\\|?*'

def sanitize_filename(name):
    return re.sub(f'[{re.escape(INVALID_FILENAME_CHARS)}]', '_', name)

def extract_curl_details(curl_parts):
    url, cookies, headers = None, {}, {}
    for i, part in enumerate(curl_parts):
        if part.startswith("http"):
            url = part.strip("'")
        elif part in ('-H', '--header') and i + 1 < len(curl_parts):
            header = curl_parts[i + 1].strip("'")
            if header.lower().startswith("cookie:"):
                cookies = dict(c.strip().split("=", 1) for c in header.split(": ", 1)[1].split("; "))
            else:
                key, value = header.split(": ", 1)
                headers[key] = value
    return url, cookies, headers

def get_child_pages(base_url, cookies, headers, parent_id):
    api_url = urljoin(base_url, f"rest/api/content/{parent_id}/child/page?expand=title")
    response = requests.get(api_url, cookies=cookies, headers=headers)
    if response.ok:
        return [(p['id'], p['title']) for p in response.json().get('results', [])]
    return []

def download_export(url, cookies, headers, output_path):
    response = requests.get(url, cookies=cookies, headers=headers, stream=True)
    if response.ok:
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(1024):
                f.write(chunk)
        print(f"Downloaded: {output_path}")

def crawl_and_download(base_url, page_id, page_title, cookies, headers):
    safe_title = sanitize_filename(page_title)
    os.makedirs(safe_title, exist_ok=True)
    pdf_url = urljoin(base_url, f"spaces/flyingpdf/pdfpageexport.action?pageId={page_id}")
    doc_url = urljoin(base_url, f"exportword?pageId={page_id}")
    
    download_export(pdf_url, cookies, headers, os.path.join(safe_title, f"{safe_title}.pdf"))
    download_export(doc_url, cookies, headers, os.path.join(safe_title, f"{safe_title}.doc"))
    
    for child_id, child_title in get_child_pages(base_url, cookies, headers, page_id):
        crawl_and_download(base_url, child_id, child_title, cookies, headers)

def extract_page_id(html):
    match = re.search(r'<meta name="ajs-page-id" content="(\d+)">', html)
    return match.group(1) if match else None

def main():
    if len(sys.argv) < 3:
        print("Usage: python script.py curl <CURL_ARGUMENTS>")
        sys.exit(1)

    curl_parts = sys.argv[2:]
    base_url, cookies, headers = extract_curl_details(curl_parts)
    if not base_url:
        print("Failed to extract base URL from curl command.")
        sys.exit(1)

    match = re.search(r'pageId=(\d+)', base_url)
    page_id = match.group(1) if match else None
    response = requests.get(base_url, cookies=cookies, headers=headers)
    if not response.ok:
        print(f"Failed to access page: {base_url} (Status: {response.status_code})")
        sys.exit(1)

    if not page_id:
        page_id = extract_page_id(response.text)
        if not page_id:
            print("Failed to extract page ID from URL or page source.")
            sys.exit(1)

    page_title_match = re.search(r'<title>(.*?)</title>', response.text, re.IGNORECASE)
    if not page_title_match:
        print("Failed to extract page title.")
        sys.exit(1)

    page_title = page_title_match.group(1).split(' - ')[0].strip()
    crawl_and_download(base_url, page_id, page_title, cookies, headers)

if __name__ == "__main__":
    main()
