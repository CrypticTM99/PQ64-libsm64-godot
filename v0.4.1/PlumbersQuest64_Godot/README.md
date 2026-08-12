# Plumber's Quest 64 – libsm64-godot Prototype

Playable prototype of the Plumber's Quest 64 RPG system running on **authentic Super Mario 64 Mario physics** via the [libsm64-godot](https://github.com/Brawmario/libsm64-godot) GDExtension.

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **Godot** | 4.3 or 4.4 |
| **Addon** | [Libsm64 Godot](https://godotengine.org/asset-library/asset/3653) (v2.7.x) — also on [GitHub Releases](https://github.com/Brawmario/libsm64-godot/releases) |
| **ROM** | Legitimate **Super Mario 64 (USA)** `.z64` / `.n64` / `.v64` |
| | SHA-256 must be: `17ce077343c6133f8c9f2d6d6d9a4ab62c8cd2aa57c40aea1f490b4c8bb21d91` |

**Legal**: Never redistribute the ROM. The game loads it at runtime and verifies the hash. This is a fan reimplementation.

---

## Setup (5 minutes)

1. Open this folder in **Godot 4.3+**.
2. **Asset Library** → search **“Libsm64 Godot”** → Download → Install.  
   Or extract a release zip so you have `addons/libsm64_godot/` inside the project.
3. **Project → Project Settings → Plugins** → enable **Libsm64 Godot**.
4. Open `scenes/town.tscn` and `scenes/battle.tscn`:
   - Select the node named `LibSM64StaticSurfaceHandler` → change its **Type** to `LibSM64StaticSurfaceHandler`.
   - Select the node named `LibSM64Mario` → change its **Type** to `LibSM64Mario`.
   - In the `LibSM64Mario` inspector:
     - **Camera** → pick the scene’s `Camera3D`.
     - Under **Mario Inputs Actions** set:
       - Stick Left / Right / Up / Down → `mario_stick_left` etc.
       - A / B / Z → `mario_a`, `mario_b`, `mario_z`
5. Press **F5**. Select your SM64 USA ROM → choose a class → Town.

After the first successful run the ROM path is remembered.

---

## What works in this prototype

| Feature | Status |
|---------|--------|
| ROM load + hash check + `LibSM64Global.init()` | Yes |
| Static surface loading from mesh group | Yes (after type change) |
| Controllable Mario in Town (WASD / stick, A jump) | Yes |
| Class select (Warrior / Mage / Rogue) | Yes |
| Turn-based battle with phases | Yes |
| **Timed counter window** (press A while enemy approaches) | Yes |
| Attack / Defend / Flee | Yes |
| Class Skills (level-gated) | Yes |
| Magic spells + Items | Yes |
| Shop (buy consumables + gear) | Yes |
| Equip system + derived stats | Yes |
| Quest log + claim rewards | Yes |
| Level-up, XP curve, save / load | Yes |
| Boss encounters (Bomb King / Bowser at high level) | Yes (chance) |

Mario is frozen for movement during battle menus (input still read for the counter). Full free-move Mario returns when you go back to Town.

---

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | WASD | Left stick |
| Jump / Confirm / Counter | Space | A / Cross |
| B / Cancel | Shift | B / Circle |
| Z | Ctrl | L1 / LB |
| UI | Enter / Esc | A / B |

---

## Project structure

```
PlumbersQuest64_Godot/
├── project.godot
├── README.md
├── icon.svg
├── scenes/
│   ├── boot.tscn      # ROM + class select
│   ├── town.tscn      # Hub + Mario + Shop/Equip/Quests
│   └── battle.tscn    # Full battle prototype
└── scripts/
    ├── data.gd            # All tables from original Lua
    ├── game_state.gd      # State machine, stats, save
    ├── boot.gd
    ├── town.gd
    └── battle_controller.gd
```

---

## Next steps (optional)

- Import SM64 actor meshes for enemies instead of capsules
- Camera follow / lock behind Mario
- Partner companion
- Full loot-box UI after victory
- `LibSM64AudioStreamPlayer` for SM64 sound

Architecture reference: `../Plumbers_Quest_64_libsm64_Architecture_Design.docx`

---

## Credits

- Original mod: **CrypticTM**
- libsm64: [libsm64/libsm64](https://github.com/libsm64/libsm64)
- Godot binding: [Brawmario/libsm64-godot](https://github.com/Brawmario/libsm64-godot)
