#!/usr/bin/env bash

set -eu

if [ ! -d "addons/gdUnit4" ]; then
	echo "GdUnit4 is not installed. Run ./tools/dev/install_gdunit4.sh first."
	exit 1
fi

godot_binary="${GODOT_BIN:-}"
if [ -z "${godot_binary}" ] && [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	godot_binary="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [ -z "${godot_binary}" ] && command -v godot4 >/dev/null 2>&1; then
	godot_binary="$(command -v godot4)"
fi
if [ -z "${godot_binary}" ] && command -v godot >/dev/null 2>&1; then
	godot_binary="$(command -v godot)"
fi

if [ -z "${godot_binary}" ]; then
	echo "Godot binary not found. Set GODOT_BIN or install Godot 4.6."
	exit 1
fi

mkdir -p ".artifacts/gdunit"

test_home="${TMPDIR:-/tmp}/claude-agent-sdk-gdscript-godot-home"
test_config="${TMPDIR:-/tmp}/claude-agent-sdk-gdscript-godot-config"
test_cache="${TMPDIR:-/tmp}/claude-agent-sdk-gdscript-godot-cache"
mkdir -p "${test_home}" "${test_config}" "${test_cache}"

HOME="${test_home}" \
XDG_DATA_HOME="${test_home}" \
XDG_CONFIG_HOME="${test_config}" \
XDG_CACHE_HOME="${test_cache}" \
"${godot_binary}" \
	--headless \
	--path . \
	--import

HOME="${test_home}" \
XDG_DATA_HOME="${test_home}" \
XDG_CONFIG_HOME="${test_config}" \
XDG_CACHE_HOME="${test_cache}" \
"${godot_binary}" \
	--headless \
	--path . \
	-s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode \
	-a res://tests \
	-c \
	-rd res://.artifacts/gdunit \
	-rc 5

HOME="${test_home}" \
XDG_DATA_HOME="${test_home}" \
XDG_CONFIG_HOME="${test_config}" \
XDG_CACHE_HOME="${test_cache}" \
"${godot_binary}" \
	--headless \
	--path . \
	--quiet \
	-s res://addons/gdUnit4/bin/GdUnitCopyLog.gd \
	-a res://tests \
	-rd res://.artifacts/gdunit \
	-rc 5 >/dev/null
