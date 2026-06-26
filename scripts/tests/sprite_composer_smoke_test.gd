extends SceneTree

## Headless SpriteComposer smoke test for Nova standing layer offsets.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/sprite_composer_smoke_test.gd


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var composer: SpriteComposer
	var world: Node2D

	func setup() -> void:
		object_manager = ObjectManager.new()
		world = Node2D.new()
		world.name = "World"
		add_child(world)
		object_manager.bind_object("world", world)
		object_manager.set_constant("resource_root", "res://resources/")
		composer = SpriteComposer.new(self)
		var profile: Resource = load("res://resources/standing_profile.tres")
		composer.configure(profile)


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ctx: TestContext = TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	_expect(ctx.composer.has_character_profile("gaotian"), "standing profile should define the sample character")
	ctx.composer.show_char("gaotian", "normal")
	var character = ctx.object_manager.objects.get("gaotian", null)
	_expect(character is CompositeSprite, "Nova character should bind a CompositeSprite")
	if character is CompositeSprite:
		var cs: CompositeSprite = character as CompositeSprite
		_expect(cs.visible_layer_count() >= 5, "normal pose should show body and face layers")
		var body_pos: Vector2 = cs.layer_position("body")
		var eye_pos: Vector2 = cs.layer_position("eye_normal")
		var mouth_pos: Vector2 = cs.layer_position("mouth_smile")
		_expect(eye_pos.y < body_pos.y, "eye layer should be above body layer")
		_expect(mouth_pos.y < body_pos.y, "mouth layer should be above body layer")
		_expect(mouth_pos.y > eye_pos.y, "mouth layer should be below eye layer")

	if _failures.is_empty():
		print("SpriteComposerSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("SpriteComposerSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
