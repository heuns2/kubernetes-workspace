package test.kuberix.gateway;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@SpringBootApplication
@EnableDiscoveryClient
public class GatewayApplication {
	
	@Autowired
	private DiscoveryClient discoveryClient;
	
	public static void main(String[] args) {
		System.setProperty("reactor.netty.http.server.accessLogEnabled", "true");
		SpringApplication.run(GatewayApplication.class, args);
	}
	
	@Bean
	public RouteLocator myRoutes(RouteLocatorBuilder builder) {
	    return builder.routes()
	        .route(p -> p
	            .path("/get")
	            .uri("https://naver.com"))
	        .build();
	}
	

	
	@GetMapping("/service-instances")
	public List<String> list() {
		System.out.println("===================================Logging TEST===================================");
		return this.discoveryClient.getServices();
	}

	@GetMapping("/service-instances/{applicationName}")
	public List<ServiceInstance> serviceInstancesByApplicationName(
			@PathVariable String applicationName) {
		System.out.println("===================================Logging TEST===================================");
		return this.discoveryClient.getInstances(applicationName);
	}
	

}
