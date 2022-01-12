package com.mzc.boot;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;


@SpringBootApplication
@RestController
public class SimpleBootApplication {
	private static final Logger logger = LoggerFactory.getLogger(SimpleBootApplication.class);

    public static void main(String[] args) {
    	System.setProperty("reactor.netty.http.server.accessLogEnabled", "true");
        SpringApplication.run(SimpleBootApplication.class, args);
    }

    @GetMapping("/test")
    public String home() {
          System.out.println("===================================Logging TEST===================================");
          logger.debug("test");
          return "ok_v1";
    }
    
    @GetMapping("/number")
    public int exception_test() {
          System.out.println("===================================Exception TEST===================================");
          int result = 0;
          try {
              int num1=1;
              int num2=0;
              result=num1/num2;
        	  } catch (Exception e) {
        		  e.printStackTrace();
        	  }
          return result;
    }
}


