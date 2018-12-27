
package myapp;

import java.util.logging.Level;
import java.util.logging.Logger;
import javax.interceptor.AroundInvoke;
import javax.interceptor.AroundTimeout;
import javax.interceptor.Interceptor;
import javax.interceptor.InvocationContext;

@Interceptor
public class InterceptorBean {

    @AroundInvoke
    public Object invokeInterceptorMethod(InvocationContext ctx) throws Exception {
        LOGGER.log(Level.SEVERE, "invokeInterceptorMethod {0}", ctx.getMethod());
        return ctx.proceed();
    }
    
    @AroundTimeout
    public Object timeoutInterceptorMethod(InvocationContext ctx) throws Exception {
        LOGGER.log(Level.SEVERE, "timeoutInterceptorMethod {0}", ctx.getMethod());
        return ctx.proceed();
    }
    
    private static final Logger LOGGER = Logger.getLogger(InterceptorBean.class.getName());
}
