#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

artifact_path=""
keep_temp=0

while [ "$#" -gt 0 ]; do
	case "$1" in
		--artifact)
			artifact_path="$2"
			shift 2
			;;
		--keep-temp)
			keep_temp=1
			shift
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
	esac
done

if [ -z "${artifact_path}" ]; then
	version="$(read_addon_version)"
	artifact_path="${repo_root}/.artifacts/release/v${version}/claude-agent-sdk-gdscript-v${version}.zip"
fi

if [ ! -f "${artifact_path}" ]; then
	echo "Release artifact not found at ${artifact_path}" >&2
	exit 1
fi

godot_binary="$(resolve_godot_binary || true)"
if [ -z "${godot_binary}" ]; then
	echo "Godot binary not found. Set GODOT_BIN or install Godot 4.6." >&2
	exit 1
fi

temp_project="$(mktemp -d "${TMPDIR:-/tmp}/claude-agent-sdk-consumer.XXXXXX")"
test_home="${temp_project}/home"
test_config="${temp_project}/config"
test_cache="${temp_project}/cache"
mkdir -p "${test_home}" "${test_config}" "${test_cache}"

cleanup() {
	if [ "${keep_temp}" -ne 1 ]; then
		rm -rf "${temp_project}"
	fi
}
trap cleanup EXIT

unzip -q "${artifact_path}" -d "${temp_project}"

cat > "${temp_project}/project.godot" <<'EOF'
config_version=5

[application]
config/name="Claude Agent SDK Consumer Smoke"
run/main_scene=""
EOF

cat > "${temp_project}/fake_transport.gd" <<'EOF'
extends RefCounted

signal stdout_line(line: String)
signal stderr_line(line: String)
signal transport_closed
signal transport_error(message: String)

var connected := false
var writes: Array[String] = []
var _last_error := ""

func open_transport() -> bool:
	connected = true
	return true

func write(payload: String) -> bool:
	if not connected:
		_last_error = "Fake transport is not connected"
		transport_error.emit(_last_error)
		return false
	writes.append(payload)
	return true

func close() -> void:
	connected = false
	transport_closed.emit()

func get_last_error() -> String:
	return _last_error

func probe_auth_status() -> Dictionary:
	return {
		"ok": true,
		"logged_in": true,
		"auth_method": "claude.ai",
		"api_provider": "firstParty",
		"email": "consumer@example.com",
		"org_id": "org-consumer",
		"org_name": "Consumer Org",
		"subscription_type": "max",
		"raw": {"loggedIn": true},
		"stdout": "",
		"stderr": "",
		"error_code": "",
		"error_message": "",
		"exit_code": 0,
	}

func emit_stdout_message(payload: Dictionary) -> void:
	stdout_line.emit(JSON.stringify(payload))
EOF

cat > "${temp_project}/consumer_smoke.gd" <<'EOF'
extends SceneTree

const OptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const AdapterScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_adapter.gd")
const NodeScript := preload("res://addons/claude_agent_sdk/runtime/adapters/claude_client_node.gd")
const PanelScene := preload("res://addons/claude_agent_sdk/ui/claude_chat_panel.tscn")
const FakeTransportScript := preload("res://fake_transport.gd")

func _init() -> void:
	await process_frame
	var ok := await _run()
	quit(0 if ok else 2)

func _run() -> bool:
	var options = OptionsScript.new({"model": "haiku", "effort": "low"})
	if options == null:
		push_error("Failed to instantiate ClaudeAgentOptions")
		return false

	var adapter_transport = FakeTransportScript.new()
	var adapter = AdapterScript.new(options.duplicate_options(), adapter_transport)
	var adapter_ready_events: Array[int] = []
	adapter.session_ready.connect(func(_server_info: Dictionary): adapter_ready_events.append(1))
	adapter.connect_client()
	var adapter_init_request: Dictionary = JSON.parse_string(adapter_transport.writes[-1])
	adapter_transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(adapter_init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await process_frame
	await process_frame
	if adapter_ready_events.size() != 1:
		push_error("Adapter did not become ready in consumer smoke project")
		return false

	var node_transport = FakeTransportScript.new()
	var client_node = NodeScript.new(options.duplicate_options(), node_transport)
	root.add_child(client_node)
	client_node.connect_client()
	var node_init_request: Dictionary = JSON.parse_string(node_transport.writes[-1])
	node_transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(node_init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await process_frame
	if not client_node.is_client_connected():
		push_error("ClaudeClientNode did not stay connected in consumer smoke project")
		return false

	var panel_transport = FakeTransportScript.new()
	var panel = PanelScene.instantiate()
	panel.setup(options.duplicate_options(), panel_transport)
	root.add_child(panel)
	await process_frame
	panel.connect_client()
	var panel_init_request: Dictionary = JSON.parse_string(panel_transport.writes[-1])
	panel_transport.emit_stdout_message({
		"type": "control_response",
		"response": {
			"subtype": "success",
			"request_id": str(panel_init_request.get("request_id", "")),
			"response": {"commands": [{"name": "/help"}]},
		},
	})
	await process_frame
	await process_frame
	var prompt_input := panel.find_child("PromptInput", true, false) as TextEdit
	if prompt_input == null or not prompt_input.editable:
		push_error("ClaudeChatPanel did not unlock the composer in consumer smoke project")
		return false

	return true
EOF

HOME="${test_home}" \
XDG_DATA_HOME="${test_home}" \
XDG_CONFIG_HOME="${test_config}" \
XDG_CACHE_HOME="${test_cache}" \
"${godot_binary}" \
	--headless \
	--path "${temp_project}" \
	--import

HOME="${test_home}" \
XDG_DATA_HOME="${test_home}" \
XDG_CONFIG_HOME="${test_config}" \
XDG_CACHE_HOME="${test_cache}" \
"${godot_binary}" \
	--headless \
	--path "${temp_project}" \
	-s res://consumer_smoke.gd

echo "Validated packaged addon in fresh temp project:"
echo "  Artifact: ${artifact_path}"
echo "  Temp project: ${temp_project}"
