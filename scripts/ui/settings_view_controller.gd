class_name SettingsViewController extends Control

## Settings view with sliders for text speed, volumes, and display options.
## Uses the same GALGAME sidebar layout with a back button.

signal back_requested()
signal setting_changed(key: String, value: Variant)

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack

@onready var slider_text_speed: HSlider = $HBox/Content/Scroll/SettingsList/RowTextSpeed/Slider
@onready var slider_auto_speed: HSlider = $HBox/Content/Scroll/SettingsList/RowAutoSpeed/Slider

@onready var slider_vol_global: HSlider = $HBox/Content/Scroll/SettingsList/RowVolGlobal/Slider
@onready var slider_vol_bgm: HSlider = $HBox/Content/Scroll/SettingsList/RowVolBgm/Slider
@onready var slider_vol_se: HSlider = $HBox/Content/Scroll/SettingsList/RowVolSe/Slider
@onready var slider_vol_voice: HSlider = $HBox/Content/Scroll/SettingsList/RowVolVoice/Slider

@onready var check_fullscreen: CheckButton = $HBox/Content/Scroll/SettingsList/RowFullscreen/Check
@onready var slider_font_size: HSlider = $HBox/Content/Scroll/SettingsList/RowFontSize/Slider

@onready var option_language: OptionButton = $HBox/Content/Scroll/SettingsList/RowLanguage/Option
@onready var btn_reset: Button = $HBox/Content/Scroll/SettingsList/BtnResetDefaults

# Label references for i18n.
@onready var lbl_text_speed: Label = $HBox/Content/Scroll/SettingsList/RowTextSpeed/Label
@onready var lbl_auto_speed: Label = $HBox/Content/Scroll/SettingsList/RowAutoSpeed/Label
@onready var lbl_vol_global: Label = $HBox/Content/Scroll/SettingsList/RowVolGlobal/Label
@onready var lbl_vol_bgm: Label = $HBox/Content/Scroll/SettingsList/RowVolBgm/Label
@onready var lbl_vol_se: Label = $HBox/Content/Scroll/SettingsList/RowVolSe/Label
@onready var lbl_vol_voice: Label = $HBox/Content/Scroll/SettingsList/RowVolVoice/Label
@onready var lbl_fullscreen: Label = $HBox/Content/Scroll/SettingsList/RowFullscreen/Label
@onready var lbl_font_size: Label = $HBox/Content/Scroll/SettingsList/RowFontSize/Label
@onready var lbl_language: Label = $HBox/Content/Scroll/SettingsList/RowLanguage/Label
@onready var section_text: Label = $HBox/Content/Scroll/SettingsList/SectionText
@onready var section_volume: Label = $HBox/Content/Scroll/SettingsList/SectionVolume
@onready var section_display: Label = $HBox/Content/Scroll/SettingsList/SectionDisplay
@onready var section_lang: Label = $HBox/Content/Scroll/SettingsList/SectionLang


func _ready() -> void:
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	btn_reset.pressed.connect(func() -> void:
		_apply_defaults()
		_emit_all()
	)

	slider_text_speed.value_changed.connect(func(v: float) -> void: setting_changed.emit("text_speed", v))
	slider_auto_speed.value_changed.connect(func(v: float) -> void: setting_changed.emit("auto_speed", v))
	slider_vol_global.value_changed.connect(func(v: float) -> void: setting_changed.emit("vol_global", v))
	slider_vol_bgm.value_changed.connect(func(v: float) -> void: setting_changed.emit("vol_bgm", v))
	slider_vol_se.value_changed.connect(func(v: float) -> void: setting_changed.emit("vol_se", v))
	slider_vol_voice.value_changed.connect(func(v: float) -> void: setting_changed.emit("vol_voice", v))
	check_fullscreen.toggled.connect(func(on: bool) -> void: setting_changed.emit("fullscreen", on))
	slider_font_size.value_changed.connect(func(v: float) -> void: setting_changed.emit("font_size", v))
	option_language.item_selected.connect(func(idx: int) -> void:
		var lang := "zh" if idx == 0 else "en"
		setting_changed.emit("language", lang)
	)

	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for section in [section_text, section_volume, section_display, section_lang]:
		if section:
			section.add_theme_font_size_override("font_size", 24)


func _apply_defaults() -> void:
	slider_text_speed.value = 30.0
	slider_auto_speed.value = 50.0
	slider_vol_global.value = 100.0
	slider_vol_bgm.value = 80.0
	slider_vol_se.value = 80.0
	slider_vol_voice.value = 100.0
	check_fullscreen.button_pressed = false
	slider_font_size.value = 26.0


func apply_settings(data: Dictionary) -> void:
	if data.has("text_speed"):
		slider_text_speed.value = float(data["text_speed"])
	if data.has("auto_speed"):
		slider_auto_speed.value = float(data["auto_speed"])
	if data.has("vol_global"):
		slider_vol_global.value = float(data["vol_global"])
	if data.has("vol_bgm"):
		slider_vol_bgm.value = float(data["vol_bgm"])
	if data.has("vol_se"):
		slider_vol_se.value = float(data["vol_se"])
	if data.has("vol_voice"):
		slider_vol_voice.value = float(data["vol_voice"])
	if data.has("fullscreen"):
		check_fullscreen.button_pressed = bool(data["fullscreen"])
	if data.has("font_size"):
		slider_font_size.value = float(data["font_size"])
	if data.has("language"):
		option_language.selected = 0 if str(data["language"]) == "zh" else 1


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if title_label:
		title_label.text = i18n.t("ingame.config.button", "设置")
	if btn_back:
		btn_back.text = i18n.t("title.selectchapter.return", "返回")
	if section_text:
		section_text.text = i18n.t("config.title.dialogue", "文字")
	if section_volume:
		section_volume.text = i18n.t("config.title.volume", "音量")
	if section_display:
		section_display.text = i18n.t("config.title.display", "显示")
	if section_lang:
		section_lang.text = i18n.t("config.tab.general", "通用")
	if lbl_text_speed:
		lbl_text_speed.text = i18n.t("config.item.textspeed", "文字显示速度")
	if lbl_auto_speed:
		lbl_auto_speed.text = i18n.t("config.item.autospeed", "自动模式速度")
	if lbl_vol_global:
		lbl_vol_global.text = i18n.t("config.item.volume.global", "全局音量")
	if lbl_vol_bgm:
		lbl_vol_bgm.text = i18n.t("config.item.volume.bgm", "背景音乐")
	if lbl_vol_se:
		lbl_vol_se.text = i18n.t("config.item.volume.sound", "音效")
	if lbl_vol_voice:
		lbl_vol_voice.text = i18n.t("config.item.volume.voice", "语音")
	if lbl_fullscreen:
		lbl_fullscreen.text = i18n.t("config.item.fullscreen", "全屏显示")
	if lbl_font_size:
		lbl_font_size.text = i18n.t("config.item.fontsize", "字体大小")
	if lbl_language:
		lbl_language.text = "语言"
	if btn_reset:
		btn_reset.text = i18n.t("config.resetdefault", "重置默认设置")


func _emit_all() -> void:
	setting_changed.emit("text_speed", slider_text_speed.value)
	setting_changed.emit("auto_speed", slider_auto_speed.value)
	setting_changed.emit("vol_global", slider_vol_global.value)
	setting_changed.emit("vol_bgm", slider_vol_bgm.value)
	setting_changed.emit("vol_se", slider_vol_se.value)
	setting_changed.emit("vol_voice", slider_vol_voice.value)
	setting_changed.emit("fullscreen", check_fullscreen.button_pressed)
	setting_changed.emit("font_size", slider_font_size.value)


func snapshot() -> Dictionary:
	return {
		"text_speed": slider_text_speed.value,
		"auto_speed": slider_auto_speed.value,
		"vol_global": slider_vol_global.value,
		"vol_bgm": slider_vol_bgm.value,
		"vol_se": slider_vol_se.value,
		"vol_voice": slider_vol_voice.value,
		"fullscreen": check_fullscreen.button_pressed,
		"font_size": slider_font_size.value,
		"language": "zh" if option_language.selected == 0 else "en",
	}
