# GdUnit generated TestSuite
extends GdUnitTestSuite


func test_catalog_exposes_default_tools_groups_and_mapping_helpers() -> void:
	var default_tools := ClaudeBuiltInToolCatalog.list_default_tools()
	var groups := ClaudeBuiltInToolCatalog.list_groups()
	var metadata := ClaudeBuiltInToolCatalog.list_tool_metadata()

	assert_array(default_tools).contains_exactly([
		"Read",
		"Glob",
		"Grep",
		"LS",
		"NotebookRead",
		"Write",
		"Edit",
		"MultiEdit",
		"NotebookEdit",
		"Bash",
		"Task",
		"TodoWrite",
		"WebFetch",
		"WebSearch",
	])
	assert_int(groups.size()).is_equal(4)
	assert_dict(groups[0]).contains_keys(["id", "label", "description", "tools"])
	assert_str(str((metadata["Read"] as Dictionary).get("group_id", ""))).is_equal("read")
	assert_str(str((metadata["Write"] as Dictionary).get("group_id", ""))).is_equal("write")

	assert_array(ClaudeBuiltInToolCatalog.selection_from_tools_config(null)).is_equal(default_tools)
	assert_array(ClaudeBuiltInToolCatalog.selection_from_tools_config({"type": "preset", "preset": "custom"})).is_equal(default_tools)
	assert_array(ClaudeBuiltInToolCatalog.selection_from_tools_config(["WebSearch", "Read", "Read", "Unknown"])).is_equal([
		"Read",
		"WebSearch",
	])

	assert_dict(ClaudeBuiltInToolCatalog.tools_config_from_selection(default_tools)).is_equal({
		"type": "preset",
		"preset": "claude_code",
	})
	assert_array(ClaudeBuiltInToolCatalog.tools_config_from_selection([])).is_empty()
	assert_array(ClaudeBuiltInToolCatalog.tools_config_from_selection(["WebSearch", "Read"])).is_equal([
		"Read",
		"WebSearch",
	])
