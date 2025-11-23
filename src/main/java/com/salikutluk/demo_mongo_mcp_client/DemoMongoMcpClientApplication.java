package com.salikutluk.demo_mongo_mcp_client;

import io.modelcontextprotocol.client.McpSyncClient;
import io.modelcontextprotocol.spec.McpSchema;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;

import java.util.List;
import java.util.Map;

@SpringBootApplication
public class DemoMongoMcpClientApplication {

    public static void main(String[] args) {
		SpringApplication.run(DemoMongoMcpClientApplication.class, args);
	}

    @Bean
    CommandLineRunner commandLineRunner(List<McpSyncClient> mcpSyncClientList, ConfigurableApplicationContext applicationContext) {
        return args -> {
            McpSyncClient mcpSyncClient = mcpSyncClientList.get(0);
            McpSchema.ListToolsResult listToolsResult = mcpSyncClient.listTools();
            System.out.println("listToolsResult = " + listToolsResult);

            McpSchema.CallToolResult listCollections = mcpSyncClient.callTool(new McpSchema.CallToolRequest("list-collections", Map.of("database", "mydb")));
            System.out.println("listCollections = " + listCollections);
            applicationContext.close();

        };
    }

}
