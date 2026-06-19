class_name TitleViewController extends Control

## GALGAME-style title screen with a left sidebar menu.
## Emits signals for each menu action; the parent coordinator
## (NovaController) decides which view to switch to.

signal new_game_requested()
signal continue_requested()
signal load_requested()
signal settings_requested()
signal gallery_requested()
signal music_requested()
signal quit_requested()

@onready var logo_label: Label = $HBox/MenuSidebar/VBox/Logo
@onready var btn_new_game: Button = $HBox/MenuSidebar/VBox/BtnNewGame
@onready var btn_continue: Button = $HBox/MenuSidebar/VBox/BtnContinue
@onready var btn_load: Button = $HBox/MenuSidebar/VBox/BtnLoad
@onready var btn_settings: Button = $HBox/MenuSidebar/VBox/BtnSettings
@onready var btn_gallery: Button = $HBox/MenuSidebar/VBox/BtnGallery
@onready var btn_music: Button = $HBox/MenuSidebar/VBox/BtnMusic
@onready var btn_quit: Button = $HBox/MenuSidebar/VBox/BtnQuit


func _ready() -> void:
	btn_new_game.pressed.connect(func() -> void: new_game_requested.emit())
	btn_continue.pressed.connect(func() -> void: continue_requested.emit())
	btn_load.pressed.connect(func() -> void: load_requested.emit())
	btn_settings.pressed.connect(func() -> void: settings_requested.emit())
	btn_gallery.pressed.connect(func() -> void: gallery_requested.emit())
	btn_music.pressed.connect(func() -> void: music_requested.emit())
	btn_quit.pressed.connect(func() -> void: quit_requested.emit())
	_apply_style()


func _apply_style() -> void:
	if logo_label:
		logo_label.add_theme_font_size_override("font_size", 36)
		logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if logo_label:
		logo_label.text = i18n.t("title.subtitle", "Story With Y")
	if btn_new_game:
		btn_new_game.text = i18n.t("title.menu.start", "新的游戏")
	if btn_continue:
		btn_continue.text = i18n.t("title.menu.continue", "继续游戏")
	if btn_load:
		btn_load.text = i18n.t("title.menu.load", "读取存档")
	if btn_settings:
		btn_settings.text = i18n.t("title.menu.config", "系统设置")
	if btn_gallery:
		btn_gallery.text = i18n.t("title.menu.gallery", "图片鉴赏")
	if btn_music:
		btn_music.text = i18n.t("title.menu.musicgallery", "音乐鉴赏")
	if btn_quit:
		btn_quit.text = i18n.t("title.menu.quit", "退出游戏")


## Enable/disable the Continue button based on auto-save existence.
func set_continue_enabled(enabled: bool) -> void:
	if btn_continue:
		btn_continue.disabled = not enabled
