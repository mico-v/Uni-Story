@tool
extends Control

## Bottom panel for visual standing sprite editing.
##
## Shows a live preview of a selected character's pose, allowing:
##   - Character selection via dropdown
##   - Pose selection / layer combination editing
##   - Visual offset adjustment (drag layers with mouse)
##   - Scale adjustment slider per layer group
##   - Live refresh when StandingProfile is modified


const StandingProfileScript = preload("res://scripts/runtime/standing_profile.gd")

var plugin: EditorPlugin
var _profile: StandingProfileScript
var _current_character: String = ""
var _current_pose: String = "normal"
var _preview_texture_rect: TextureRect
var _character_option: OptionButton
var _pose_option: OptionButton
var _layer_list: ItemList
var _offset_spinboxes: Dictionary = {}  # layer_group → {x: SpinBox, y: SpinBox}
var _scale_slider: HSlider
var _status_label: Label
var _refresh_timer: Timer

# Internal state: layer textures loaded from disk
var _layer_textures: Dictionary = {}  # "layer_name" → Texture2D
var _layer_previews: Array[Node] = []  # Sprite2D nodes in preview

# Enhanced features (Phase 17)
var _dual_preview: bool = false
var _dual_character: String = ""
var _dual_preview_texture_rect: TextureRect
var _dual_preview_btn: Button
var _move_up_btn: Button
var _move_down_btn: Button
var _cycle_poses_btn: Button
var _cycle_poses_timer: Timer
var _cycle_index: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 350)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_hbox)

	# Left: control panel
	var control_panel := VBoxContainer.new()
	control_panel.custom_minimum_size = Vector2(300, 0)
	control_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(control_panel)

	# Character selector
	var char_label := Label.new()
	char_label.text = "Character:"
	control_panel.add_child(char_label)

	_character_option = OptionButton.new()
	_character_option.item_selected.connect(_on_character_selected)
	control_panel.add_child(_character_option)

	# Pose selector
	var pose_label := Label.new()
	pose_label.text = "Pose:"
	control_panel.add_child(pose_label)

	var pose_hbox := HBoxContainer.new()
	control_panel.add_child(pose_hbox)

	_pose_option = OptionButton.new()
	_pose_option.item_selected.connect(_on_pose_selected)
	pose_hbox.add_child(_pose_option)

	var refresh_btn := Button.new()
	refresh_btn.text = "↻"
	refresh_btn.tooltip_text = "Refresh preview"
	refresh_btn.pressed.connect(_refresh_preview)
	pose_hbox.add_child(refresh_btn)

	# Layer list
	var layers_label := Label.new()
	layers_label.text = "Layers (drag to reorder):"
	control_panel.add_child(layers_label)

	_layer_list = ItemList.new()
	_layer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layer_list.allow_rmb_select = true
	control_panel.add_child(_layer_list)

	# Offset controls
	var offset_label := Label.new()
	offset_label.text = "Layer Offset:"
	control_panel.add_child(offset_label)

	var offset_grid := GridContainer.new()
	offset_grid.columns = 3
	control_panel.add_child(offset_grid)

	# Scale slider
	var scale_label := Label.new()
	scale_label.text = "Preview Scale:"
	control_panel.add_child(scale_label)

	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.1
	_scale_slider.max_value = 2.0
	_scale_slider.value = 0.5
	_scale_slider.step = 0.05
	_scale_slider.value_changed.connect(_on_scale_changed)
	control_panel.add_child(_scale_slider)

	# Status
	_status_label = Label.new()
	_status_label.text = "Select a StandingProfile resource to begin."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_panel.add_child(_status_label)

	# Right: preview area (supports dual preview with split)
	var preview_split := HSplitContainer.new()
	preview_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(preview_split)

	# Primary preview (always visible)
	var primary_panel := PanelContainer.new()
	primary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_split.add_child(primary_panel)

	var primary_bg := ColorRect.new()
	primary_bg.color = Color(0.15, 0.15, 0.15, 1.0)
	primary_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary_panel.add_child(primary_bg)

	_preview_texture_rect = TextureRect.new()
	_preview_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary_panel.add_child(_preview_texture_rect)

	# Secondary preview (dual, hidden by default)
	var secondary_panel := PanelContainer.new()
	secondary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary_panel.visible = false
	preview_split.add_child(secondary_panel)

	var secondary_bg := ColorRect.new()
	secondary_bg.color = Color(0.12, 0.12, 0.18, 1.0)
	secondary_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary_panel.add_child(secondary_bg)

	_dual_preview_texture_rect = TextureRect.new()
	_dual_preview_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_dual_preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dual_preview_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dual_preview_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary_panel.add_child(_dual_preview_texture_rect)

	# Store reference for toggling
	_dual_preview_texture_rect.get_parent().visible = false

	# Layer reorder buttons
	var reorder_hbox := HBoxContainer.new()
	control_panel.add_child(reorder_hbox)

	_move_up_btn = Button.new()
	_move_up_btn.text = "▲ Move Up"
	_move_up_btn.tooltip_text = "Move selected layer up in the order"
	_move_up_btn.pressed.connect(_move_layer_up)
	reorder_hbox.add_child(_move_up_btn)

	_move_down_btn = Button.new()
	_move_down_btn.text = "▼ Move Down"
	_move_down_btn.tooltip_text = "Move selected layer down in the order"
	_move_down_btn.pressed.connect(_move_layer_down)
	reorder_hbox.add_child(_move_down_btn)

	# Dual preview toggle
	_dual_preview_btn = Button.new()
	_dual_preview_btn.text = "Toggle Dual Preview"
	_dual_preview_btn.tooltip_text = "Show side-by-side comparison with another character"
	_dual_preview_btn.pressed.connect(_toggle_dual_preview)
	control_panel.add_child(_dual_preview_btn)

	# Cycle poses
	_cycle_poses_btn = Button.new()
	_cycle_poses_btn.text = "Cycle All Poses"
	_cycle_poses_btn.tooltip_text = "Automatically cycle through all poses (1.5s each)"
	_cycle_poses_btn.pressed.connect(_toggle_cycle_poses)
	control_panel.add_child(_cycle_poses_btn)

	# Refresh timer (debounce)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.3
	_refresh_timer.one_shot = true
	_refresh_timer.timeout.connect(_refresh_preview)
	add_child(_refresh_timer)

	# Cycle poses timer
	_cycle_poses_timer = Timer.new()
	_cycle_poses_timer.wait_time = 1.5
	_cycle_poses_timer.timeout.connect(_on_cycle_tick)
	add_child(_cycle_poses_timer)


func edit_profile(profile: Resource) -> void:
	if not profile:
		return

	_profile = profile
	_populate_characters()
	if _current_character.is_empty() and _character_option.item_count > 0:
		_current_character = _character_option.get_item_text(0).to_lower()
		_populate_poses()
	_refresh_preview()


func _populate_characters() -> void:
	_character_option.clear()
	if not _profile:
		return

	var chars_dict: Dictionary = _profile.characters
	for char_name in chars_dict:
		_character_option.add_item(char_name)

	if _character_option.item_count > 0:
		_current_character = _character_option.get_item_text(0).to_lower()


func _populate_poses() -> void:
	_pose_option.clear()
	if not _profile or _current_character.is_empty():
		return

	if not _profile.has_character(_current_character):
		_pose_option.add_item("normal")
		return

	var poses: Dictionary = _profile._poses(_current_character)
	if poses.is_empty():
		# Add a default
		_pose_option.add_item("normal")
		return

	for pose_name in poses:
		_pose_option.add_item(pose_name)
	_pose_option.selected = 0
	_current_pose = _pose_option.get_item_text(0)


func _on_character_selected(idx: int) -> void:
	_current_character = _character_option.get_item_text(idx).to_lower()
	_populate_poses()
	_refresh_preview()


func _on_pose_selected(idx: int) -> void:
	_current_pose = _pose_option.get_item_text(idx)
	_refresh_preview()


func _on_scale_changed(_value: float) -> void:
	_refresh_timer.start()


func _refresh_preview() -> void:
	if not _profile or _current_character.is_empty():
		_status_label.text = "No profile or character selected."
		return

	if not _profile.has_character(_current_character):
		_status_label.text = "Character '%s' not found in profile." % _current_character
		return

	# Load layer textures from disk
	var root_dir: String = "res://resources/"
	var char_dir: String = _profile.character_directory(_current_character)
	var full_dir: String = root_dir.path_join(char_dir)
	var pose_layers: Array[String] = _profile.resolve_pose_layers(_current_character, _current_pose)
	var layer_order: Array[String] = _profile.layer_order(_current_character)

	_layer_textures.clear()
	_layer_list.clear()

	var missing_layers: Array[String] = []
	for layer_name in pose_layers:
		var tex_path := full_dir.path_join(layer_name + ".png")
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path)
			if tex:
				_layer_textures[layer_name] = tex
				_layer_list.add_item(layer_name, tex)
		else:
			missing_layers.append(layer_name)
			_layer_list.add_item("⚠ " + layer_name)

	# Generate composite preview image
	var preview_img := _compose_preview(pose_layers, layer_order)

	if preview_img:
		var tex := ImageTexture.create_from_image(preview_img)
		_preview_texture_rect.texture = tex
		var scale_val := _scale_slider.value
		_preview_texture_rect.scale = Vector2(scale_val, scale_val)

		var total := pose_layers.size()
		var loaded := total - missing_layers.size()
		_status_label.text = "Preview: %s / %s  |  Layers: %d/%d loaded" % [
			_current_character, _current_pose, loaded, total,
		]
		if not missing_layers.is_empty():
			_status_label.text += "  |  Missing: " + ", ".join(missing_layers)
	else:
		_status_label.text = "Cannot compose preview for %s/%s. Check layer files." % [_current_character, _current_pose]


func _compose_preview(pose_layers: Array[String], layer_order: Array[String]) -> Image:
	if _layer_textures.is_empty():
		return null

	# Sort layers by layer_order
	var sorted_layers: Array[String] = pose_layers.duplicate()
	sorted_layers.sort_custom(func(a: String, b: String) -> bool:
		var a_idx := _layer_order_index(layer_order, a)
		var b_idx := _layer_order_index(layer_order, b)
		return a_idx < b_idx
	)

	# Determine canvas size (max of all textures)
	var max_w := 0
	var max_h := 0
	for layer_name in sorted_layers:
		if _layer_textures.has(layer_name):
			var tex: Texture2D = _layer_textures[layer_name]
			max_w = max(max_w, tex.get_width())
			max_h = max(max_h, tex.get_height())

	if max_w == 0 or max_h == 0:
		return null

	var img := Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for layer_name in sorted_layers:
		if not _layer_textures.has(layer_name):
			continue
		var tex: Texture2D = _layer_textures[layer_name]
		var layer_img := tex.get_image()
		if layer_img:
			# Apply offset
			var offset := _profile.layer_offset("res://resources/", _current_character, layer_name)
			var ox := int(offset.x)
			var oy := int(offset.y)
			# Composite with alpha blending
			img.blend_rect(layer_img, Rect2i(0, 0, layer_img.get_width(), layer_img.get_height()), Vector2i(ox, oy))

	return img


func _layer_order_index(order: Array[String], layer_name: String) -> int:
	var exact := order.find(layer_name)
	if exact != -1:
		return exact
	for i in range(order.size()):
		var group_name: String = order[i]
		if not group_name.is_empty() and layer_name.begins_with(group_name + "_"):
			return i
	return order.size()


# ── Enhanced features (Phase 17) ──

func _move_layer_up() -> void:
	var selected := _layer_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := selected[0]
	if idx <= 0:
		return
	var item_text := _layer_list.get_item_text(idx)
	var item_icon := _layer_list.get_item_icon(idx)
	_layer_list.remove_item(idx)
	_layer_list.insert(idx - 1, item_text, item_icon, true)
	_layer_list.select(idx - 1)
	_status_label.text = "Moved '%s' up" % item_text
	_refresh_timer.start()


func _move_layer_down() -> void:
	var selected := _layer_list.get_selected_items()
	if selected.is_empty():
		return
	var idx := selected[0]
	if idx >= _layer_list.item_count - 1:
		return
	var item_text := _layer_list.get_item_text(idx)
	var item_icon := _layer_list.get_item_icon(idx)
	_layer_list.remove_item(idx)
	_layer_list.insert(idx + 1, item_text, item_icon, true)
	_layer_list.select(idx + 1)
	_status_label.text = "Moved '%s' down" % item_text
	_refresh_timer.start()


func _toggle_dual_preview() -> void:
	_dual_preview = not _dual_preview
	var secondary := _dual_preview_texture_rect.get_parent()
	secondary.visible = _dual_preview
	_dual_preview_btn.text = "Dual Preview: ON" if _dual_preview else "Toggle Dual Preview"

	if _dual_preview:
		# Pick the next character for comparison
		if _character_option.item_count > 1:
			var cur_idx := _character_option.selected
			var next_idx := (cur_idx + 1) % _character_option.item_count
			_dual_character = _character_option.get_item_text(next_idx).to_lower()
			_refresh_dual_preview()
		_status_label.text = "Dual Preview: %s ↔ %s" % [_current_character, _dual_character]


func _refresh_dual_preview() -> void:
	if not _profile or _dual_character.is_empty():
		return

	if not _profile.has_character(_dual_character):
		return

	var root_dir: String = "res://resources/"
	var char_dir: String = _profile.character_directory(_dual_character)
	var full_dir: String = root_dir.path_join(char_dir)
	var pose_layers: Array[String] = _profile.resolve_pose_layers(_dual_character, "normal")
	var layer_order: Array[String] = _profile.layer_order(_dual_character)

	var dual_textures: Dictionary = {}
	for layer_name in pose_layers:
		var tex_path := full_dir.path_join(layer_name + ".png")
		if ResourceLoader.exists(tex_path):
			var tex: Texture2D = load(tex_path)
			if tex:
				dual_textures[layer_name] = tex

	if dual_textures.is_empty():
		return

	var sorted_layers: Array[String] = pose_layers.duplicate()
	sorted_layers.sort_custom(func(a: String, b: String) -> bool:
		return a.naturalnocasecmp_to(b) < 0
	)

	var max_w := 0
	var max_h := 0
	for layer_name in sorted_layers:
		if dual_textures.has(layer_name):
			var tex: Texture2D = dual_textures[layer_name]
			max_w = max(max_w, tex.get_width())
			max_h = max(max_h, tex.get_height())

	if max_w == 0 or max_h == 0:
		return

	var img := Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for layer_name in sorted_layers:
		if dual_textures.has(layer_name):
			var tex: Texture2D = dual_textures[layer_name]
			var layer_img := tex.get_image()
			if layer_img:
				img.blend_rect(layer_img, Rect2i(0, 0, layer_img.get_width(), layer_img.get_height()), Vector2i(0, 0))

	var tex := ImageTexture.create_from_image(img)
	_dual_preview_texture_rect.texture = tex
	_dual_preview_texture_rect.scale = Vector2(_scale_slider.value, _scale_slider.value)


func _toggle_cycle_poses() -> void:
	if _cycle_poses_timer.is_stopped():
		if _pose_option.item_count <= 1:
			_status_label.text = "Only 1 pose available for cycling."
			return
		_cycle_index = 0
		_cycle_poses_timer.start()
		_cycle_poses_btn.text = "⏸ Stop Cycling"
		_status_label.text = "Cycling poses..."
	else:
		_cycle_poses_timer.stop()
		_cycle_poses_btn.text = "Cycle All Poses"
		_status_label.text = "Pose cycling stopped."


func _on_cycle_tick() -> void:
	_cycle_index = (_cycle_index + 1) % _pose_option.item_count
	_pose_option.select(_cycle_index)
	_current_pose = _pose_option.get_item_text(_cycle_index)
	_refresh_preview()
	_status_label.text = "Cycling: %s / %s" % [_current_character, _current_pose]
