# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Uni-Story is a Godot 4.6 visual novel engine written in GDScript. It parses NovaScript-format scenarios, compiles presentation blocks into GDScript classes, and drives a full VN runtime with graphics, animation, audio, save/load, and UI. The reference architecture is Nova (Unity/C#/Lua) but this project is GDScript-first — it does not embed a Lua VM or require .NET.

## Build & Test Commands

Godot 4.6 standard edition (not .NET). Headless tests run as standalone SceneTree scripts:

```bash
# Single test
godot --headless --path . --script res://scripts/tests/<test_name>.gd

# Example: parse all 28 scenarios
godot --headless --path . --script res://scripts/tests/parse_scenarios_test.gd

# Run all tests (no built-in runner; execute individually)
# Tests: parse_scenarios_test, game_state_smoke_test, save_system_smoke_test,
#        checkpoint_manager_smoke_test, nova_compat_smoke_test,
#        sprite_composer_smoke_test, main_scene_smoke_test,
#        scenario_resource_scan_test, chapter_select_smoke_test,
#        nova_ch1_playback_smoke_test, nova_visual_compat_smoke_test,
#        nova_runtime_compile_test, load_runtime_scripts_test
```

The Godot project must be imported first: `godot --headless --import` (CI does this before export).

Test convention: each test `extends SceneTree`, defers to `_run()`, checks with `_expect(condition, msg)`, and calls `quit(0)` or `quit(1)`. Tests write to `user://tests/` to avoid polluting `res://`.

Export presets exist for Windows Desktop, Linux, and Android (see `export_presets.cfg`).

## Architecture

### Composition Root

`scripts/NovaController.gd` is the single Composition Root. On `_ready()` it:

1. Creates ~28 `RefCounted` subsystems
2. Registers restorable subsystems with `RestorableRegistry`
3. Binds view controllers from the scene tree
4. Initializes `ViewManager` with registered views and transition types
5. Wires model signals → view callbacks
6. Loads all scenario files via `ScriptLoader`, then calls `game_state.setup(graph)`

### Layer Map

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| Composition Root | `scripts/NovaController.gd` | Subsystem creation, signal routing, navigation |
| Core | `scripts/core/` | Pure models: GameState, FlowChartGraph, parser, save system, variables, i18n, checkpoint, EngineContext |
| Runtime | `scripts/runtime/` | Presentation systems: graphics, animation, audio, camera, VFX, transitions, sprite composer, prefab loader, BaseBlock |
| UI Controllers | `scripts/ui/` | View controllers: Title, Game, Settings, SaveLoad, Gallery, Backlog, ChapterSelect, Help, MobileUiSupport |
| Scenes | `scene/` | `.tscn` files: `game.tscn` (main), `view/` (8 views), `ui/` (components) |
| Tests | `scripts/tests/` | Headless SceneTree smoke tests |
| Resources | `resources/` | Scenarios (`.txt`), characters, demo media, shaders (`.gdshader`), fonts, themes, prefabs |

### Subsystem Dependencies

Every subsystem receives `_ctx: Node` (NovaController) via constructor injection. Subsystems access each other through `_ctx.<subsystem_name>`. New code should prefer `EngineContext` (`scripts/core/engine_context.gd`), a typed facade that wraps `_ctx` with explicit property accessors.

### NovaScript Pipeline

1. `NovaParser` splits `.txt` scenario into eager/lazy/text blocks
2. `NovaScriptCompat` translates NovaScript syntax (`l_` labels, `v_`/`gv_` variables, branch tuples, text interpolation) into GDScript
3. `ScriptLoader` compiles each block into a `BaseBlock` subclass via `GDScript.new()` and stores it in `FlowChartGraph`
4. `GDRuntime` instantiates and runs blocks at playback time
5. `BaseBlock` (`scripts/runtime/base_block.gd`) defines all API methods visible to compiled blocks: `show()`, `hide()`, `move()`, `tint()`, `play_bgm()`, `cam()`, `trans()`, `o.anim.*`, `vfx()`, `branch()`, `jump_to()`, etc.

### Flow Chart Model

- `FlowChartGraph` holds `FlowChartNode` objects keyed by `StringName`
- Each node contains an ordered array of `DialogueEntry` items
- Each entry has three runtime stages: `before_checkpoint`, lazy block (default), `after_dialogue`
- Nodes can have branches (normal/show/enable/jump modes) or a `jump_target`
- Node types: NORMAL, CHAPTER, END

### Save/Restore Architecture

- `CheckpointManager`: records node history, reached dialogue/ending, and position checkpoints
- `SaveSystem`: manages bookmark slot files (JSON in `user://saves/`) with metadata (thumbnail, chapter, timestamp)
- `RestorableRegistry`: subsystems register with `snapshot()`/`restore(data)` duck-typed methods
- Restore order: GameState first, then other restorables; backward jump uses "nearest checkpoint restore + replay to target"

### ViewManager State Machine

Views are registered by name with a transition type (FADE, SLIDE_LEFT, INSTANT). State tracking: Title, UI, Game, InTransition, Alert. Leaving GameView auto-pauses animation domains and voice. Input is blocked during transitions.

### Animation Domains

`AnimationSystem` classifies animations into four domains: `PER_DIALOGUE` (stops on advance), `HOLDING` (persists across dialogue), `UI` (interface), `TEXT` (text effects). Supports `pause()`, `resume()`, `stop()` by domain and named holding groups. Easing uses Nova-style string descriptors (e.g. `"inOutCubic"`) parsed to Godot Tween enums.

### VFX System

Shader effects registered in three categories: OBJECT (per-node), POST (fullscreen), TRANSITION (screen wipes). Registry maps effect name → shader path + default params + animatable params. 8 shaders: blur, grayscale, dissolve, chromatic, vignette, glitch, ripple, wipe.

## Coding Conventions

- **GDScript-first**: no C#, no Lua VM; all runtime logic in GDScript
- **`class_name` on core scripts**; explicit type annotations; **no `:=` inferred declarations**
- **JSON-serializable data** for save/checkpoint payloads: only Dictionary, Array, String, float, int, bool, null
- **4-space indentation**, LF line endings, UTF-8 (see `.editorconfig`)
- **`snapshot() -> Dictionary` / `restore(data: Dictionary) -> bool`** for any subsystem that participates in save/load
- **`EngineLog` categories** (parse, runtime, save, asset, config, restore, ui) instead of raw `push_warning` for new subsystems
- **Comments**: explain non-obvious constraints, restore order, compatibility strategies, or complex flow — not self-documenting code
- **Scene vs controller separation**: UI structure in `.tscn`, logic in `scripts/ui/*`
- **Config in exported vars or resource files**, never hardcoded in runtime scripts (character names, poses, resource aliases, chapter data)

## Key Constraints

- Do not change the order of `before_checkpoint` / default lazy / `after_dialogue` stages — checkpoint and replay determinism depends on it
- `v_` = save-scoped variable, `gv_` = global variable; maintain this convention
- Save format must include `version` field and be backward-compatible
- Modifying checkpoint/replay logic requires running `checkpoint_manager_smoke_test.gd` and `save_system_smoke_test.gd`
- Modifying sprite composition requires running `sprite_composer_smoke_test.gd`
- CI on push to `main`/`dev` builds Windows, Linux, and Android artifacts
