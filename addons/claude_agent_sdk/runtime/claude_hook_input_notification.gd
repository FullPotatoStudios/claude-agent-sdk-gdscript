extends ClaudeHookInput
class_name ClaudeHookInputNotification

var message: String = ""
var title: String = ""
var notification_type: String = ""


func _init(config: Dictionary = {}) -> void:
	hook_event_name = "Notification"
	if not config.is_empty():
		apply(config)


func apply(config: Dictionary):
	super.apply(config)
	hook_event_name = "Notification"
	if config.has("message"):
		message = str(config["message"])
	if config.has("title"):
		title = str(config["title"])
	if config.has("notification_type") or config.has("notificationType"):
		notification_type = str(_get_first(config, ["notification_type", "notificationType"]))
	return self


func to_dict() -> Dictionary:
	var result := super.to_dict()
	if not message.is_empty():
		result["message"] = message
	if not title.is_empty():
		result["title"] = title
	if not notification_type.is_empty():
		result["notification_type"] = notification_type
	return result
