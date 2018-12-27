package myapp;

import java.util.logging.Logger;
import javax.annotation.PostConstruct;
import javax.ejb.EJB;
import javax.ejb.Singleton;
import javax.ejb.Startup;
import javax.ejb.Stateless;

@Singleton
@Startup
public class NewClass {

    @EJB
    private TimerBean bean;
    
    @PostConstruct
    protected void init() {
        LOGGER.severe("PostConstruct");
        bean.someMethod();
        bean.someMethod2();
    }

    private static final Logger LOGGER = Logger.getLogger(NewClass.class.getName());
}
