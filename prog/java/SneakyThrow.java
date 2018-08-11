import java.io.IOException;

public class SneakyThrow
{

    public static void main( String[] args )
    {
        sneakyThrow( new IOException("nope") );
    }

    /**
     * Throw even checked exceptions without being required
     * to declare them or catch them. Suggested idiom:
     * throw sneakyThrow( some exception );
     */
    public static RuntimeException sneakyThrow(Throwable t) {
        // http://www.mail-archive.com/javaposse@googlegroups.com/msg05984.html
        if (t == null)
            throw new NullPointerException();
        throw SneakyThrow.<RuntimeException>sneakyThrow0(t);
    }

    @SuppressWarnings("unchecked")
    private static <T extends Throwable> RuntimeException sneakyThrow0(Throwable t) throws T {
        throw (T) t;
    }
}
