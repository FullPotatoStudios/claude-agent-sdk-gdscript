# GdUnit generated TestSuite
extends GdUnitTestSuite


func test_tool_creation_supports_annotations_and_raw_json_schema() -> void:
	var annotations := ClaudeMcpToolAnnotations.new({
		"read_only_hint": true,
		"open_world_hint": false,
	})
	var schema := {
		"type": "object",
		"properties": {
			"query": {"type": "string"},
		},
		"required": ["query"],
	}
	var tool = ClaudeMcp.tool(
		"search_docs",
		"Search documentation",
		schema,
		func(args: Dictionary): return {"content": [{"type": "text", "text": str(args.get("query", ""))}]},
		annotations
	)

	assert_object(tool).is_instanceof(ClaudeMcpTool)
	assert_str(tool.name).is_equal("search_docs")
	assert_str(tool.description).is_equal("Search documentation")
	assert_dict(tool.input_schema).is_equal(schema)
	assert_bool(tool.handler.is_valid()).is_true()
	assert_object(tool.annotations).is_instanceof(ClaudeMcpToolAnnotations)
	assert_dict(tool.annotations.to_mcp_dictionary()).is_equal({
		"readOnlyHint": true,
		"openWorldHint": false,
	})


func test_tool_creation_rejects_invalid_inputs() -> void:
	var valid_schema := ClaudeMcp.schema_object({
		"value": ClaudeMcp.schema_scalar("string"),
	}, ["value"])

	assert_that(ClaudeMcp.tool("", "Description", valid_schema, func(_args: Dictionary): return {})).is_null()
	assert_that(ClaudeMcp.tool("name", "", valid_schema, func(_args: Dictionary): return {})).is_null()
	assert_that(ClaudeMcp.tool("name", "Description", {}, func(_args: Dictionary): return {})).is_null()
	assert_that(ClaudeMcp.tool("name", "Description", {"type": "array"}, func(_args: Dictionary): return {})).is_null()
	assert_that(ClaudeMcp.tool("name", "Description", valid_schema, Callable())).is_null()


func test_schema_helpers_produce_stable_json_schema_dictionaries() -> void:
	var scalar := ClaudeMcp.schema_scalar("string", "The prompt")
	var optional := ClaudeMcp.schema_optional(ClaudeMcp.schema_scalar("integer"))
	var array_schema := ClaudeMcp.schema_array(ClaudeMcp.schema_scalar("number"), "Scores")
	var object_schema := ClaudeMcp.schema_object({
		"prompt": scalar,
		"count": optional,
		"scores": array_schema,
	}, ["prompt"])

	assert_dict(scalar).is_equal({
		"type": "string",
		"description": "The prompt",
	})
	assert_dict(optional).is_equal({
		"type": "integer",
	})
	assert_dict(array_schema).is_equal({
		"type": "array",
		"items": {"type": "number"},
		"description": "Scores",
	})
	assert_dict(object_schema).is_equal({
		"type": "object",
		"properties": {
			"prompt": {"type": "string", "description": "The prompt"},
			"count": {"type": "integer"},
			"scores": {
				"type": "array",
				"items": {"type": "number"},
				"description": "Scores",
			},
		},
		"required": ["prompt"],
	})
	assert_dict(ClaudeMcp.schema_scalar("unsupported")).is_empty()


func test_create_sdk_server_returns_runtime_config_shape() -> void:
	var tool = ClaudeMcp.tool(
		"echo",
		"Echo input",
		ClaudeMcp.schema_object({"text": ClaudeMcp.schema_scalar("string")}, ["text"]),
		func(args: Dictionary): return {"content": [{"type": "text", "text": str(args.get("text", ""))}]}
	)
	var config := ClaudeMcp.create_sdk_server("test-sdk", "1.2.3", [tool])

	assert_dict(config).contains_keys(["type", "name", "instance"])
	assert_str(str(config.get("type", ""))).is_equal("sdk")
	assert_str(str(config.get("name", ""))).is_equal("test-sdk")
	assert_object(config.get("instance")).is_instanceof(ClaudeSdkMcpServer)

	var server := config["instance"] as ClaudeSdkMcpServer
	assert_str(server.name).is_equal("test-sdk")
	assert_str(server.version).is_equal("1.2.3")
	assert_int(server.tools.size()).is_equal(1)
	assert_dict(server.list_tools()[0]).is_equal({
		"name": "echo",
		"description": "Echo input",
		"inputSchema": {
			"type": "object",
			"properties": {
				"text": {"type": "string"},
			},
			"required": ["text"],
		},
	})
