extends Control
## Boot screen: ROM selection → class select → Town.

@onready var rom_label: Label = $Center/RomLabel
@onready var status_label: Label = $Center/StatusLabel
@onready var class_box: VBoxContainer = $Center/ClassButtons
@onready var file_dialog: FileDialog = $FileDialog

var rom_loaded: bool = false

func _ready() -> void:
	status_label.text = "Select a Super Mario 64 (USA) ROM to continue."
	_build_class_buttons()
	# Diagnose addon presence once at startup
	if not _addon_available():
		status_label.text = _addon_help_text()
	else:
		status_label.text = "Addon detected. Select a Super Mario 64 (USA) ROM."
		var prev := _load_rom_path()
		if not prev.is_empty() and FileAccess.file_exists(prev):
			_try_load_rom(prev)

func _addon_available() -> bool:
	# LibSM64 is the GDExtension singleton (most reliable check).
	# LibSM64Global is a GDScript class_name – ClassDB.class_exists can fail for it.
	if ClassDB.class_exists("LibSM64"):
		return true
	# Fallback: try resolving the global class by name
	if ClassDB.class_exists("LibSM64Global"):
		return true
	# Last resort: the script may still be loadable via class_name after plugin enable
	var test = load("res://addons/libsm64_godot/static/libsm64_global.gd")
	return test != null

func _addon_help_text() -> String:
	return (
		"Libsm64 Godot addon not detected.\n\n"
		+ "1. Asset Library → search “Libsm64 Godot” → Download → Install\n"
		+ "   (or copy addons/libsm64_godot from a GitHub release)\n"
		+ "2. Project → Project Settings → Plugins → enable “Libsm64 Godot”\n"
		+ "3. Project → Reload Current Project\n"
		+ "4. Confirm folder is exactly: res://addons/libsm64_godot/"
	)

func _build_class_buttons() -> void:
	for c in class_box.get_children():
		c.queue_free()
	for i in Data.CLASSES.size():
		var btn := Button.new()
		var cl: Dictionary = Data.CLASSES[i]
		btn.text = "%s  —  HP%d  ATK%d  DEF%d  Crit%d%%\n%s" % [cl.name, cl.hp, cl.atk, cl.def, cl.crit, cl.desc]
		btn.disabled = true
		btn.custom_minimum_size = Vector2(0, 56)
		btn.pressed.connect(_on_class_pressed.bind(i))
		class_box.add_child(btn)

func _on_select_rom_pressed() -> void:
	if not _addon_available():
		status_label.text = _addon_help_text()
		return
	file_dialog.popup_centered_ratio(0.65)

func _on_file_selected(path: String) -> void:
	_try_load_rom(path)

func _try_load_rom(path: String) -> void:
	if not _addon_available():
		status_label.text = _addon_help_text()
		rom_loaded = false
		return

	# Direct call – LibSM64Global is a static GDScript class from the addon
	var ok: bool = false
	var err_detail := ""
	# Prefer load_rom_file (current API). Second arg skips checksum if needed for testing.
	var result = LibSM64Global.load_rom_file(path, false)
	if typeof(result) == TYPE_BOOL:
		ok = result
	else:
		err_detail = "load_rom_file returned unexpected type"

	if not ok:
		# Show more detail: file missing vs hash mismatch
		if not FileAccess.file_exists(path):
			status_label.text = "ROM file not found at:\n" + path
		else:
			var got_hash := FileAccess.get_sha256(path)
			status_label.text = (
				"ROM rejected (SHA-256 mismatch or unreadable).\n\n"
				+ "Expected:\n17ce077343c6133f8c9f2d6d6d9a4ab62c8cd2aa57c40aea1f490b4c8bb21d91\n\n"
				+ "Your file:\n" + got_hash + "\n\n"
				+ "Use an unmodified Super Mario 64 (USA) .z64 ROM."
			)
		rom_loaded = false
		return

	var init_ok: bool = LibSM64Global.init()
	if not init_ok:
		status_label.text = "ROM loaded but LibSM64Global.init() failed.\nCheck the Output panel for errors."
		rom_loaded = false
		return

	rom_loaded = true
	GameState.rom_ready = true
	_save_rom_path(path)
	rom_label.text = "ROM loaded: " + path.get_file()
	status_label.text = "ROM OK. Choose your class to begin."
	for c in class_box.get_children():
		c.disabled = false

func _on_class_pressed(idx: int) -> void:
	if not rom_loaded:
		return
	GameState.select_class(idx)
	get_tree().change_scene_to_file("res://scenes/town.tscn")

func _on_load_game_pressed() -> void:
	if not rom_loaded:
		status_label.text = "Load a ROM first, then load a save."
		return
	if GameState.load_game() and GameState.class_id >= 0:
		get_tree().change_scene_to_file("res://scenes/town.tscn")
	else:
		status_label.text = "No valid save found (user://pq64_save.json)."

func _save_rom_path(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("rom", "path", path)
	cfg.save("user://pq64_settings.cfg")

func _load_rom_path() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://pq64_settings.cfg") == OK:
		return str(cfg.get_value("rom", "path", ""))
	return ""
