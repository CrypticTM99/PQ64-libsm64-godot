extends Node3D
## Town hub – authentic Mario movement + menu access.

@onready var mario: Node3D = $LibSM64Mario
@onready var surface_handler: Node = $LibSM64StaticSurfaceHandler
@onready var camera: Camera3D = $Camera3D

@onready var hp_label: Label = $TownUI/TopBar/HPLabel
@onready var mp_label: Label = $TownUI/TopBar/MPLabel
@onready var gold_label: Label = $TownUI/TopBar/GoldLabel
@onready var level_label: Label = $TownUI/TopBar/LevelLabel
@onready var message_label: Label = $TownUI/Message
@onready var panel_shop: PanelContainer = $TownUI/ShopPanel
@onready var panel_equip: PanelContainer = $TownUI/EquipPanel
@onready var panel_quests: PanelContainer = $TownUI/QuestsPanel
@onready var shop_list: VBoxContainer = $TownUI/ShopPanel/VBox/ShopList
@onready var equip_list: VBoxContainer = $TownUI/EquipPanel/VBox/EquipList
@onready var quest_list: VBoxContainer = $TownUI/QuestsPanel/VBox/QuestList

var _mario_created: bool = false

func _ready() -> void:
	GameState.player_stats_changed.connect(_refresh_hud)
	GameState.message.connect(_show_message)
	_refresh_hud()
	_hide_panels()
	_init_libsm64()
	GameState.change_state(Data.GameState.S_TOWN)

func _init_libsm64() -> void:
	if not GameState.rom_ready:
		_show_message("ROM not loaded – return to boot.")
		return

	# Always load collision so Mario can be created (works even if handler type not set)
	var faces := SM64Helpers.load_group_as_static_surfaces(&"libsm64_static_surfaces")
	print("[PQ64] Loaded %d static surface triangles" % faces)

	if mario and mario.has_method("create"):
		if "camera" in mario:
			mario.camera = camera
		mario.create()
		_mario_created = true
		_show_message("Welcome to town. Move with WASD / stick, Space to jump.")
	else:
		_show_message("Tip: set LibSM64Mario node type to LibSM64Mario and assign Camera (README).")

func _refresh_hud() -> void:
	if hp_label:
		hp_label.text = "HP  %d / %d" % [GameState.hp, GameState.max_hp]
	if mp_label:
		mp_label.text = "MP  %d / %d" % [GameState.mp, GameState.max_mp]
	if gold_label:
		gold_label.text = "Gold  %d" % GameState.gold
	var cname := "?"
	if GameState.class_id >= 0 and GameState.class_id < Data.CLASSES.size():
		cname = Data.CLASSES[GameState.class_id].name
	if level_label:
		level_label.text = "Lv %d  %s" % [GameState.level, cname]

func _show_message(text: String) -> void:
	if not message_label:
		return
	message_label.text = text
	message_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(message_label, "modulate:a", 0.0, 0.6)

func _hide_panels() -> void:
	if panel_shop:
		panel_shop.visible = false
	if panel_equip:
		panel_equip.visible = false
	if panel_quests:
		panel_quests.visible = false

func _on_battle_pressed() -> void:
	_hide_panels()
	var pool: Array = []
	for e in Data.ENEMIES:
		if e.safe and GameState.level >= int(e.min_level):
			pool.append(e)
	if pool.is_empty():
		pool = Data.ENEMIES.duplicate()
	if GameState.level >= 10 and randf() < 0.12:
		pool.append(Data.BOSSES[0])
	if GameState.level >= 15 and randf() < 0.08:
		pool.append(Data.BOSSES[1])
	var chosen: Dictionary = pool[randi() % pool.size()]
	GameState.start_battle(chosen)
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_shop_pressed() -> void:
	_hide_panels()
	if panel_shop:
		panel_shop.visible = true
	_rebuild_shop()

func _on_equip_pressed() -> void:
	_hide_panels()
	if panel_equip:
		panel_equip.visible = true
	_rebuild_equip()

func _on_quests_pressed() -> void:
	_hide_panels()
	if panel_quests:
		panel_quests.visible = true
	_rebuild_quests()

func _on_save_pressed() -> void:
	GameState.save_game()

func _on_close_panels() -> void:
	_hide_panels()

func _rebuild_shop() -> void:
	if not shop_list:
		return
	for c in shop_list.get_children():
		c.queue_free()
	for item in Data.SHOP_CONSUMABLES:
		var btn := Button.new()
		btn.text = "%s  —  %d gold" % [item.name, item.price]
		btn.pressed.connect(_buy_consumable.bind(item))
		shop_list.add_child(btn)
	for g in Data.GEAR:
		var btn2 := Button.new()
		btn2.text = "%s  —  %d gold  (%s)" % [g.name, g.price, g.slot]
		btn2.pressed.connect(_buy_gear.bind(g))
		shop_list.add_child(btn2)

func _buy_consumable(item: Dictionary) -> void:
	if GameState.gold < int(item.price):
		_show_message("Not enough gold.")
		return
	GameState.gold -= int(item.price)
	GameState.inventory[item.id] = GameState.inventory.get(item.id, 0) + 1
	GameState.player_stats_changed.emit()
	_show_message("Bought %s" % item.name)

func _buy_gear(g: Dictionary) -> void:
	if GameState.gold < int(g.price):
		_show_message("Not enough gold.")
		return
	GameState.gold -= int(g.price)
	GameState.inventory[g.id] = GameState.inventory.get(g.id, 0) + 1
	GameState.player_stats_changed.emit()
	_show_message("Bought %s" % g.name)

func _rebuild_equip() -> void:
	if not equip_list:
		return
	for c in equip_list.get_children():
		c.queue_free()
	var cur := Label.new()
	cur.text = "Equipped:  W:%s  A:%s  Acc:%s" % [
		GameState.equipment.weapon if GameState.equipment.weapon else "—",
		GameState.equipment.armor if GameState.equipment.armor else "—",
		GameState.equipment.accessory if GameState.equipment.accessory else "—"]
	equip_list.add_child(cur)
	for id in GameState.inventory:
		var g := Data.get_gear(id)
		if g.is_empty():
			continue
		var btn := Button.new()
		btn.text = "Equip %s  (x%d)" % [g.name, GameState.inventory[id]]
		btn.pressed.connect(_do_equip.bind(id))
		equip_list.add_child(btn)

func _do_equip(id: String) -> void:
	GameState.equip_item(id)
	_rebuild_equip()

func _rebuild_quests() -> void:
	if not quest_list:
		return
	for c in quest_list.get_children():
		c.queue_free()
	for q in Data.QUESTS:
		var done: bool = GameState.quest_done.get(q.id, false)
		var prog: int = int(GameState.quest_progress.get(q.id, 0))
		var line := Label.new()
		var status := "DONE" if done else "%d / %d" % [prog, q.goal]
		line.text = "[%s] %s — %s" % [status, q.name, q.desc]
		quest_list.add_child(line)
		if not done and prog >= int(q.goal):
			var claim := Button.new()
			claim.text = "Claim reward (+%dg +%dxp)" % [q.gold, q.xp]
			claim.pressed.connect(_claim_quest.bind(q))
			quest_list.add_child(claim)

func _claim_quest(q: Dictionary) -> void:
	GameState.quest_done[q.id] = true
	GameState.gold += int(q.gold)
	GameState.xp += int(q.xp)
	GameState._check_level_up()
	GameState.player_stats_changed.emit()
	_show_message("Quest complete: %s" % q.name)
	_rebuild_quests()

func _exit_tree() -> void:
	if _mario_created and mario and mario.has_method("delete"):
		mario.delete()
