extends SceneTree

const ClaudeAgentOptionsScript := preload("res://addons/claude_agent_sdk/runtime/claude_agent_options.gd")
const ClaudeQueryScript := preload("res://addons/claude_agent_sdk/runtime/query.gd")
const ExampleSupportScript := preload("res://tools/examples/example_support.gd")


func _init() -> void:
	await process_frame
	var exit_code := await _run_example()
	quit(exit_code)


func _run_example() -> int:
	var reasonable := await _run_budget_case(
		"Reasonable budget",
		0.10,
		"What is 2 + 2? Answer only with the number."
	)
	var tight := await _run_budget_case(
		"Tight budget",
		0.0001,
		"Read the README.md file and summarize it in one short sentence."
	)
	var ok := ExampleSupportScript.summary_ok(reasonable) and ExampleSupportScript.summary_ok(tight)
	if str(tight.get("result_subtype", "")) == "error_max_budget_usd":
		print("Observed the expected max-budget error subtype for the tight budget case.")
	else:
		print("Tight budget did not trigger error_max_budget_usd on this run.")
	return 0 if ok else 2


func _run_budget_case(label: String, budget: float, prompt: String) -> Dictionary:
	var options = ClaudeAgentOptionsScript.new({
		"cwd": ExampleSupportScript.repo_root(),
		"max_turns": 1,
		"max_budget_usd": budget,
	})
	var summary := await ExampleSupportScript.collect_stream_summary(
		ClaudeQueryScript.query(prompt, options)
	)
	ExampleSupportScript.print_summary(label, summary)
	return summary
