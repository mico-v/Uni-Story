class_name HelpViewController extends Control

## Help page shown from title and first-run hints.

signal back_requested()

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack
@onready var intro_title: Label = $HBox/Content/Scroll/HelpList/IntroTitle
@onready var intro_text: Label = $HBox/Content/Scroll/HelpList/IntroText
@onready var controls_title: Label = $HBox/Content/Scroll/HelpList/ControlsTitle
@onready var controls_text: Label = $HBox/Content/Scroll/HelpList/ControlsText
@onready var save_title: Label = $HBox/Content/Scroll/HelpList/SaveTitle
@onready var save_text: Label = $HBox/Content/Scroll/HelpList/SaveText
@onready var close_button: Button = $HBox/Content/Scroll/HelpList/CloseButton


func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(func() -> void: back_requested.emit())
	if close_button:
		close_button.pressed.connect(func() -> void: back_requested.emit())
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label in [intro_title, controls_title, save_title]:
		if label is Label:
			(label as Label).add_theme_font_size_override("font_size", 24)
	for label in [intro_text, controls_text, save_text]:
		if label is Label:
			(label as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if title_label:
		title_label.text = i18n.t("title.menu.help", "操作说明")
	if btn_back:
		btn_back.text = i18n.t("title.selectchapter.return", "返回")
	if intro_title:
		intro_title.text = i18n.t("help.section.about", "项目说明")
	if intro_text:
		intro_text.text = i18n.t("help.text.about", "Uni-Story 是基于 Godot 的视觉小说运行时，支持章节、分支、存读档、回顾和鉴赏。")
	if controls_title:
		controls_title.text = i18n.t("help.section.controls", "基本操作")
	if controls_text:
		controls_text.text = i18n.t("help.text.controls", "左键或空格推进文本，右键打开游戏菜单，Esc 返回当前界面的上一级。")
	if save_title:
		save_title.text = i18n.t("help.section.save", "存档与回顾")
	if save_text:
		save_text.text = i18n.t("help.text.save", "存档会记录当前位置、变量、演出状态和缩略图。回顾中选择已读文本可以跳回对应位置。")
	if close_button:
		close_button.text = i18n.t("help.close", "关闭")
