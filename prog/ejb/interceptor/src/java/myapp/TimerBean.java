
package myapp;

import java.util.logging.Logger;
import javax.ejb.Schedule;
import javax.ejb.Startup;
import javax.ejb.Stateless;

@Stateless
public class TimerBean {
    
    public void someMethod() {
        LOGGER.severe("someMethod");
    }

    public void someMethod2() {
        LOGGER.severe("someMethod2");
    }
    
    @Schedule(minute="*/1", hour="*")
    public void automaticTimerMethod() {
        LOGGER.severe("automaticTimerMethod");
    }

    private static final Logger LOGGER = Logger.getLogger(TimerBean.class.getName());
}
