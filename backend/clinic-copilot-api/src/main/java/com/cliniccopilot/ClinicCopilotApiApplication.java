package com.cliniccopilot;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.reactive.config.EnableWebFlux;

@SpringBootApplication
public class ClinicCopilotApiApplication {

	public static void main(String[] args) {
		SpringApplication.run(ClinicCopilotApiApplication.class, args);
	}

}
