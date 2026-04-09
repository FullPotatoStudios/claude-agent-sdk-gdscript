extends RefCounted


static func parse_args(raw_args: Array) -> Dictionary:
	var parsed := {}
	var index := 0
	while index < raw_args.size():
		var token := str(raw_args[index]).strip_edges()
		if token.is_empty():
			index += 1
			continue
		var normalized := token.substr(2) if token.begins_with("--") else token
		if normalized.contains("="):
			var pieces := normalized.split("=", false, 1)
			parsed[pieces[0]] = pieces[1] if pieces.size() > 1 else ""
			index += 1
			continue
		if token.begins_with("--") and index + 1 < raw_args.size():
			var next_token := str(raw_args[index + 1])
			if not next_token.begins_with("--") and not next_token.contains("="):
				parsed[normalized] = next_token
				index += 2
				continue
		parsed[normalized] = true
		index += 1
	return parsed


static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://")


static func fixture_path(relative_path: String) -> String:
	return repo_root().path_join("tools/examples/fixtures").path_join(relative_path)


static func create_temp_workspace_from_fixture(relative_fixture_path: String, prefix: String) -> String:
	var source_dir := fixture_path(relative_fixture_path)
	if not DirAccess.dir_exists_absolute(source_dir):
		return ""
	var root_dir := ProjectSettings.globalize_path("user://example_workspaces")
	if DirAccess.make_dir_recursive_absolute(root_dir) != OK:
		return ""
	var target_dir := root_dir.path_join("%s-%d" % [prefix, Time.get_ticks_msec()])
	if not _copy_directory_recursive(source_dir, target_dir):
		return ""
	return target_dir


static func collect_stream_summary(stream) -> Dictionary:
	var summary := {
		"message_types": [],
		"init_commands": [],
		"init_command_names": [],
		"init_plugins": [],
		"init_agents": [],
		"init_output_style": "",
		"assistant_texts": [],
		"stream_event_count": 0,
		"stream_event_types": [],
		"result_present": false,
		"result_is_error": false,
		"result_subtype": "",
		"result_text": "",
		"result_cost_usd": 0.0,
		"stream_error": "",
	}

	while true:
		var message: Variant = await stream.next_message()
		if message == null:
			break
		if message is Object:
			summary["message_types"].append(str(message.get("message_type")))
		if message is ClaudeSystemMessage and (message as ClaudeSystemMessage).subtype == "init":
			var raw_data := (message as ClaudeSystemMessage).raw_data
			summary["init_commands"] = _extract_command_names(raw_data.get("commands", []))
			summary["init_command_names"] = _normalize_command_names(summary["init_commands"])
			summary["init_plugins"] = _extract_plugin_names(raw_data.get("plugins", []))
			summary["init_agents"] = _variant_to_string_array(raw_data.get("agents", []))
			summary["init_output_style"] = str(raw_data.get("output_style", ""))
		elif message is ClaudeAssistantMessage:
			var text := extract_assistant_text(message as ClaudeAssistantMessage)
			if not text.is_empty():
				summary["assistant_texts"].append(text)
		elif message is ClaudeStreamEvent:
			summary["stream_event_count"] = int(summary["stream_event_count"]) + 1
			var event_payload: Variant = (message as ClaudeStreamEvent).event
			if event_payload is Dictionary:
				summary["stream_event_types"].append(str((event_payload as Dictionary).get("type", "")))
		elif message is ClaudeResultMessage:
			var result_message := message as ClaudeResultMessage
			summary["result_present"] = true
			summary["result_is_error"] = result_message.is_error
			summary["result_subtype"] = result_message.subtype
			summary["result_text"] = result_message.result
			summary["result_cost_usd"] = result_message.total_cost_usd

	summary["stream_error"] = stream.get_error()
	return summary


static func extract_assistant_text(message: ClaudeAssistantMessage) -> String:
	var segments: Array[String] = []
	for block in message.content:
		if block is ClaudeTextBlock:
			segments.append((block as ClaudeTextBlock).text)
	return "\n".join(segments)


static func summary_ok(summary: Dictionary) -> bool:
	return str(summary.get("stream_error", "")).is_empty()


static func summary_has_command(summary: Dictionary, command_name: String) -> bool:
	return (summary.get("init_command_names", []) as Array).has(command_name.strip_edges().trim_prefix("/"))


static func summary_has_agent(summary: Dictionary, agent_name: String) -> bool:
	return (summary.get("init_agents", []) as Array).has(agent_name)


static func print_summary(label: String, summary: Dictionary) -> void:
	print("=== %s ===" % label)
	print("Message types: %s" % str(summary.get("message_types", [])))
	var command_names: Array = summary.get("init_commands", [])
	if not command_names.is_empty():
		print("Commands: %s" % str(command_names))
	var plugin_names: Array = summary.get("init_plugins", [])
	if not plugin_names.is_empty():
		print("Plugins: %s" % str(plugin_names))
	var agent_names: Array = summary.get("init_agents", [])
	if not agent_names.is_empty():
		print("Agents: %s" % str(agent_names))
	var output_style := str(summary.get("init_output_style", ""))
	if not output_style.is_empty():
		print("Init output style: %s" % output_style)
	if int(summary.get("stream_event_count", 0)) > 0:
		print("Stream events: %d %s" % [int(summary.get("stream_event_count", 0)), str(summary.get("stream_event_types", []))])
	var assistant_text := "\n\n".join(summary.get("assistant_texts", []) as Array[String]).strip_edges()
	if not assistant_text.is_empty():
		print("Assistant text:\n%s" % assistant_text)
	if bool(summary.get("result_present", false)):
		print("Result subtype: %s" % str(summary.get("result_subtype", "")))
		print("Result cost USD: %s" % str(summary.get("result_cost_usd", 0.0)))
		var result_text := str(summary.get("result_text", "")).strip_edges()
		if not result_text.is_empty():
			print("Result text: %s" % result_text)
	var stream_error := str(summary.get("stream_error", ""))
	if not stream_error.is_empty():
		print("Stream error: %s" % stream_error)


static func _copy_directory_recursive(source_dir: String, target_dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(target_dir) != OK:
		return false
	var dir := DirAccess.open(source_dir)
	if dir == null:
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var source_path := source_dir.path_join(name)
		var target_path := target_dir.path_join(name)
		if dir.current_is_dir():
			if not _copy_directory_recursive(source_path, target_path):
				dir.list_dir_end()
				return false
		else:
			if DirAccess.copy_absolute(source_path, target_path) != OK:
				dir.list_dir_end()
				return false
		name = dir.get_next()
	dir.list_dir_end()
	return true


static func _extract_command_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		if entry is Dictionary:
			names.append(str((entry as Dictionary).get("name", "")))
	return names


static func _normalize_command_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		names.append(str(entry).strip_edges().trim_prefix("/"))
	return names


static func _extract_plugin_names(value: Variant) -> Array[String]:
	var names: Array[String] = []
	if value is not Array:
		return names
	for entry in value:
		if entry is Dictionary:
			names.append(str((entry as Dictionary).get("name", "")))
	return names


static func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is not Array:
		return result
	for entry in value:
		result.append(str(entry))
	return result
