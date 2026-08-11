# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Uni-Story is a Godot 4.6 visual novel engine written in GDScript on the `main` branch (CI also runs on `dev`). It parses NovaScript-format scenarios, compiles presentation blocks into GDScript classes, and drives a full VN runtime with graphics, animation, audio, save/load, and UI. The reference architecture is Nova (Unity/C#/Lua), while this repository uses standard Godot 4.6 and does not require a .NET toolchain or embed a Lua VM.

The `Nova/` submodule at the repo root is the upstream Unity/C# reference project — architecture reference only, not part of the Godot build. Fetch it with `git submodule update --init Nova`; it can be ignored during normal development.

## Build & Test Commands

Use Godot 4.6 standard edition. Headless tests run as isolated `SceneTree` scripts:

```bash
# Single test
godot --headless --path . --script res://scripts/tests/<test_name>.gd

# Example: parse all 28 scenarios
godot --headless --path . --script res://scripts/tests/parse_scenarios_test.gd

# Lint all 28 scenarios (warnings are non-failing by default)
python scripts/tools/scenario_lint.py --godot godot

# Inventory dialogue/source statistics without executing eager code
python scripts/tools/scenario_stat.py --godot godot --top 0

# Run all 32 tests
python scripts/tests/run_headless_suite.py --godot godot --timeout 180

# Filter or inspect the suite
python scripts/tests/run_headless_suite.py --godot godot --pattern "*vfx*" --fail-fast
python scripts/tests/run_headless_suite.py --list
```

The complete suite contains:

- `auto_voice_system_smoke_test.gd`
- `chapter_select_smoke_test.gd`
- `checkpoint_manager_smoke_test.gd`
- `editor_tools_smoke_test.gd`
- `export_smoke_test.gd`
- `game_state_smoke_test.gd`
- `i18n_switch_smoke_test.gd`
- `load_runtime_scripts_test.gd`
- `main_scene_smoke_test.gd`
- `minigame_smoke_test.gd`
- `minigame_templates_smoke_test.gd`
- `nova_ch1_playback_smoke_test.gd`
- `nova_compat_smoke_test.gd`
- `nova_lua_compat_smoke_test.gd`
- `nova_runtime_compile_test.gd`
- `nova_visual_compat_smoke_test.gd`
- `parse_scenarios_test.gd`
- `performance_baseline_test.gd`
- `prefab_loader_smoke_test.gd`
- `preload_system_smoke_test.gd`
- `sample_work_playback_smoke_test.gd`
- `sample_work_save_load_test.gd`
- `save_system_smoke_test.gd`
- `save_viewer_smoke_test.gd`
- `scenario_linter_smoke_test.gd`
- `scenario_resource_scan_test.gd`
- `scenario_stat_smoke_test.gd`
- `scenario_visualize_smoke_test.gd`
- `shader_effects_smoke_test.gd`
- `sprite_composer_smoke_test.gd`
- `theme_manager_smoke_test.gd`
- `vfx_stack_smoke_test.gd`

Import first with `godot --headless --path . --import`. The current complete suite is 32/32 PASS in about 55 seconds. Both CI and release workflows run Scenario lint with `--fail-on error` and then `run_headless_suite.py`; warnings remain visible but do not block Windows, Linux, or Android jobs. Strict resource scanning includes `say(speaker, id)` and currently reports `referenced=369`, `found=367`, `virtual=2`, `missing=0`.

The public linter entry point is `python scripts/tools/scenario_lint.py`. It accepts `--godot`, `--project`, `--format text|json`, `--output`, `--fail-on error|warning|never`, and optional file/directory paths. Diagnostics are stable `path:line:column: severity [rule] message` records; exits are 0 (threshold not reached), 1 (lint findings reached the threshold), and 2 (invocation/infrastructure failure). The default 28-scenario corpus currently reports `errors=0`, `warnings=133`, `referenced=372`, `found=370`, `virtual=2`, `missing=0`; the extra references come from branch-image lint coverage.

The public statistics entry point is `python scripts/tools/scenario_stat.py`. It accepts `--godot`, `--project`, `--format text|json`, `--output`, `--top`, and optional file/directory paths; exits are 0 on success and 2 on invocation, input, analysis, or infrastructure failure. It builds the execution-free `scenario_analysis.gd` IR and never runs eager code. The report is a source inventory, not a playthrough estimate. The default corpus is 28 files, 360 blocks (106 eager/254 lazy), 53 nodes, 731 dialogues, 15434 normalized Unicode code points, 23 jumps, 24 branch options, and 1 silent entry.

Test convention: each test `extends SceneTree`, defers to `_run()`, checks with `_expect(condition, msg)`, and calls `quit(0)` or `quit(1)`. Tests write to `user://tests/` to avoid polluting `res://`.

Export presets exist for Windows Desktop, Linux, and Android (see `export_presets.cfg`).

## Architecture

### Composition Root

`scripts/NovaController.gd` is the single Composition Root. On `_ready()` it:

1. Creates and coordinates roughly 32 core subsystems, managers, and facades
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
| Runtime | `scripts/runtime/` | Presentation systems: graphics, animation, audio, AutoVoice, camera, VFX, transitions, sprite composer, prefab loader, BaseBlock |
| UI Controllers | `scripts/ui/` | View controllers: Title, Game, Settings, SaveLoad, Gallery, Backlog, ChapterSelect, Help, MobileUiSupport |
| Scenes | `scene/` | `.tscn` files: `game.tscn` (main), `view/` (8 views), `ui/` (components) |
| Tests | `scripts/tests/` | Headless SceneTree smoke tests |
| Tools | `scripts/tools/` | Scenario lint, execution-free shared analysis IR, and Python/Godot stat CLIs |
| Resources | `resources/` | Scenarios (`.txt`), characters, demo media, shaders (`.gdshader`), fonts, themes, prefabs |

### Subsystem Dependencies

Every subsystem receives `_ctx: Node` (NovaController) via constructor injection. Subsystems access each other through `_ctx.<subsystem_name>`. New code should prefer `EngineContext` (`scripts/core/engine_context.gd`), a typed facade that wraps `_ctx` with explicit property accessors.

### NovaScript Pipeline

1. `NovaParser` splits `.txt` scenario into eager/lazy/text blocks
2. `NovaScriptCompat` translates NovaScript syntax (`l_` labels, `v_`/`gv_` variables, branch tuples, text interpolation) into GDScript
3. `ScriptLoader` compiles each block into a `BaseBlock` subclass via `GDScript.new()` and stores it in `FlowChartGraph`
4. `GDRuntime` instantiates and runs blocks at playback time

Offline tools use `scenario_analysis.gd` instead: it inventories blocks, nodes, entries, silent entries, edges, and events without executing eager code. Scenario visualization should consume this shared IR rather than the linter report.
5. `BaseBlock` (`scripts/runtime/base_block.gd`) defines all API methods visible to compiled blocks, including `show()`, `hide()`, `move()`, `tint()`, `play_bgm()`, `say()`, `auto_voice_*`, `cam()`, `trans()`, `o.anim.*`, `vfx()`, `clear_effect()`, `capture_screen()`, `load_ui_prefab()`, `load_persistent_prefab()`, `cancel_preload()`, `cancel_all_preloads()`, `branch()`, and `jump_to()`.

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
- Restore order: GameState silently replays first, other restorables follow, AutoVoice restores last, then the target dialogue is presented; backward jump uses "nearest checkpoint restore + replay to target"

### ViewManager State Machine

Views are registered by name with a transition type (FADE, SLIDE_LEFT, INSTANT). State tracking: Title, UI, Game, InTransition, Alert. Leaving GameView auto-pauses animation domains and voice. Input is blocked during transitions.

### Animation Domains

`AnimationSystem` classifies animations into four domains: `PER_DIALOGUE` (stops on advance), `HOLDING` (persists across dialogue), `UI` (interface), `TEXT` (text effects). Supports `pause()`, `resume()`, `stop()` by domain and named holding groups. Easing uses Nova-style string descriptors (e.g. `"inOutCubic"`) parsed to Godot Tween enums.

### AutoVoice

- `resources/auto_voice_profile.tres` maps canonical script speakers and aliases to case-sensitive voice directories. The default profile uses six-digit zero-padded `.ogg` names under `Voices/Ergong`, `Voices/Qianye`, `Voices/Xiben`, and `Voices/Gaotian`.
- Dialogue syntax `display//canonical::text` keeps UI display names separate from runtime identity. The mapping is inherited only inside the current flow-chart node and resets at the next label.
- `AutoVoiceSystem.prepare_dialogue()` consumes one-shot delay/override state and advances the per-speaker index before checkpointing; `start_prepared_cue()` runs only after Backlog has recorded the exact voice path.
- `set_auto_voice_delay()` applies to the next eligible automatic cue only. Narration, disabled speakers, and an explicit override do not consume the delay. `say()` and `play_voice()` override the next automatic cue by default; `say()` resolves the configured speaker directory.
- Auto mode waits for both a pending delayed cue and active voice playback before its reading delay. AutoVoice snapshots enabled/index/prefix, next delay, override state, and the current cue; restore must not replay skipped historical voices or consume an index twice.

### Theme, Preload, and Prefab Lifecycles

- `ThemeManager` combines a structural `base_theme.tres` with a project/work theme such as `main_theme.tres`, applies it at the scene-tree root, and snapshots the selected work theme.
- `PreloadSystem` maintains separate IMAGE, AUDIO, PREFAB, and OTHER LRU caches with per-type capacities, priority-aware load/eviction order, reference-counted `cancel_preload()`, `cancel_all()`, and overall/per-type progress.
- `PrefabLoader` classifies instances as WORLD, UI, or PERSISTENT. Use `load_prefab()`, `load_ui_prefab()`, and `load_persistent_prefab()` so cleanup preserves the intended lifetime.

### VFX System

OBJECT (per-node) and POST (fullscreen) effects use registries. Transition shaders are still selected by `match`; a dedicated TRANSITION registry remains TODO. The repository contains 12 `.gdshader` files, including separate object/post variants where needed.

`VFXSystem` records up to three active object effects per target, supports snapshot/restore and `clear_effect()`, and exposes `capture_screen()`. This is currently a state stack rather than true rendering composition: only the top effect's `ShaderMaterial` is assigned to the node. True SubViewport/multi-pass composition and a transition shader that actually consumes the captured texture remain TODO.

## Coding Conventions

- **GDScript-first**: no C#, no Lua VM; all runtime logic in GDScript
- **`class_name` on core scripts**; explicit type annotations on the public API surface. `:=` type inference is permitted (and preferred for literals/preloads) wherever the type is unambiguous; the important rule is *no untyped* `var x =` or untyped function return types in committed code. Note: `docs/CodingStandards.md` carries an older, stricter "avoid `:=`" rule; the codebase uses `:=` widely (101 files, including `scripts/core/`), so follow this rule rather than the CodingStandards prohibition.
- **Typed containers**: every `Array`/`Dictionary` that crosses an API boundary or holds save/checkpoint data must declare its element type (e.g. `Array[StringName]`, `Dictionary`). Save/restore payloads are JSON-serializable only: Dictionary, Array, String, float, int, bool, null.
- **4-space indentation**, LF line endings, UTF-8 (see `.editorconfig`)
- **`snapshot() -> Dictionary` / `restore(data: Dictionary)`** for any subsystem that participates in save/load; return `bool` only when the caller needs a success result
- **`EngineLog` categories** (parse, runtime, save, asset, config, restore, ui) instead of raw `push_warning` for new subsystems
- **Comments**: explain non-obvious constraints, restore order, compatibility strategies, or complex flow — not self-documenting code
- **Scene vs controller separation**: UI structure in `.tscn`, logic in `scripts/ui/*`
- **Config in exported vars or resource files**, never hardcoded in runtime scripts (character names, poses, resource aliases, chapter data)

## Key Constraints

- Do not change the order of `before_checkpoint` / default lazy / `after_dialogue` stages — checkpoint and replay determinism depends on it
- `v_` = save-scoped variable, `gv_` = global variable; maintain this convention
- Save format must include `version` field and be backward-compatible
- Modifying checkpoint/replay logic requires running `checkpoint_manager_smoke_test.gd` and `save_system_smoke_test.gd`
- Modifying AutoVoice, dialogue speaker parsing, Backlog voice attachment, or Auto timing requires running `auto_voice_system_smoke_test.gd`, `nova_runtime_compile_test.gd`, `nova_ch1_playback_smoke_test.gd`, and the checkpoint/save tests
- Scenario changes should pass `python scripts/tools/scenario_lint.py`; linter rule/CLI changes require `scenario_linter_smoke_test.gd`
- Scenario corpus changes should also run `python scripts/tools/scenario_stat.py --top 0`; analysis IR, normalization, schema, ordering, or stat CLI changes require `scenario_stat_smoke_test.gd`
- Modifying sprite composition requires running `sprite_composer_smoke_test.gd`
- CI on push to `main`/`dev` and release builds must pass error-level Scenario lint plus the 32-test headless quality gate before Windows, Linux, or Android export jobs run

## Reference Docs

- `docs/NovaScript.md` — the NovaScript script API (what compiled `BaseBlock` subclasses can call)
- `docs/CodingStandards.md` — engineering conventions and memory rules (note the `:=` conflict above)
- `docs/ProjectTerms.md` — terminology glossary
- `docs/ReleaseGuide.md` and `PLAN.md` — release process and roadmap
- `README.md` and `Setup.md` — Chinese-language overview and quick start
