extends RefCounted

var values = {"music": 0.35, "effects": 0.65, "ui_scale": 1.0, "tutorial": true, "fullscreen": false, "cheat_keys": [KEY_F1, KEY_F2, KEY_F3, KEY_F4]}

func _init():
	var c = ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		for key in values: values[key] = c.get_value("options", key, values[key])

func save():
	var c = ConfigFile.new()
	for key in values: c.set_value("options", key, values[key])
	c.save("user://settings.cfg")

func apply():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
