class_name AnimationSystem extends RefCounted

## The `o.anim` object. Each top-level call creates a fresh AnimationChain (its
## own Tween) and delegates the first step to it. Subsequent chained calls return
## the chain, so they append to the same tween and play sequentially. Two
## separate `o.anim...` statements therefore animate in parallel.

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


func PropertyVector3(obj: Variant, prop: String, value: Vector3, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	return AnimationChain.new(_ctx).PropertyVector3(obj, prop, value, duration, immediate)


func PropertyColor(obj: Variant, prop: String, value: Color, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	return AnimationChain.new(_ctx).PropertyColor(obj, prop, value, duration, immediate)


func Delay(seconds: float) -> AnimationChain:
	return AnimationChain.new(_ctx).Delay(seconds)


## Used by BaseBlock.wait().
func wait(seconds: float) -> void:
	AnimationChain.new(_ctx).Delay(seconds)
