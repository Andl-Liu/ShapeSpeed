extends Control


# ── 子节点引用 ──

@onready var _button_container: VBoxContainer = $VBox/ButtonContainer
@onready var _timed_checkbox: CheckBox = $VBox/TimedModeCheckBox
@onready var _timed_input: LineEdit = $VBox/TimedSecondsInput


# ── 支持面板常量 ──

const SUPPORT_BUTTON_TEXT := "支持我"
const SUPPORT_PANEL_SIZE := Vector2(460, 310)
const SUPPORT_BUTTON_SIZE := Vector2(120, 44)
const SUPPORT_MARGIN := 16.0
const SUPPORT_GAP := 12.0
const KOFI_URL := "https://ko-fi.com/andlliu"


# ── 生命周期 ──

func _ready() -> void:
	for type in ExerciseFactory.get_available_types():
		var btn := Button.new()
		btn.text = ExerciseFactory.get_display_name(type)
		btn.custom_minimum_size = Vector2(300, 50)
		btn.pressed.connect(_on_exercise_selected.bind(type))
		_button_container.add_child(btn)

	_build_support_widget()

	# 计时模式 UI：先从 GameManager 同步，再连接信号（避免初始化触发回调）
	_timed_checkbox.button_pressed = GameManager.timed_mode_enabled
	_timed_input.visible = GameManager.timed_mode_enabled
	_timed_input.text = str(int(GameManager.timed_mode_seconds))
	_timed_checkbox.toggled.connect(_on_timed_mode_toggled)
	_timed_input.text_submitted.connect(_on_timed_seconds_submitted)


# ── 支持面板（右下角“支持我”按钮） ──

## 在右下角创建“支持我”按钮，点击后在按钮上方展开/收起支持面板
func _build_support_widget() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	# 展开面板
	var panel := PanelContainer.new()
	panel.name = "SupportPanel"
	panel.size = Vector2(SUPPORT_PANEL_SIZE.x, 10.0)
	panel.pivot_offset = Vector2(0.0, 0.0)
	panel.position = Vector2(
		viewport_size.x - SUPPORT_MARGIN - SUPPORT_PANEL_SIZE.x,
		viewport_size.y - SUPPORT_MARGIN - SUPPORT_BUTTON_SIZE.y - SUPPORT_GAP - SUPPORT_PANEL_SIZE.y
	)
	panel.visible = false
	add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.13, 0.14, 0.17, 0.96)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_color = Color(0.32, 0.35, 0.42, 0.9)
	panel_style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "服务器好贵QAQ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var rows := HBoxContainer.new()
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 28)
	vbox.add_child(rows)

	# 左边：支付宝收款码
	var alipay_col := VBoxContainer.new()
	alipay_col.alignment = BoxContainer.ALIGNMENT_CENTER
	alipay_col.add_theme_constant_override("separation", 8)
	rows.add_child(alipay_col)

	var alipay_label := Label.new()
	alipay_label.text = "支付宝"
	alipay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alipay_col.add_child(alipay_label)

	var qr := TextureRect.new()
	qr.texture = load("res://assets/images/alipay.png")
	qr.custom_minimum_size = Vector2(140, 140)
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	alipay_col.add_child(qr)

	# 右边：Buy Me A Coffee / Ko-fi 链接
	var kofi_col := VBoxContainer.new()
	kofi_col.alignment = BoxContainer.ALIGNMENT_CENTER
	kofi_col.add_theme_constant_override("separation", 8)
	rows.add_child(kofi_col)

	var kofi_label := Label.new()
	kofi_label.text = "buy me a coffee"
	kofi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kofi_col.add_child(kofi_label)

	var link := RichTextLabel.new()
	link.bbcode_enabled = true
	link.fit_content = true
	link.scroll_active = false
	link.mouse_filter = Control.MOUSE_FILTER_PASS
	link.text = "[color=#6fb6ff][url=%s]%s[/url][/color]" % [KOFI_URL, KOFI_URL]
	link.add_theme_font_size_override("normal_font_size", 17)
	link.add_theme_font_size_override("bold_font_size", 17)
	link.meta_clicked.connect(_on_kofi_clicked)
	kofi_col.add_child(link)

	var kofi_spacer := Control.new()
	kofi_spacer.custom_minimum_size = Vector2(0, 10)
	kofi_col.add_child(kofi_spacer)

	# “支持我”切换按钮（固定在右下角）
	var toggle_btn := Button.new()
	toggle_btn.name = "SupportButton"
	toggle_btn.text = SUPPORT_BUTTON_TEXT
	toggle_btn.custom_minimum_size = SUPPORT_BUTTON_SIZE
	toggle_btn.position = Vector2(
		viewport_size.x - SUPPORT_MARGIN - SUPPORT_BUTTON_SIZE.x,
		viewport_size.y - SUPPORT_MARGIN - SUPPORT_BUTTON_SIZE.y
	)
	toggle_btn.size = SUPPORT_BUTTON_SIZE
	toggle_btn.add_theme_font_size_override("font_size", 20)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.20, 0.22, 0.28, 0.95)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.border_color = Color(0.42, 0.46, 0.55, 0.9)
	btn_style.set_border_width_all(1)
	toggle_btn.add_theme_stylebox_override("normal", btn_style)
	toggle_btn.add_theme_stylebox_override("hover", btn_style)
	toggle_btn.add_theme_stylebox_override("pressed", btn_style)
	toggle_btn.add_theme_stylebox_override("focus", btn_style)
	toggle_btn.pressed.connect(_on_support_button_pressed.bind(panel, toggle_btn))
	add_child(toggle_btn)


func _on_support_button_pressed(panel: Control, button: Button) -> void:
	var opening: bool = not panel.visible
	button.text = "收起" if opening else SUPPORT_BUTTON_TEXT
	if not opening:
		panel.size = Vector2(SUPPORT_PANEL_SIZE.x, 10.0)
		panel.visible = false
		return

	panel.visible = true
	panel.size = Vector2(SUPPORT_PANEL_SIZE.x, 10.0)
	var tween := create_tween()
	tween.tween_property(panel, "size", SUPPORT_PANEL_SIZE, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_kofi_clicked(_meta: Variant) -> void:
	OS.shell_open(KOFI_URL)


# ── 信号回调 ──

func _on_exercise_selected(type: String) -> void:
	GameManager.session_type = type
	get_tree().change_scene_to_file("res://src/scenes/main.tscn")


## 计时模式开关：切换 GameManager 配置并显示/隐藏秒数输入框
func _on_timed_mode_toggled(checked: bool) -> void:
	GameManager.timed_mode_enabled = checked
	_timed_input.visible = checked
	if checked:
		_timed_input.grab_focus()


## 秒数输入回车提交：正整数 1~600 生效（>600 截为 600），非法输入恢复当前值
func _on_timed_seconds_submitted(text: String) -> void:
	var value: int = 0
	var cleaned: String = text.strip_edges()
	if cleaned.is_valid_int():
		value = cleaned.to_int()
	if value < 1:
		_timed_input.text = str(int(GameManager.timed_mode_seconds))
		return
	value = min(value, 600)
	GameManager.timed_mode_seconds = float(value)
	_timed_input.text = str(value)
