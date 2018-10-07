// printclasspath

package org.foo;

import java.io.PrintWriter;
import java.net.URLClassLoader;
import java.util.Arrays;

public class PrintClassloaders {
    
    private static void log(final PrintWriter pw, final Object _o) {
        final String o = "" + _o;
        pw.println(o);
    }
    
    public static void printClassloader(final PrintWriter pw, final Class clazz) throws Exception {
        log(pw, "classloader hierarchy for " + clazz);
        printClassloader0(pw, clazz.getClassLoader());
        log(pw, "");
        log(pw, "");
    }
    
    private static void printClassloader0(final PrintWriter pw, final ClassLoader cl)
            throws Exception {
        log(pw, cl);
        if (cl instanceof URLClassLoader) {
            final URLClassLoader ucl = (URLClassLoader) cl;
            log(pw, Arrays.asList(ucl.getURLs()));
        } else {
            //
        }
        final ClassLoader parent = cl.getParent();
        if (parent != null && parent != cl) {
            printClassloader0(pw, parent);
        }
    }
}
