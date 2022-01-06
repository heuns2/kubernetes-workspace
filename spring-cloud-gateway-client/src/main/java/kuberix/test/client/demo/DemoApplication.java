package kuberix.test.client.demo;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@EnableDiscoveryClient
@RestController
public class DemoApplication {
	
	@Autowired
	private DiscoveryClient discoveryClient;
	
	public static void main(String[] args) {
		SpringApplication.run(DemoApplication.class, args);
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
	
	@GetMapping("/")
	public String getClient2(){
		System.out.println("===================================OK===================================");
		return "ok";
	}

}
