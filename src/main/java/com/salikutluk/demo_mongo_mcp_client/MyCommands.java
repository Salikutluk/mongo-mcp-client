package com.salikutluk.demo_mongo_mcp_client;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.tool.ToolCallbackProvider;
import org.springframework.shell.standard.ShellComponent;
import org.springframework.shell.standard.ShellMethod;
import org.springframework.shell.standard.ShellOption;

@ShellComponent
public class MyCommands {

    private final ChatClient chatClient;

    public MyCommands(ChatClient.Builder builder, ToolCallbackProvider tools) {
        this.chatClient = builder.build();
    }

    @ShellMethod(key = "chat")
    public String helloWorld(
            @ShellOption(defaultValue = "Hello MCP Client") String arg
    ) {
        return this.chatClient.prompt(arg).call().content();
    }
}