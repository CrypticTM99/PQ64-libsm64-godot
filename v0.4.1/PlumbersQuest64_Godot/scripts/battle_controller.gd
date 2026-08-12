extends Node3D
## Timed-counter battle prototype with full Attack / Defend / Magic / Item / Flee / Skills.

@onready var mario: Node3D = $LibSM64Mario
@onready var surface_handler: Node = $LibSM64StaticSurfaceHandler
@onready var camera: Camera3D = $Camera3D
@onready var enemy_mesh: MeshInstance3D = $EnemyPlaceholder
@onready var enemy_label: Label3D = $EnemyPlaceholder/NameLabel

@onready var player_hp: Label = $BattleUI/TopBar/PlayerHP
@onready var enemy_hp: Label = $BattleUI/TopBar/EnemyHP
@onready var phase_label: Label = $BattleUI/TopBar/PhaseLabel
@onready var message_label: Label = $BattleUI/BattleMessage
@onready var counter_prompt: Label = $BattleUI/CounterPrompt
@onready var command_panel: PanelContainer = $BattleUI/CommandPanel
@onready var skill_panel: PanelContainer = $BattleUI/SkillPanel
@onready var magic_panel: PanelContainer = $BattleUI/MagicPanel
@onready var item_panel: PanelContainer = $BattleUI/ItemPanel
@onready var skill_list: VBoxContainer = $BattleUI/SkillPanel/SkillList
@onready var magic_list: VBoxContainer = $BattleUI/MagicPanel/MagicList
@onready var item_list: VBoxContainer = $BattleUI/ItemPanel/ItemList
@onready var result_panel: PanelContainer = $BattleUI/ResultPanel
@onready var result_label: Label = $BattleUI/ResultPanel/VBox/ResultLabel

var _mario_created: bool = false
var _approach_t: float = 0.0

const COUNTER_MIN := 1.5
const COUNTER_MAX := 2.6
const APPROACH_DURATION := 0.55
const RETURN_DURATION := 0.45
const WAIT_DURATION := 0.55

func _ready() -> void:
	GameState.battle_phase_changed.connect(_on_phase)
	GameState.player_stats_changed.connect(_refresh_hud)
	GameState.enemy_hp_changed.connect(_refresh_hud)
	GameState.message.connect(_show_msg)
	GameState.battle_ended.connect(_on_battle_ended)
	if result_panel:
		result_panel.visible = false
	_hide_submenus()
	_setup_enemy_visual()
	_init_libsm64()
	_refresh_hud()
	_on_phase(GameState.phase)

func _init_libsm64() -> void:
	if not GameState.rom_ready:
		return
	SM64Helpers.load_group_as_static_surfaces(&"libsm64_static_surfaces")
	if mario and mario.has_method("create"):
		if "camera" in mario:
			mario.camera = camera
		mario.global_position = GameState.mario_home
		mario.create()
		_mario_created = true

func _setup_enemy_visual() -> void:
	var col: Color = GameState.enemy.get("color", Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	enemy_mesh.material_override = mat
	enemy_mesh.global_position = GameState.enemy_home
	enemy_label.text = str(GameState.enemy.get("name", "Enemy"))
	enemy_mesh.visible = true

func _refresh_hud() -> void:
	if player_hp:
		player_hp.text = "HP %d/%d   MP %d/%d" % [GameState.hp, GameState.max_hp, GameState.mp, GameState.max_mp]
	var ehp: int = int(GameState.enemy.get("current_hp", 0))
	var emax: int = int(GameState.enemy.get("hp", 1))
	if enemy_hp:
		enemy_hp.text = "%s  HP %d/%d" % [GameState.enemy.get("name", "?"), ehp, emax]
	var phase_names := ["SELECT", "APPROACH", "ATTACK", "DAMAGE", "RETURN", "WAIT",
		"E-APPROACH", "E-ATTACK", "E-RETURN"]
	if phase_label:
		phase_label.text = phase_names[clampi(GameState.phase, 0, phase_names.size() - 1)]

func _show_msg(text: String) -> void:
	if not message_label:
		return
	message_label.text = text
	message_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(message_label, "modulate:a", 0.0, 0.4)

func _on_phase(p: int) -> void:
	if counter_prompt:
		counter_prompt.visible = false
	if command_panel:
		command_panel.visible = (p == Data.BattlePhase.BP_SELECT)
	_hide_submenus()
	match p:
		Data.BattlePhase.BP_SELECT:
			pass
		Data.BattlePhase.BP_APPROACH:
			_approach_t = 0.0
		Data.BattlePhase.BP_ATTACK:
			_do_player_attack()
		Data.BattlePhase.BP_E_APPROACH:
			GameState.can_counter = false
			GameState.counter_success = false
			_approach_t = 0.0
		Data.BattlePhase.BP_E_ATTACK:
			_do_enemy_attack()

func _process(delta: float) -> void:
	if GameState.state != Data.GameState.S_BATTLE:
		return
	GameState.b_timer += delta

	match GameState.phase:
		Data.BattlePhase.BP_APPROACH:
			_approach_t += delta
			# simple visual move of enemy/mario positions optional
			if _approach_t >= APPROACH_DURATION:
				GameState.change_phase(Data.BattlePhase.BP_ATTACK)

		Data.BattlePhase.BP_RETURN:
			if GameState.b_timer >= RETURN_DURATION:
				GameState.is_player_turn = false
				GameState.change_phase(Data.BattlePhase.BP_WAIT)

		Data.BattlePhase.BP_E_APPROACH:
			_approach_t += delta
			# distance simulation for counter window
			var dist := lerpf(6.0, 0.9, clampf(_approach_t / APPROACH_DURATION, 0.0, 1.0))
			GameState.can_counter = (dist >= COUNTER_MIN and dist <= COUNTER_MAX)
			counter_prompt.visible = GameState.can_counter and not GameState.counter_success
			if _approach_t >= APPROACH_DURATION:
				GameState.change_phase(Data.BattlePhase.BP_E_ATTACK)

		Data.BattlePhase.BP_E_RETURN:
			if GameState.b_timer >= RETURN_DURATION:
				GameState.is_player_turn = true
				GameState.change_phase(Data.BattlePhase.BP_WAIT)

		Data.BattlePhase.BP_WAIT:
			if GameState.b_timer >= WAIT_DURATION:
				if int(GameState.enemy.get("current_hp", 0)) <= 0:
					GameState.end_battle(true)
				elif GameState.hp <= 0:
					GameState.end_battle(false)
				elif GameState.is_player_turn:
					GameState.change_phase(Data.BattlePhase.BP_SELECT)
				else:
					GameState.change_phase(Data.BattlePhase.BP_E_APPROACH)

func _do_player_attack() -> void:
	var atk := GameState.total_atk()
	var e_def: int = int(GameState.enemy.get("def", 0))
	var dmg := maxi(1, atk - e_def + randi_range(-3, 6))
	var is_crit := randi_range(0, 99) < GameState.total_crit()
	if is_crit:
		dmg = int(dmg * 1.9)
	GameState.apply_damage_to_enemy(dmg, is_crit)
	GameState.change_phase(Data.BattlePhase.BP_RETURN)

func _do_enemy_attack() -> void:
	var e_atk: int = int(GameState.enemy.get("atk", 5))
	var dmg := maxi(1, e_atk - GameState.total_def() + randi_range(-2, 5))
	if GameState.counter_success:
		dmg = maxi(1, int(dmg * 0.25))
		var c_dmg := maxi(1, int(GameState.total_atk() * 0.85))
		GameState.apply_damage_to_enemy(c_dmg)
		_show_msg("Counter damage %d!" % c_dmg)
	GameState.apply_damage_to_player(dmg)
	GameState.defend_bonus = 0
	# poison tick
	if GameState.status_poison_turns > 0:
		var pd := maxi(1, int(GameState.max_hp * 0.04))
		GameState.hp = maxi(0, GameState.hp - pd)
		GameState.status_poison_turns -= 1
		GameState.player_stats_changed.emit()
		_show_msg("Poison: -%d HP" % pd)
	GameState.change_phase(Data.BattlePhase.BP_E_RETURN)

# ---------- Commands ----------
func command_attack() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	GameState.change_phase(Data.BattlePhase.BP_APPROACH)

func command_defend() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	GameState.defend_bonus = 7
	_show_msg("Defending (+7 DEF)")
	GameState.is_player_turn = false
	GameState.change_phase(Data.BattlePhase.BP_WAIT)

func command_flee() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	var chance := 50 + GameState.total_crit() / 2
	if GameState.class_id == 2:
		chance += 25
	if GameState.enemy.get("is_boss", false):
		chance = 15
	if randi_range(0, 99) < chance:
		_show_msg("Got away safely!")
		await get_tree().create_timer(0.8).timeout
		_return_to_town()
	else:
		_show_msg("Couldn't escape!")
		GameState.is_player_turn = false
		GameState.change_phase(Data.BattlePhase.BP_WAIT)

func command_skills() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	_hide_submenus()
	skill_panel.visible = true
	for c in skill_list.get_children():
		c.queue_free()
	if GameState.class_id < 0:
		return
	var skills: Array = Data.CLASSES[GameState.class_id].skills
	for s in skills:
		var btn := Button.new()
		var locked := GameState.level < int(s.lvl)
		btn.text = "%s  (Lv%d)  %s" % [s.name, s.lvl, s.desc]
		btn.disabled = locked
		btn.pressed.connect(_use_skill.bind(s))
		skill_list.add_child(btn)

func command_magic() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	_hide_submenus()
	magic_panel.visible = true
	for c in magic_list.get_children():
		c.queue_free()
	for sp in Data.SPELLS:
		var btn := Button.new()
		btn.text = "%s  (%d MP)  %s" % [sp.name, sp.mp, sp.desc]
		btn.disabled = GameState.mp < int(sp.mp)
		btn.pressed.connect(_use_spell.bind(sp))
		magic_list.add_child(btn)

func command_item() -> void:
	if GameState.phase != Data.BattlePhase.BP_SELECT:
		return
	_hide_submenus()
	item_panel.visible = true
	for c in item_list.get_children():
		c.queue_free()
	var any := false
	for id in GameState.inventory:
		var count: int = GameState.inventory[id]
		if count <= 0:
			continue
		var item: Dictionary = {}
		for cons in Data.SHOP_CONSUMABLES:
			if cons.id == id:
				item = cons
				break
		if item.is_empty():
			continue
		any = true
		var btn := Button.new()
		btn.text = "%s  x%d" % [item.name, count]
		btn.pressed.connect(_use_item.bind(id))
		item_list.add_child(btn)
	if not any:
		var empty := Label.new()
		empty.text = "(no consumables)"
		item_list.add_child(empty)

func _use_skill(s: Dictionary) -> void:
	_hide_submenus()
	var mp_cost := int(s.get("mp", 0))
	if GameState.mp < mp_cost:
		_show_msg("Not enough MP")
		return
	GameState.mp -= mp_cost
	GameState.player_stats_changed.emit()
	var name: String = s.name
	match name:
		"Power Strike":
			var dmg := maxi(1, int(GameState.total_atk() * 1.9) - int(GameState.enemy.def) + randi_range(-2, 4))
			GameState.apply_damage_to_enemy(dmg, true)
		"Guard Break":
			var dmg2 := maxi(1, GameState.total_atk() - int(GameState.enemy.def * 0.5) + randi_range(-2, 5))
			GameState.apply_damage_to_enemy(dmg2)
		"War Cry":
			GameState.active_buff = {"atk": 5, "battles_remaining": 2}
			GameState.hp = mini(GameState.max_hp, GameState.hp + 25)
			GameState.player_stats_changed.emit()
			_show_msg("War Cry! +ATK & heal")
		"Shadow Step":
			var dmg3 := maxi(1, int(GameState.total_atk() * 1.5) - int(GameState.enemy.def))
			GameState.apply_damage_to_enemy(dmg3, true)
			GameState.hp = mini(GameState.max_hp, GameState.hp + 12)
		"Poison Blade":
			var dmg4 := maxi(1, GameState.total_atk() - int(GameState.enemy.def) + 4)
			GameState.apply_damage_to_enemy(dmg4)
			GameState.status_poison_turns = 3  # applied to enemy conceptually; simplified as player poison for now
			_show_msg("Poison applied!")
		"Vanish":
			_show_msg("Vanish – next attack will crit, high flee")
			GameState.active_buff = {"crit": 40, "battles_remaining": 1}
		"Arcane Focus":
			var dmg5 := maxi(1, int(GameState.total_atk() * 1.3) + 8)
			GameState.apply_damage_to_enemy(dmg5)
			GameState.mp = mini(GameState.max_mp, GameState.mp + 10)
		"Elemental Burst":
			var dmg6 := maxi(1, int(GameState.total_atk() * 2.1) - int(GameState.enemy.def))
			GameState.apply_damage_to_enemy(dmg6, true)
		"Mana Shield":
			_show_msg("Mana Shield active this turn")
			GameState.defend_bonus = 12
	GameState.is_player_turn = false
	GameState.change_phase(Data.BattlePhase.BP_WAIT)

func _use_spell(sp: Dictionary) -> void:
	_hide_submenus()
	if GameState.mp < int(sp.mp):
		_show_msg("Not enough MP")
		return
	GameState.mp -= int(sp.mp)
	GameState.spells_cast += 1
	GameState.player_stats_changed.emit()
	if sp.type == "heal":
		var heal := int(sp.get("heal", 40))
		GameState.hp = mini(GameState.max_hp, GameState.hp + heal)
		GameState.player_stats_changed.emit()
		_show_msg("Healed %d" % heal)
	else:
		var dmg := maxi(1, int(GameState.total_atk() * float(sp.power)) - int(GameState.enemy.def / 2) + randi_range(-2, 6))
		GameState.apply_damage_to_enemy(dmg)
	GameState.is_player_turn = false
	GameState.change_phase(Data.BattlePhase.BP_WAIT)

func _use_item(id: String) -> void:
	_hide_submenus()
	if GameState.use_item(id):
		GameState.is_player_turn = false
		GameState.change_phase(Data.BattlePhase.BP_WAIT)

func _hide_submenus() -> void:
	if skill_panel:
		skill_panel.visible = false
	if magic_panel:
		magic_panel.visible = false
	if item_panel:
		item_panel.visible = false

func _on_battle_ended(victory: bool) -> void:
	if result_panel:
		result_panel.visible = true
	if result_label:
		result_label.text = "VICTORY!" if victory else "DEFEAT..."
	if command_panel:
		command_panel.visible = false
	if counter_prompt:
		counter_prompt.visible = false

func _on_result_continue() -> void:
	_return_to_town()

func _return_to_town() -> void:
	if _mario_created and mario and mario.has_method("delete"):
		mario.delete()
		_mario_created = false
	get_tree().change_scene_to_file("res://scenes/town.tscn")

func _input(event: InputEvent) -> void:
	if GameState.state != Data.GameState.S_BATTLE:
		return
	if GameState.phase == Data.BattlePhase.BP_E_APPROACH and GameState.can_counter:
		if (event.is_action_pressed("mario_a")
			or event.is_action_pressed("libsm64_mario_inputs_button_a")
			or event.is_action_pressed("ui_accept")):
			GameState.try_counter()
			counter_prompt.visible = false

func _exit_tree() -> void:
	if _mario_created and mario and mario.has_method("delete"):
		mario.delete()
