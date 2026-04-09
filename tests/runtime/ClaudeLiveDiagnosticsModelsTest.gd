# GdUnit generated TestSuite
extends GdUnitTestSuite

const ClaudeContextUsageResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_context_usage_response.gd")
const ClaudeMcpStatusResponseScript := preload("res://addons/claude_agent_sdk/runtime/claude_mcp_status_response.gd")


func test_context_usage_response_coerces_nested_items_and_serializes_wire_keys() -> void:
	var usage = ClaudeContextUsageResponseScript.coerce({
		"categories": [
			{"name": "System prompt", "tokens": 3200, "color": "#abc", "isDeferred": true},
		],
		"totalTokens": 98200,
		"maxTokens": 155000,
		"rawMaxTokens": 200000,
		"percentage": 49.1,
		"model": "claude-sonnet-4-5",
		"isAutoCompactEnabled": true,
		"memoryFiles": [{"path": "CLAUDE.md", "type": "project", "tokens": 512}],
		"mcpTools": [{"name": "search", "serverName": "ref", "tokens": 164, "isLoaded": true}],
		"agents": [{"agentType": "coder", "source": "sdk", "tokens": 299}],
		"gridRows": [],
	})

	assert_object(usage).is_not_null()
	if usage == null:
		return
	assert_bool(usage.is_empty()).is_false()
	assert_int(usage.categories.size()).is_equal(1)
	assert_bool(bool(usage.categories[0].is_deferred)).is_true()
	assert_str(usage.memory_files[0].path).is_equal("CLAUDE.md")
	assert_str(usage.mcp_tools[0].server_name).is_equal("ref")
	assert_str(usage.agents[0].agent_type).is_equal("coder")
	assert_dict(usage.to_dict()).is_equal({
		"categories": [{"name": "System prompt", "tokens": 3200, "color": "#abc", "isDeferred": true}],
		"totalTokens": 98200,
		"maxTokens": 155000,
		"rawMaxTokens": 200000,
		"percentage": 49.1,
		"model": "claude-sonnet-4-5",
		"isAutoCompactEnabled": true,
		"memoryFiles": [{"path": "CLAUDE.md", "type": "project", "tokens": 512}],
		"mcpTools": [{"name": "search", "serverName": "ref", "tokens": 164, "isLoaded": true}],
		"agents": [{"agentType": "coder", "source": "sdk", "tokens": 299}],
		"gridRows": [],
	})


func test_mcp_status_response_coerces_nested_items_and_keeps_raw_config_dictionary() -> void:
	var status = ClaudeMcpStatusResponseScript.coerce({
		"mcpServers": [
			{
				"name": "my-http-server",
				"status": "connected",
				"serverInfo": {"name": "my-http-server", "version": "1.0.0"},
				"config": {"type": "http", "url": "https://example.com/mcp"},
				"scope": "project",
				"tools": [{"name": "greet", "annotations": {"readOnly": true}}],
			},
			{
				"name": "failed-server",
				"status": "failed",
				"error": "Connection refused",
			},
		],
	})

	assert_object(status).is_not_null()
	if status == null:
		return
	assert_bool(status.is_empty()).is_false()
	assert_int(status.mcp_servers.size()).is_equal(2)
	assert_str(status.mcp_servers[0].server_info.version).is_equal("1.0.0")
	assert_str(str(status.mcp_servers[0].config.get("url", ""))).is_equal("https://example.com/mcp")
	assert_bool(bool(status.mcp_servers[0].tools[0].annotations.read_only)).is_true()
	assert_str(status.mcp_servers[1].error_message).is_equal("Connection refused")
	assert_dict(status.to_dict()).is_equal({
		"mcpServers": [
			{
				"name": "my-http-server",
				"status": "connected",
				"serverInfo": {"name": "my-http-server", "version": "1.0.0"},
				"config": {"type": "http", "url": "https://example.com/mcp"},
				"scope": "project",
				"tools": [{"name": "greet", "annotations": {"readOnly": true}}],
			},
			{
				"name": "failed-server",
				"status": "failed",
				"error": "Connection refused",
			},
		],
	})
