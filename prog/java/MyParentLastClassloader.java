package org.foo;

import java.io.IOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.Enumeration;
import java.util.NoSuchElementException;

public class MyParentLastClassloader extends URLClassLoader {

    private final String dbgName;

    public MyParentLastClassloader(URL[] urls, ClassLoader parent, String name) {
        super(urls, parent);
        this.dbgName = name;
    }

    @Override
    public String toString() {
        return getDbgName();
    }

    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {

        synchronized (getClassLoadingLock(name)) {
            // First, check if the class has already been loaded
            Class<?> c = findLoadedClass(name);
            if (c == null) {
                try {
                    c = findClass(name);
                } catch (ClassNotFoundException e) {
                    // ignore
                }

                if (c == null) {
                    // If still not found
                    ClassLoader parent = getParent();
                    if (parent == null) {
                        parent = BOOTSTRAP_CL;
                    }
                    c = parent.loadClass(name);
                }
            }
            if (resolve) {
                resolveClass(c);
            }
            return c;
        }
    }

    @Override
    public URL getResource(final String name) {
        URL url;
        url = findResource(name);
        if (url == null) {
            ClassLoader parent = getParent();
            if (parent == null) {
                parent = BOOTSTRAP_CL;
            }
            url = parent.getResource(name);
        }
        return url;
    }

    @Override
    public Enumeration<URL> getResources(final String name) throws IOException {
        ClassLoader parent = getParent();
        if (parent == null) {
            parent = BOOTSTRAP_CL;
        }

        final Enumeration<URL> tmp0 = findResources(name);
        final Enumeration<URL> tmp1 = parent.getResources(name);

        return new MyEnumeration(tmp0, tmp1);
    }

    private static final ClassLoader BOOTSTRAP_CL = new URLClassLoader(new URL[0], null);

    public String getDbgName() {
        return dbgName;
    }

}

class MyEnumeration implements Enumeration<URL> {

    @SafeVarargs
    MyEnumeration(Enumeration<URL>... enus) {
        this.enus = enus;
    }

    int index;

    Enumeration<URL>[] enus;

    @Override
    public boolean hasMoreElements() {
        for (; index < enus.length; index++) {
            if (enus[index] != null && enus[index].hasMoreElements()) {
                return true;
            }
        }
        return false;
    }

    @Override
    public URL nextElement() {
        hasMoreElements();
        if (index >= enus.length) {
            throw new NoSuchElementException();
        }
        return enus[index].nextElement();
    }
}
