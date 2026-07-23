class_name InterruptManager extends RefCounted

## InterruptManager — handles the interrupt/fence protocol for minigames
## and external gameplay systems.
##
## When a minigame (or any external system) starts an interrupt:
##   1. VN auto/skip is deactivated
##   2. Click-to-advance is paused
##   3. The interrupt system takes control
## When the interrupt finishes:
##   1. A checkpoint is created
##   2. Dialogue can resume from the next entry

signal interrupt_started()
signal interrupt_finished()

var _ctx: Node
var _is_active: bool = false
var _interrupt_count: int = 0


func _init(ctx: Node) -> void:
	_ctx = ctx


## Whether an interrupt is currently active (blocks VN input advance).
func is_active() -> bool:
	return _is_active


## Begin an interrupt. Returns an interrupt ID that must be passed to end_interrupt().
func begin_interrupt() -> int:
	_interrupt_count += 1
	var id := _interrupt_count
	_is_active = true
	interrupt_started.emit()
	return id


## End an interrupt. Pass the ID returned by begin_interrupt().
## Creates a checkpoint to capture the current VN state after minigame completion.
func end_interrupt(_interrupt_id: int) -> void:
	if not _is_active:
		push_warning("InterruptManager: end_interrupt called while no interrupt is active")
		return
	_is_active = false
	# Create checkpoint so save/load works after minigame.
	if _ctx.checkpoint_manager and _ctx.checkpoint_manager.has_method("create_checkpoint"):
		_ctx.checkpoint_manager.create_checkpoint()
	interrupt_finished.emit()


## Is input advancement blocked by an interrupt?
func blocks_advance() -> bool:
	return _is_active


## Is auto/skip allowed during interrupt?
func allows_auto_skip() -> bool:
	return false


# ── Restorable (duck-typed) ────────────────────────────────────────────

func snapshot() -> Dictionary:
	return {
		"is_active": _is_active,
		"interrupt_count": _interrupt_count,
	}


func restore(data: Dictionary) -> void:
	_is_active = bool(data.get("is_active", false))
	_interrupt_count = int(data.get("interrupt_count", 0))
