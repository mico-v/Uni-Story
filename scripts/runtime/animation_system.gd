class_name AnimationSystem extends RefCounted

## The `o.anim` object. Each top-level call creates a fresh AnimationChain (its
## own Tween) and delegates the first step to it. Subsequent chained calls return
## the chain, so they append to the same tween and play sequentially. Two
## separate `o.anim...` statements therefore animate in parallel.
##
## Phase 6: adds animation domains (per_dialogue, holding, ui, text),
## pause/resume/stop by domain, named holding groups, and easing parser.

enum Domain { PER_DIALOGUE, HOLDING, UI, TEXT }

var _ctx: Node
var _active_chains: Array[AnimationChain] = []


func _init(ctx: Node) -> void:
	_ctx = ctx


## Register a chain so it can be paused/resumed/stopped globally.
func _track(chain: AnimationChain) -> void:
	_prune_completed()
	_active_chains.append(chain)


func _prune_completed() -> void:
	var filtered: Array[AnimationChain] = []
	for c in _active_chains:
		if is_instance_valid(c) and c.is_running():
			filtered.append(c)
	_active_chains = filtered


## Pause all animations in the given domain (or all if domain=-1).
func pause_all(domain: int = -1) -> void:
	_prune_completed()
	for chain in _active_chains:
		if domain < 0 or chain.domain == domain:
			chain.pause()


## Resume all paused animations in the given domain.
func resume_all(domain: int = -1) -> void:
	_prune_completed()
	for chain in _active_chains:
		if domain < 0 or chain.domain == domain:
			chain.resume()


## Stop all animations in the given domain.
func stop_all(domain: int = -1) -> void:
	_prune_completed()
	for chain in _active_chains:
		if domain < 0 or chain.domain == domain:
			chain.stop()
	_active_chains.clear()


## Stop all animations in a named holding group.
func stop_holding_group(group_name: String) -> void:
	_prune_completed()
	for chain in _active_chains:
		if chain.domain == Domain.HOLDING and chain.holding_group == group_name:
			chain.stop()
	_prune_completed()


# ── Chain factory methods ──────────────────────────────────────────────

func PropertyFloat(obj: Variant, prop: String, value: float, duration: float = 0.5, easing: String = "", domain: int = Domain.PER_DIALOGUE) -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = domain
	c.easing_str = easing
	_track(c)
	return c.PropertyFloat(obj, prop, value, duration)


func PropertyVector2(obj: Variant, prop: String, value: Vector2, duration: float = 0.5, easing: String = "", domain: int = Domain.PER_DIALOGUE) -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = domain
	c.easing_str = easing
	_track(c)
	return c.PropertyVector2(obj, prop, value, duration)


func PropertyVector3(obj: Variant, prop: String, value: Vector3, duration: float = 0.5, immediate: bool = false, easing: String = "", domain: int = Domain.PER_DIALOGUE) -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = domain
	c.easing_str = easing
	_track(c)
	return c.PropertyVector3(obj, prop, value, duration, immediate)


func PropertyColor(obj: Variant, prop: String, value: Color, duration: float = 0.5, immediate: bool = false, easing: String = "", domain: int = Domain.PER_DIALOGUE) -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = domain
	c.easing_str = easing
	_track(c)
	return c.PropertyColor(obj, prop, value, duration, immediate)


func Delay(seconds: float) -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = Domain.PER_DIALOGUE
	_track(c)
	return c.Delay(seconds)


## Start a holding animation chain with a named group.
func holding(group_name: String = "") -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = Domain.HOLDING
	c.holding_group = group_name
	_track(c)
	return c


## Start a UI animation chain.
func ui() -> AnimationChain:
	var c := AnimationChain.new(_ctx)
	c.domain = Domain.UI
	_track(c)
	return c


## Used by BaseBlock.wait().
func wait(seconds: float):
	var c := AnimationChain.new(_ctx)
	c.domain = Domain.TEXT
	_track(c)
	return c.Delay(seconds)


# ── NovaScript animation block support ──────────────────────────────────
## These are called from GDRuntime-compiled blocks and return the chain
## so the runtime can await them.

func anim_move(obj: Variant, coord: Variant, duration: float = 0.5, easing: String = "") -> AnimationChain:
	var vec := _to_vector2(coord)
	return PropertyVector2(obj, "position", vec, duration, easing)

func anim_fade(obj: Variant, alpha: float, duration: float = 0.5, easing: String = "") -> AnimationChain:
	return PropertyFloat(obj, "modulate:a", clampf(alpha, 0.0, 1.0), duration, easing)

func anim_rotate(obj: Variant, degrees: float, duration: float = 0.5, easing: String = "") -> AnimationChain:
	return PropertyFloat(obj, "rotation_degrees", degrees, duration, easing)

func anim_scale(obj: Variant, scale: float, duration: float = 0.5, easing: String = "") -> AnimationChain:
	return PropertyVector2(obj, "scale", Vector2(scale, scale), duration, easing)

func anim_tint(obj: Variant, color: Color, duration: float = 0.5, easing: String = "") -> AnimationChain:
	return PropertyColor(obj, "modulate", color, duration, false, easing)


## Parse Nova-style easing string to Godot Tween enums.
## Returns [Tween.EaseType, Tween.TransitionType] or [-1, -1] if unrecognized.
static func parse_easing(easing: String) -> Array:
	if easing.is_empty():
		return [-1, -1]
	var e := easing.to_lower()
	var ease_type := Tween.EASE_IN_OUT
	if e.begins_with("inout"):
		ease_type = Tween.EASE_IN_OUT
		e = e.substr(5)
	elif e.begins_with("outin"):
		ease_type = Tween.EASE_OUT_IN
		e = e.substr(5)
	elif e.begins_with("in"):
		ease_type = Tween.EASE_IN
		e = e.substr(2)
	elif e.begins_with("out"):
		ease_type = Tween.EASE_OUT
		e = e.substr(3)
	var trans_type := _parse_transition(e)
	return [ease_type, trans_type]


static func _parse_transition(name: String) -> int:
	match name:
		"linear":         return Tween.TRANS_LINEAR
		"sine", "sin":    return Tween.TRANS_SINE
		"quint":          return Tween.TRANS_QUINT
		"quart":          return Tween.TRANS_QUART
		"quad":           return Tween.TRANS_QUAD
		"expo":           return Tween.TRANS_EXPO
		"elastic":        return Tween.TRANS_ELASTIC
		"cubic":          return Tween.TRANS_CUBIC
		"circ":           return Tween.TRANS_CIRC
		"bounce":         return Tween.TRANS_BOUNCE
		"back":           return Tween.TRANS_BACK
		"spring":         return Tween.TRANS_SPRING
		_:                return Tween.TRANS_LINEAR


static func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.y)
	if value is Array:
		var arr := value as Array
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
		if arr.size() >= 1:
			return Vector2(float(arr[0]), float(arr[0]))
	return Vector2.ZERO


# ── Snapshot (transient — animations are not persisted) ────────────────

func snapshot() -> Dictionary:
	return {
		"active": false,
		"active_object": "",
		"active_property": "",
		"remaining": 0.0,
	}


func restore(_state: Dictionary) -> void:
	return
