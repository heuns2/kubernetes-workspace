package com.mzc.boot;

import org.springframework.beans.factory.annotation.Value;
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

	@Value("${spring.application.name:default}")
	String application_name;

	@Value("${vcap.application.application_id:default}")
	String application_id;

	
	@Value("${vcap.application.application_uris:default}")
	String application_uris;

	@Value("${vcap.application.cf_api:default}")
	String cf_api;

	@Value("${test:default}")
	String test;

	@GetMapping("/")
	public String home() throws Exception{
		StringBuilder sb = new StringBuilder();
		sb.append("application_name=" + application_name+"</br>");
		sb.append("application_id=" + application_id+"</br>");
		sb.append("application_uris=" + application_uris+"</br>");
		sb.append("cf_api=" + cf_api+"</br>");
		sb.append("test=" + test+"</br>");
		return sb.toString();
	}


}


