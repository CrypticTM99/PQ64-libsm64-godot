extends Node
## Central state machine, player progression, battle runtime.
## Autoloaded as GameState.

signal state_changed(new_state: int)
signal battle_phase_changed(new_phase: int)
signal player_stats_changed
signal message(text: String)
signal enemy_hp_changed
signal battle_ended(victory: bool)

var state: int = Data.GameState.S_BOOT
var phase: int = Data.BattlePhase.BP_SELECT
var b_timer: float = 0.0

# Player
var class_id: int = -1
var level: int = 1
var xp: int = 0
var gold: int = 50
var max_hp: int = 100
var hp: int = 100
var max_mp: int = 30
var mp: int = 30
var base_atk: int = 10
var base_def: int = 5
var base_crit: int = 5

var inventory: Dictionary = {}   # id -> count
var equipment: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
var active_buff: Dictionary = {}
var quest_progress: Dictionary = {}
var quest_done: Dictionary = {}
var partner_hired: bool = false
var kills: int = 0
var counters: int = 0
var spells_cast: int = 0

# Battle
var enemy: Dictionary = {}
var can_counter: bool = false
var counter_success: bool = false
var pending_damage: int = 0
var is_player_turn: bool = true
var defend_bonus: int = 0
var last_damage: int = 0
var last_was_crit: bool = false
var status_poison_turns: int = 0

# Positions (Godot units, scale_factor 100)
var mario_home := Vector3(0, 0.8, 2.5)
var enemy_home := Vector3(0, 0.9, -5.0)

var rom_ready: bool = false

func _ready() -> void:
	randomize()

func change_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)

func change_phase(new_phase: int) -> void:
	phase = new_phase
	b_timer = 0.0
	battle_phase_changed.emit(phase)

func select_class(idx: int) -> void:
	if idx < 0 or idx >= Data.CLASSES.size():
		return
	class_id = idx
	var c: Dictionary = Data.CLASSES[idx]
	max_hp = c.hp
	hp = max_hp
	max_mp = c.mp
	mp = max_mp
	base_atk = c.atk
	base_def = c.def
	base_crit = c.crit
	level = 1
	xp = 0
	gold = 50
	inventory = {"potion": 3, "ether": 1}
	equipment = {"weapon": "", "armor": "", "accessory": ""}
	active_buff = {}
	quest_progress = {}
	quest_done = {}
	kills = 0
	counters = 0
	spells_cast = 0
	player_stats_changed.emit()
	change_state(Data.GameState.S_TOWN)

func total_atk() -> int:
	var v := base_atk + _gear_stat("atk")
	if active_buff.has("atk"):
		v += int(active_buff.atk)
	return v

func total_def() -> int:
	var v := base_def + _gear_stat("def") + defend_bonus
	if active_buff.has("def"):
		v += int(active_buff.def)
	return v

func total_crit() -> int:
	var v := base_crit + _gear_stat("crit")
	if active_buff.has("crit"):
		v += int(active_buff.crit)
	return clampi(v, 0, 95)

func _gear_stat(stat: String) -> int:
	var total := 0
	for slot in equipment:
		var gid: String = str(equipment[slot])
		if gid.is_empty():
			continue
		var g := Data.get_gear(gid)
		if not g.is_empty():
			total += int(g.get(stat, 0))
	return total

func start_battle(enemy_data: Dictionary) -> void:
	enemy = Data.scale_enemy(enemy_data, level)
	can_counter = false
	counter_success = false
	defend_bonus = 0
	is_player_turn = true
	last_damage = 0
	last_was_crit = false
	status_poison_turns = 0
	change_phase(Data.BattlePhase.BP_SELECT)
	change_state(Data.GameState.S_BATTLE)
	enemy_hp_changed.emit()

func end_battle(victory: bool) -> void:
	if victory:
		kills += 1
		var g_gain := int(enemy.get("gold", 0))
		var x_gain := int(enemy.get("xp", 0))
		if active_buff.get("gold_mult", 1.0) > 1.0:
			g_gain = int(g_gain * active_buff.gold_mult)
		xp += x_gain
		gold += g_gain
		_check_level_up()
		_update_quests()
		_tick_buff()
		message.emit("Victory! +%d XP  +%d Gold" % [x_gain, g_gain])
	else:
		message.emit("Defeated...")
	battle_ended.emit(victory)
	change_state(Data.GameState.S_VICTORY if victory else Data.GameState.S_DEFEAT)

func _check_level_up() -> void:
	while xp >= Data.xp_needed(level):
		xp -= Data.xp_needed(level)
		level += 1
		max_hp += 12
		max_mp += 4
		base_atk += 2
		base_def += 1
		hp = max_hp
		mp = max_mp
		message.emit("Level up! Now level %d" % level)
		player_stats_changed.emit()

func _tick_buff() -> void:
	if active_buff.is_empty():
		return
	active_buff["battles_remaining"] = int(active_buff.get("battles_remaining", 1)) - 1
	if active_buff.battles_remaining <= 0:
		if active_buff.has("hp"):
			max_hp = maxi(1, max_hp - int(active_buff.hp))
			hp = mini(hp, max_hp)
		if active_buff.has("mp"):
			max_mp = maxi(0, max_mp - int(active_buff.mp))
			mp = mini(mp, max_mp)
		active_buff = {}
		message.emit("Temporary buff expired.")
		player_stats_changed.emit()

func _update_quests() -> void:
	for q in Data.QUESTS:
		if quest_done.get(q.id, false):
			continue
		match q.type:
			"kills":
				quest_progress[q.id] = kills
			"level":
				quest_progress[q.id] = level
			"counters":
				quest_progress[q.id] = counters
			"boss":
				if enemy.get("is_boss", false) and enemy.name == "Bomb King":
					quest_progress[q.id] = 1
			"bowser":
				if enemy.get("is_boss", false) and enemy.name == "Bowser":
					quest_progress[q.id] = 1

func apply_damage_to_enemy(amount: int, is_crit: bool = false) -> void:
	enemy.current_hp = maxi(0, int(enemy.current_hp) - amount)
	last_damage = amount
	last_was_crit = is_crit
	enemy_hp_changed.emit()
	if is_crit:
		message.emit("Critical! %d damage" % amount)
	else:
		message.emit("%d damage" % amount)

func apply_damage_to_player(amount: int) -> void:
	hp = maxi(0, hp - amount)
	last_damage = amount
	last_was_crit = false
	player_stats_changed.emit()
	message.emit("Took %d damage" % amount)

func try_counter() -> bool:
	if not can_counter or counter_success:
		return false
	counter_success = true
	counters += 1
	message.emit("COUNTER!")
	return true

func use_item(item_id: String) -> bool:
	if not inventory.has(item_id) or inventory[item_id] <= 0:
		return false
	var item: Dictionary = {}
	for c in Data.SHOP_CONSUMABLES:
		if c.id == item_id:
			item = c
			break
	if item.is_empty():
		return false
	inventory[item_id] -= 1
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	if item.get("heal", 0) > 0:
		hp = mini(max_hp, hp + int(item.heal))
	if item.get("mp", 0) > 0:
		mp = mini(max_mp, mp + int(item.mp))
	player_stats_changed.emit()
	message.emit("Used %s" % item.name)
	return true

func equip_item(gear_id: String) -> void:
	var g := Data.get_gear(gear_id)
	if g.is_empty():
		return
	var slot: String = g.slot
	# unequip old
	var old: String = str(equipment.get(slot, ""))
	if not old.is_empty():
		inventory[old] = inventory.get(old, 0) + 1
	equipment[slot] = gear_id
	if inventory.has(gear_id):
		inventory[gear_id] -= 1
		if inventory[gear_id] <= 0:
			inventory.erase(gear_id)
	# accessory bonuses
	if g.has("hp_bonus"):
		max_hp += int(g.hp_bonus)
		hp = mini(hp + int(g.hp_bonus), max_hp)
	if g.has("mp_bonus"):
		max_mp += int(g.mp_bonus)
		mp = mini(mp + int(g.mp_bonus), max_mp)
	player_stats_changed.emit()
	message.emit("Equipped %s" % g.name)

# ---------- Save / Load ----------
func save_game(path: String = "user://pq64_save.json") -> void:
	var data := {
		"class_id": class_id, "level": level, "xp": xp, "gold": gold,
		"max_hp": max_hp, "hp": hp, "max_mp": max_mp, "mp": mp,
		"base_atk": base_atk, "base_def": base_def, "base_crit": base_crit,
		"inventory": inventory, "equipment": equipment, "active_buff": active_buff,
		"quest_progress": quest_progress, "quest_done": quest_done,
		"partner_hired": partner_hired, "kills": kills, "counters": counters,
		"spells_cast": spells_cast,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		message.emit("Game saved.")

func load_game(path: String = "user://pq64_save.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return false
	var data: Dictionary = json.data
	class_id = int(data.get("class_id", -1))
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	gold = int(data.get("gold", 0))
	max_hp = int(data.get("max_hp", 100))
	hp = int(data.get("hp", max_hp))
	max_mp = int(data.get("max_mp", 30))
	mp = int(data.get("mp", max_mp))
	base_atk = int(data.get("base_atk", 10))
	base_def = int(data.get("base_def", 5))
	base_crit = int(data.get("base_crit", 5))
	inventory = data.get("inventory", {})
	equipment = data.get("equipment", {"weapon": "", "armor": "", "accessory": ""})
	active_buff = data.get("active_buff", {})
	quest_progress = data.get("quest_progress", {})
	quest_done = data.get("quest_done", {})
	partner_hired = bool(data.get("partner_hired", false))
	kills = int(data.get("kills", 0))
	counters = int(data.get("counters", 0))
	spells_cast = int(data.get("spells_cast", 0))
	player_stats_changed.emit()
	message.emit("Game loaded.")
	return true
