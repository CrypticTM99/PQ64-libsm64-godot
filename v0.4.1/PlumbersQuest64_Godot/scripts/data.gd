extends Node
## Data tables ported from the original Plumber's Quest 64 Lua mod.
## Autoloaded as Data.

const CLASSES := [
	{
		"name": "Warrior",
		"hp": 130, "mp": 25, "atk": 17, "def": 11, "crit": 8,
		"desc": "High HP, ATK and DEF. Power skills.",
		"skills": [
			{"name": "Power Strike", "lvl": 1, "mp": 0, "desc": "Spinning smash (1.9x ATK)"},
			{"name": "Guard Break", "lvl": 5, "mp": 8, "desc": "Ignore 50% enemy DEF"},
			{"name": "War Cry", "lvl": 10, "mp": 12, "desc": "+ATK and heal for 2 turns"},
		]
	},
	{
		"name": "Mage",
		"hp": 90, "mp": 60, "atk": 11, "def": 6, "crit": 10,
		"desc": "Powerful magic, high MP.",
		"skills": [
			{"name": "Arcane Focus", "lvl": 1, "mp": 6, "desc": "Magic hit + restore MP"},
			{"name": "Elemental Burst", "lvl": 5, "mp": 14, "desc": "Strong multi-element hit"},
			{"name": "Mana Shield", "lvl": 10, "mp": 10, "desc": "Absorb damage with MP"},
		]
	},
	{
		"name": "Rogue",
		"hp": 100, "mp": 35, "atk": 15, "def": 7, "crit": 24,
		"desc": "High crit and flee. Stealth skills.",
		"skills": [
			{"name": "Shadow Step", "lvl": 1, "mp": 5, "desc": "Guaranteed crit + small heal"},
			{"name": "Poison Blade", "lvl": 5, "mp": 9, "desc": "Apply Poison for 3 turns"},
			{"name": "Vanish", "lvl": 10, "mp": 8, "desc": "High flee + next attack crit"},
		]
	},
]

const ENEMIES := [
	{"name": "Goomba Scout", "hp": 32, "atk": 8, "def": 2, "xp": 15, "gold": 11, "weak": false, "safe": true, "min_level": 1, "color": Color(0.86, 0.71, 0.39)},
	{"name": "Koopa Trooper", "hp": 48, "atk": 12, "def": 5, "xp": 26, "gold": 19, "weak": true, "safe": true, "min_level": 1, "color": Color(0.31, 0.71, 0.31)},
	{"name": "Boo Phantom", "hp": 58, "atk": 14, "def": 3, "xp": 34, "gold": 26, "weak": false, "safe": true, "min_level": 1, "color": Color(0.71, 0.71, 0.86)},
	{"name": "Thwomp Sentinel", "hp": 75, "atk": 16, "def": 10, "xp": 45, "gold": 32, "weak": false, "safe": true, "min_level": 2, "color": Color(0.55, 0.55, 0.63)},
	{"name": "Chuckya Brute", "hp": 85, "atk": 19, "def": 6, "xp": 55, "gold": 40, "weak": true, "safe": true, "min_level": 3, "color": Color(0.78, 0.47, 0.24)},
	{"name": "Piranha Plant", "hp": 55, "atk": 15, "def": 4, "xp": 30, "gold": 22, "weak": false, "safe": true, "min_level": 1, "color": Color(0.16, 0.63, 0.16)},
	{"name": "Bob-omb Grunt", "hp": 42, "atk": 12, "def": 4, "xp": 22, "gold": 15, "weak": true, "safe": false, "min_level": 1, "color": Color(0.2, 0.2, 0.2)},
	{"name": "Scuttlebug", "hp": 52, "atk": 16, "def": 4, "xp": 32, "gold": 24, "weak": false, "safe": false, "min_level": 2, "color": Color(0.39, 0.24, 0.16)},
	{"name": "Bully Bruiser", "hp": 65, "atk": 18, "def": 6, "xp": 42, "gold": 30, "weak": true, "safe": false, "min_level": 3, "color": Color(0.71, 0.31, 0.16)},
	{"name": "Fly Guy Elite", "hp": 95, "atk": 22, "def": 8, "xp": 70, "gold": 55, "weak": false, "safe": true, "min_level": 8, "color": Color(0.86, 0.39, 0.39)},
]

const BOSSES := [
	{"name": "Bomb King", "hp": 220, "atk": 28, "def": 12, "xp": 180, "gold": 150, "weak": false, "safe": false, "min_level": 10, "color": Color(0.9, 0.2, 0.15), "is_boss": true},
	{"name": "Bowser", "hp": 420, "atk": 38, "def": 18, "xp": 400, "gold": 300, "weak": false, "safe": false, "min_level": 15, "color": Color(0.2, 0.7, 0.25), "is_boss": true},
]

const SPELLS := [
	{"name": "Fireball", "mp": 8, "power": 1.45, "type": "fire", "desc": "Basic fire projectile"},
	{"name": "Ice Shard", "mp": 10, "power": 1.35, "type": "ice", "desc": "Chance to freeze"},
	{"name": "Thunder", "mp": 14, "power": 1.75, "type": "thunder", "desc": "Strong single-target"},
	{"name": "Heal", "mp": 12, "power": 0.0, "type": "heal", "heal": 45, "desc": "Restore HP"},
]

const GEAR := [
	{"id": "wood_sword", "name": "Wood Sword", "slot": "weapon", "atk": 3, "def": 0, "crit": 0, "price": 40},
	{"id": "iron_sword", "name": "Iron Sword", "slot": "weapon", "atk": 8, "def": 0, "crit": 2, "price": 120},
	{"id": "steel_blade", "name": "Steel Blade", "slot": "weapon", "atk": 14, "def": 0, "crit": 4, "price": 220},
	{"id": "leather_armor", "name": "Leather Armor", "slot": "armor", "atk": 0, "def": 4, "crit": 0, "price": 60},
	{"id": "chainmail", "name": "Chainmail", "slot": "armor", "atk": 0, "def": 7, "crit": 0, "price": 80},
	{"id": "knight_plate", "name": "Knight Plate", "slot": "armor", "atk": 1, "def": 13, "crit": 0, "price": 170},
	{"id": "mage_ring", "name": "Mage Ring", "slot": "accessory", "atk": 0, "def": 0, "crit": 0, "mp_bonus": 12, "price": 60},
	{"id": "power_band", "name": "Power Band", "slot": "accessory", "atk": 5, "def": 0, "crit": 0, "price": 95},
	{"id": "guardian_amulet", "name": "Guardian Amulet", "slot": "accessory", "atk": 0, "def": 4, "crit": 0, "hp_bonus": 20, "price": 110},
	{"id": "lucky_charm", "name": "Lucky Charm", "slot": "accessory", "atk": 1, "def": 1, "crit": 5, "price": 45},
]

const SHOP_CONSUMABLES := [
	{"id": "potion", "name": "Potion", "heal": 45, "mp": 0, "price": 15},
	{"id": "hi_potion", "name": "Hi-Potion", "heal": 90, "mp": 0, "price": 42},
	{"id": "ether", "name": "Ether", "heal": 0, "mp": 30, "price": 28},
	{"id": "elixir", "name": "Elixir", "heal": 999, "mp": 999, "price": 90},
]

const QUESTS := [
	{"id": "first_blood", "name": "First Blood", "desc": "Win 5 battles", "type": "kills", "goal": 5, "gold": 60, "xp": 40},
	{"id": "rising_star", "name": "Rising Star", "desc": "Reach level 5", "type": "level", "goal": 5, "gold": 80, "xp": 0},
	{"id": "gear_up", "name": "Gear Up", "desc": "Equip a weapon and armor", "type": "equip", "goal": 1, "gold": 50, "xp": 30},
	{"id": "counter_master", "name": "Counter Master", "desc": "Land 5 timed counters", "type": "counters", "goal": 5, "gold": 100, "xp": 60},
	{"id": "bomb_king", "name": "Bomb King Slayer", "desc": "Defeat the Bomb King", "type": "boss", "goal": 1, "gold": 150, "xp": 100},
	{"id": "bowser_slayer", "name": "Bowser Slayer", "desc": "Defeat Bowser (Lv15+)", "type": "bowser", "goal": 1, "gold": 300, "xp": 200},
]

const LOOT_BUFFS := [
	{"id": "atk_up", "name": "Power Surge", "desc": "+4 ATK for 3 battles", "atk": 4, "battles": 3},
	{"id": "def_up", "name": "Iron Skin", "desc": "+4 DEF for 3 battles", "def": 4, "battles": 3},
	{"id": "crit_up", "name": "Lucky Edge", "desc": "+10 Crit for 3 battles", "crit": 10, "battles": 3},
	{"id": "hp_up", "name": "Vitality", "desc": "+25 Max HP for 3 battles", "hp": 25, "battles": 3},
	{"id": "mp_up", "name": "Mana Well", "desc": "+15 Max MP for 3 battles", "mp": 15, "battles": 3},
]

enum GameState {
	S_BOOT = 0,
	S_CLASS = 1,
	S_TOWN = 3,
	S_BATTLE = 4,
	S_VICTORY = 5,
	S_DEFEAT = 6,
	S_SHOP = 8,
	S_EQUIP = 9,
	S_LEVELUP = 10,
	S_QUESTS = 11,
	S_LOOTBOX = 12,
}

enum BattlePhase {
	BP_SELECT = 0,
	BP_APPROACH = 1,
	BP_ATTACK = 2,
	BP_DAMAGE = 3,
	BP_RETURN = 4,
	BP_WAIT = 5,
	BP_E_APPROACH = 6,
	BP_E_ATTACK = 7,
	BP_E_RETURN = 8,
}

func xp_needed(level: int) -> int:
	return level * 52 + 40 + level * 3

func scale_enemy(base: Dictionary, player_level: int) -> Dictionary:
	var e := base.duplicate(true)
	var bonus := maxi(0, player_level - 1)
	e["hp"] = int(base.hp + bonus * 11)
	e["atk"] = int(base.atk + bonus * 2)
	e["def"] = int(base.def + bonus * 1)
	e["current_hp"] = e.hp
	return e

func get_gear(id: String) -> Dictionary:
	for g in GEAR:
		if g.id == id:
			return g
	return {}
