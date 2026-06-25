class_name BacklogPanelController extends RefCounted

## Encapsulates backlog panel UI logic extracted from GameViewController.

var _ctx: Node
var _backlog_panel: Panel
var _backlog_list: VBoxContainer
var _backlog_scroll: ScrollContainer
var _backlog_close_btn: Button


func bind_nodes(panel: Panel, list: VBoxContainer, scroll: ScrollContainer, close_btn: Button) -> void:
	_backlog_panel = panel
	_backlog_list = list
	_backlog_scroll = scroll
	_backlog_close_btn = close_btn
	if _backlog_close_btn:
		_backlog_close_btn.pressed.connect(func() -> void:
			if _backlog_panel:
				_backlog_panel.visible = false
		)


func setup(ctx: Node) -> void:
	_ctx = ctx


func open() -> void:
	_clear_children(_backlog_list)
	var backlog_title := _backlog_panel_title_node()
	if backlog_title:
		backlog_title.text = _t("ui.label.backlog", "文本回顾")
	if _backlog_panel:
		_backlog_panel.visible = true
	await _ctx.get_tree().process_frame
	if _ctx.backlog:
		var entries = _ctx.backlog.entries()
		var current_node_name := ""
		var current_idx := -1
		if _ctx.game_state and _ctx.game_state.current_node:
			current_node_name = str(_ctx.game_state.current_node.name)
			current_idx = _ctx.game_state.current_index
		for i in entries.size():
			var entry: Dictionary = entries[i]
			var node_name := str(entry.get("node", ""))
			var entry_idx: int = int(entry.get("index", -1))
			# Skip entries after current position
			if _is_after_current(node_name, entry_idx, current_node_name, current_idx):
				continue
			var lbl := RichTextLabel.new()
			lbl.bbcode_enabled = true
			lbl.fit_content = true
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.size_flags_vertical = Control.SIZE_FILL
			lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var speaker := str(entry["speaker"])
			var text := str(entry["text"])
			if speaker.is_empty():
				lbl.text = text
			else:
				lbl.text = "[b]%s[/b]：%s" % [speaker, text]
			if node_name != "" and entry_idx >= 0:
				lbl.mouse_filter = Control.MOUSE_FILTER_STOP
				lbl.gui_input.connect(_on_backlog_entry_click.bind(i, lbl))
				# Hover effects
				lbl.mouse_entered.connect(func() -> void: _on_entry_hover(lbl, true))
				lbl.mouse_exited.connect(func() -> void: _on_entry_hover(lbl, false))
			_backlog_list.add_child(lbl)
	await _ctx.get_tree().process_frame
	for child in _backlog_list.get_children():
		if child is RichTextLabel:
			child.custom_minimum_size.y = child.size.y
	if _backlog_scroll:
		_backlog_scroll.scroll_vertical = int(_backlog_scroll.get_v_scroll_bar().max_value)


func _on_entry_hover(lbl: RichTextLabel, hovered: bool) -> void:
	if hovered:
		lbl.modulate = Color(1.0, 1.0, 0.8, 1.0)
	else:
		lbl.modulate = Color.WHITE


func _is_after_current(entry_node: String, entry_idx: int, current_node: String, current_idx: int) -> bool:
	if entry_node != current_node:
		return false
	return entry_idx > current_idx


func close() -> void:
	if _backlog_panel:
		_backlog_panel.visible = false


func panel_is_visible() -> bool:
	return _backlog_panel != null and _backlog_panel.visible


func _backlog_panel_title_node() -> Label:
	if not _backlog_panel:
		return null
	var node := _backlog_panel.get_node_or_null("BacklogPanelContainer/Title")
	if node is Label:
		return node
	return null


func _on_backlog_entry_click(event: InputEvent, entry_index: int, _lbl: RichTextLabel) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.is_echo():
			if _ctx.backlog:
				_ctx.backlog.request_jump(entry_index)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
