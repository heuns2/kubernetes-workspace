package com.kamo.sample.boot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class SimpleBootApplication {

    public static void main(String[] args) {
        SpringApplication.run(SimpleBootApplication.class, args);
    }

    @GetMapping("/")
    public String getHostName() {
    	String hostName = System.getenv("HOSTNAME");
    	return "<h1>Springboot</h1><br>" + hostName;
    }
}


