# GdUnit generated TestSuite
extends GdUnitTestSuite

const FakeTransportScript := preload("res://tests/support/fake_transport.gd")


func test_client_get_auth_status_uses_transport_probe() -> void:
	var transport = FakeTransportScript.new()
	transport.auth_status_result = {
		"ok": true,
		"logged_in": true,
		"auth_method": "claude.ai",
		"api_provider": "firstParty",
		"email": "tester@example.com",
		"org_id": "org-1",
		"org_name": "Test Org",
		"subscription_type": "max",
		"raw": {"loggedIn": true},
		"stdout": "",
		"stderr": "",
		"error_code": "",
		"error_message": "",
		"exit_code": 0,
	}
	var client = ClaudeSDKClient.new(ClaudeAgentOptions.new(), transport)

	var result = client.get_auth_status()

	assert_bool(bool(result.get("ok", false))).is_true()
	assert_bool(bool(result.get("logged_in", false))).is_true()
	assert_str(str(result.get("subscription_type", ""))).is_equal("max")


func test_query_get_auth_status_uses_transport_probe() -> void:
	var transport = FakeTransportScript.new()
	transport.auth_status_result["logged_in"] = false
	transport.auth_status_result["ok"] = false
	transport.auth_status_result["error_code"] = "logged_out"
	transport.auth_status_result["error_message"] = "Claude CLI is not logged in"

	var result = ClaudeQuery.get_auth_status(ClaudeAgentOptions.new(), transport)

	assert_bool(bool(result.get("logged_in", true))).is_false()
	assert_str(str(result.get("error_code", ""))).is_equal("logged_out")


func test_subprocess_auth_probe_parses_logged_in_json() -> void:
	if OS.get_name() == "Windows":
		return
	var script_path := _write_auth_probe_script("logged_in", "printf '%s\\n' '{\"loggedIn\":true,\"authMethod\":\"claude.ai\",\"apiProvider\":\"firstParty\",\"email\":\"tester@example.com\",\"orgId\":\"org-1\",\"orgName\":\"Test Org\",\"subscriptionType\":\"max\"}'")
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cli_path": script_path,
	}))

	var result = transport.probe_auth_status()

	assert_bool(bool(result.get("ok", false))).is_true()
	assert_bool(bool(result.get("logged_in", false))).is_true()
	assert_str(str(result.get("auth_method", ""))).is_equal("claude.ai")
	assert_str(str(result.get("org_name", ""))).is_equal("Test Org")


func test_subprocess_auth_probe_surfaces_logged_out_payload() -> void:
	if OS.get_name() == "Windows":
		return
	var script_path := _write_auth_probe_script("logged_out", "printf '%s\\n' '{\"loggedIn\":false,\"authMethod\":\"none\",\"apiProvider\":\"firstParty\"}'")
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cli_path": script_path,
	}))

	var result = transport.probe_auth_status()

	assert_bool(bool(result.get("ok", true))).is_false()
	assert_bool(bool(result.get("logged_in", true))).is_false()
	assert_str(str(result.get("error_code", ""))).is_equal("logged_out")


func test_subprocess_auth_probe_prefers_structured_json_payload_even_on_non_zero_exit() -> void:
	if OS.get_name() == "Windows":
		return
	var script_path := _write_auth_probe_script(
		"logged_out_non_zero",
		"printf '%s\\n' '{\"loggedIn\":false,\"authMethod\":\"none\",\"apiProvider\":\"firstParty\"}'\nexit 1"
	)
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cli_path": script_path,
	}))

	var result = transport.probe_auth_status()

	assert_bool(bool(result.get("ok", true))).is_false()
	assert_bool(bool(result.get("logged_in", true))).is_false()
	assert_str(str(result.get("error_code", ""))).is_equal("logged_out")
	assert_int(int(result.get("exit_code", 0))).is_equal(1)


func test_subprocess_auth_probe_reports_missing_binary() -> void:
	if OS.get_name() == "Windows":
		return
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cli_path": "/tmp/definitely-missing-claude-binary",
	}))

	var result = transport.probe_auth_status()

	assert_bool(bool(result.get("ok", true))).is_false()
	assert_str(str(result.get("error_code", ""))).is_equal("binary_not_found")


func test_subprocess_auth_probe_reports_json_parse_failure() -> void:
	if OS.get_name() == "Windows":
		return
	var script_path := _write_auth_probe_script("bad_json", "printf '%s\\n' 'not-json'")
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"cli_path": script_path,
	}))

	var result = transport.probe_auth_status()

	assert_bool(bool(result.get("ok", true))).is_false()
	assert_str(str(result.get("error_code", ""))).is_equal("json_parse_failed")


func test_subprocess_auth_probe_uses_user_process_launch_when_configured() -> void:
	var transport = ClaudeSubprocessCLITransport.new(ClaudeAgentOptions.new({
		"user": "claude",
	}))

	if OS.get_name() == "Windows":
		assert_bool(transport._validate_supported_options()).is_false()
		assert_str(transport.get_last_error()).contains("supported only on POSIX")
		return

	var process_spec := transport._build_process_spec_for_args(PackedStringArray(["auth", "status"]))
	var process_args := process_spec.get("args", PackedStringArray()) as PackedStringArray
	var shell_script := str(process_args[6])

	assert_str(str(process_spec.get("path", ""))).contains("sudo")
	assert_str(process_args[0]).is_equal("-n")
	assert_str(process_args[1]).is_equal("-u")
	assert_str(process_args[2]).is_equal("claude")
	assert_str(process_args[3]).is_equal("--")
	assert_str(process_args[4]).is_equal("/bin/sh")
	assert_str(process_args[5]).is_equal("-lc")
	assert_bool(shell_script.contains("auth")).is_true()
	assert_bool(shell_script.contains("status")).is_true()


func _write_auth_probe_script(script_name: String, command: String) -> String:
	var path := "/tmp/%s_%d.sh" % [script_name, Time.get_unix_time_from_system()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("#!/bin/sh\n%s\n" % command)
	file.close()
	var output: Array[String] = []
	OS.execute("chmod", ["+x", path], output)
	return path
