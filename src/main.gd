extends Node2D


# ── 常量 ──

const AREA_PADDING := 20.0         # 两个区域之间的间距
const BG_TARGET := Color(0.15, 0.15, 0.18, 1.0)   # 原图区背景
const BG_COPY   := Color(0.15, 0.15, 0.18, 1.0)   # 临摹区背景（和原图区一致）
const BORDER_COLOR := Color(0.35, 0.35, 0.40, 1.0)
const AREA_LABEL_FONT := preload("res://assets/fonts/SmileySans-Oblique.otf")


# ── 内部状态 ──

var _exercise: BaseExercise = null
var _is_rotating: bool = false
var _prev_mouse_angle_deg: float = 0.0
var _dragging_point_id: int = -1

## 两个区域的屏幕坐标矩形（每帧 _draw 前更新）
var _original_rect := Rect2()
var _copy_rect := Rect2()

## 固定数值模式 UI 状态
var _fixed_value_mode_enabled: bool = false
var _selected_fixed_value: float = 0.0
var _is_custom_value: bool = false
var _custom_value_text: String = ""


# ── 子节点引用 ──

@onready var _submit_btn: Button = $UI/SubmitBtn
@onready var _hint_label: Label = $UI/HintLabel
@onready var _score_label: Label = $UI/ScoreLabel
@onready var _back_btn: Button = $UI/BackBtn

@onready var _fixed_checkbox: CheckBox = $UI/FixedValueCheckBox
@onready var _fixed_dropdown: OptionButton = $UI/FixedValueDropdown
@onready var _fixed_custom_input: LineEdit = $UI/FixedValueCustomInput


# ── 生命周期 ──

func _ready() -> void:
	# 连接 GameManager 信号
	GameManager.exercise_started.connect(_on_exercise_started)
	GameManager.result_ready.connect(_on_result_ready)
	GameManager.state_changed.connect(_on_state_changed)

	_submit_btn.pressed.connect(_on_submit_pressed)
	_back_btn.pressed.connect(_on_back_pressed)

	# 固定数值模式 UI 连接
	_fixed_checkbox.toggled.connect(_on_fixed_value_checkbox_toggled)
	_fixed_dropdown.item_selected.connect(_on_fixed_value_dropdown_selected)
	_fixed_custom_input.text_submitted.connect(_on_fixed_value_custom_submitted)

	# 启动第一题
	GameManager.start_new_exercise()


# ── 渲染 ──

func _draw() -> void:
	_update_area_rects()

	# 原图区
	_draw_area_bg(_original_rect, BG_TARGET, "原图")
	_draw_geometry(_exercise.get_target_draw_date() if _exercise else [], _original_rect)

	# 临摹区
	_draw_area_bg(_copy_rect, BG_COPY, "临摹")

	# 先画用户线段（在下方）
	_draw_geometry(_exercise.get_copy_draw_date() if _exercise else [], _copy_rect)

	# 提交后：正确答案半透明叠加在最上方，便于与用户答案对比
	if GameManager.get_state() == GameManager.State.SHOWING_RESULT and _exercise:
		_draw_geometry(_exercise.get_answer_draw_date(), _copy_rect, 0.3)


func _update_area_rects() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var top_offset: float = 60.0  # 给顶部 UI 留空间
	var available_h: float = vp_size.y - top_offset - AREA_PADDING
	var area_size: float = min((vp_size.x - AREA_PADDING * 3) / 2.0, available_h)
	area_size = max(area_size, 100.0)  # 最小值保护

	_original_rect = Rect2(
		AREA_PADDING,
		top_offset + (available_h - area_size) / 2.0,
		area_size, area_size
	)
	_copy_rect = Rect2(
		AREA_PADDING * 2 + area_size,
		top_offset + (available_h - area_size) / 2.0,
		area_size, area_size
	)


func _draw_area_bg(rect: Rect2, bg_color: Color, label: String) -> void:
	draw_rect(rect, bg_color, true)
	draw_rect(rect, BORDER_COLOR, false, 1.0)
	# 区域标签
	var font := AREA_LABEL_FONT
	var font_size := 14
	draw_string(
		font,
		Vector2(rect.position.x + 6, rect.position.y + font_size + 4),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size,
		Color(0.6, 0.6, 0.6, 1.0)
	)


func _draw_geometry(draw_data: Array, area_rect: Rect2, alpha: float = 1.0) -> void:
	# 将练习逻辑坐标（以 area_center 为原点）映射到屏幕区域
	var logical_size: Vector2 = Settings.CANVAS.default_size
	var scale_current: float = area_rect.size.x / logical_size.x
	var area_center := area_rect.position + area_rect.size / 2.0
	var logical_center: Vector2 = Settings.CANVAS.default_center

	for item in draw_data:
		var item_type: String = item.get("type", "")
		var color: Color = item["color"]
		if alpha < 1.0:
			color = Color(color.r, color.g, color.b, color.a * alpha)

		match item_type:
			"line":
				var from_local: Vector2 = _logical_to_screen(item["from"], area_center, logical_center, scale_current)
				var to_local_current: Vector2 = _logical_to_screen(item["to"], area_center, logical_center, scale_current)
				draw_line(from_local, to_local_current, color, item.get("width", 2.0), true)

			"circle":
				var c: Vector2 = _logical_to_screen(item["center"], area_center, logical_center, scale_current)
				var r: float = item["radius"] * scale_current
				draw_circle(c, r, color)

			"control_point":
				var cp: Vector2 = _logical_to_screen(item["center"], area_center, logical_center, scale_current)
				var cp_radius: float = item.get("radius", Settings.CANVAS.control_point_radius) * scale_current
				draw_circle(cp, cp_radius, color)
				draw_arc(cp, cp_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9 * alpha), 2.0, true)


func _logical_to_screen(logical_pos: Vector2, area_center: Vector2, logical_center: Vector2, scale_current: float) -> Vector2:
	# 1. 计算相对于逻辑中心的偏移
	var offset: Vector2 = logical_pos - logical_center
	# 2. 缩放到屏幕像素
	var scaled: Vector2 = offset * scale_current
	# 3. 平移到屏幕区域中心
	return area_center + scaled


## 屏幕坐标 → 练习逻辑坐标（与 _logical_to_screen 互逆）
func _screen_to_logical(screen_pos: Vector2, area_rect: Rect2) -> Vector2:
	var logical_size: Vector2 = Settings.CANVAS.default_size
	var scale_current: float = area_rect.size.x / logical_size.x
	var area_center: Vector2 = area_rect.position + area_rect.size / 2.0
	var logical_center: Vector2 = Settings.CANVAS.default_center
	return logical_center + (screen_pos - area_center) / scale_current


# ── 输入处理 ──

func _input(event: InputEvent) -> void:
	if GameManager.get_state() != GameManager.State.PLAYING:
		return
	if not _exercise:
		return

	match _exercise.get_interaction_mode():
		BaseExercise.InteractionMode.ROTATION:
			_handle_rotation_input(event)
		BaseExercise.InteractionMode.LINE_CONSTAINED, BaseExercise.InteractionMode.FREE_MOVE:
			_handle_point_drag_input(event)


## 旋转模式输入：在临摹区按住拖动控制旋转
func _handle_rotation_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _copy_rect.has_point(mb.position):
				_is_rotating = true
				_prev_mouse_angle_deg = _mouse_to_angle(mb.position)
			else:
				_is_rotating = false

	elif event is InputEventMouseMotion:
		if _is_rotating:
			var current_angle: float = _mouse_to_angle(event.position)
			var delta: float = _shortest_angle_delta(_prev_mouse_angle_deg, current_angle)
			_exercise.on_rotation_input(delta)
			_prev_mouse_angle_deg = current_angle


## 控制点拖拽模式输入：命中可控点后拖动，位置交由练习约束
func _handle_point_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _copy_rect.has_point(mb.position):
					_dragging_point_id = _hit_test_control_point(mb.position)
				else:
					_dragging_point_id = -1
			else:
				_dragging_point_id = -1

	elif event is InputEventMouseMotion:
		if _dragging_point_id >= 0:
			var proposed: Vector2 = _screen_to_logical(event.position, _copy_rect)
			_exercise.on_point_dragged(_dragging_point_id, proposed)
			queue_redraw()


## 在临摹区命中检测可控点，返回其序号；未命中返回 -1
func _hit_test_control_point(screen_pos: Vector2) -> int:
	if not _exercise:
		return -1

	var logical_size: Vector2 = Settings.CANVAS.default_size
	var scale_current: float = _copy_rect.size.x / logical_size.x
	var area_center: Vector2 = _copy_rect.position + _copy_rect.size / 2.0
	var logical_center: Vector2 = Settings.CANVAS.default_center

	var hit_radius_logical: float = 20.0
	var point_id: int = 0
	for item in _exercise.get_copy_draw_date():
		if item.get("type", "") != "control_point":
			continue
		var c: Vector2 = _logical_to_screen(item["center"], area_center, logical_center, scale_current)
		if c.distance_to(screen_pos) <= hit_radius_logical * scale_current:
			return point_id
		point_id += 1
	return -1


## 计算鼠标位置相对于旋转中心的角度（度，Godot 坐标系：右=0，下=90）
func _mouse_to_angle(mouse_pos: Vector2) -> float:
	var pivot: Vector2 = _get_rotation_center_screen()
	var delta: Vector2 = mouse_pos - pivot
	return rad_to_deg(delta.angle())  # Godot Y-down: angle increases clockwise


## 将练习的旋转中心（逻辑坐标）换算为临摹区屏幕坐标
func _get_rotation_center_screen() -> Vector2:
	var logical_size: Vector2 = Settings.CANVAS.default_size
	var scale_current: float = _copy_rect.size.x / logical_size.x
	var area_center: Vector2 = _copy_rect.position + _copy_rect.size / 2.0
	var logical_center: Vector2 = Settings.CANVAS.default_center
	var logical_pivot: Vector2 = _exercise.get_rotation_center() if _exercise else logical_center
	return _logical_to_screen(logical_pivot, area_center, logical_center, scale_current)


## 两个角度之间的最短带符号差值（度），结果 (-180, 180]
func _shortest_angle_delta(from_deg: float, to_deg: float) -> float:
	var delta: float = fmod(to_deg - from_deg + 180.0, 360.0) - 180.0
	return delta


# ── 信号回调 ──

func _on_exercise_started(exercise: BaseExercise) -> void:
	_exercise = exercise
	_exercise.geometry_changed.connect(queue_redraw)
	_is_rotating = false
	_dragging_point_id = -1

	_submit_btn.text = "提交"
	_submit_btn.disabled = false
	_hint_label.text = _exercise.get_hint_text()
	_hint_label.visible = not _hint_label.text.is_empty()
	_score_label.text = "第 %d 题 | 正确: %d | 连胜: %d" % [
		GameManager.get_round(),
		GameManager.get_correct_count(),
		GameManager.get_streak(),
	]

	# 固定数值模式 UI 更新
	_update_fixed_value_ui()

	queue_redraw()


func _on_submit_pressed() -> void:
	# 根据当前状态决定行为：PLAYING → 提交，SHOWING_RESULT → 下一题
	match GameManager.get_state():
		GameManager.State.PLAYING:
			GameManager.submit_current_exercise()
		GameManager.State.SHOWING_RESULT:
			GameManager.next_exercise()


func _on_result_ready(result: Dictionary) -> void:
	_submit_btn.text = "下一题"

	var rating: String = _rating_display_text(result.get("rating", BaseExercise.Rating.PRACTICE))

	_score_label.text = "第 %d 题 | 正确: %d | 连胜: %d | %s" % [
		GameManager.get_round(),
		GameManager.get_correct_count(),
		GameManager.get_streak(),
		rating,
	]

	_hint_label.text = _exercise.get_error_display_text(result) if _exercise else ""
	_hint_label.visible = true

	queue_redraw()


func _on_back_pressed() -> void:
	GameManager.reset_session()
	get_tree().change_scene_to_file("res://src/scenes/menu.tscn")


func _on_state_changed(_state: GameManager.State) -> void:
	pass


## 将练习返回的 Rating 枚举映射为展示文字
func _rating_display_text(rating: BaseExercise.Rating) -> String:
	match rating:
		BaseExercise.Rating.FLAWLESS: return "无暇"
		BaseExercise.Rating.PERFECT:  return "完美"
		BaseExercise.Rating.PASS:     return "过关"
		_:                            return "继续练习"


# ── 固定数值模式 UI 逻辑 ──

## 根据当前练习更新固定数值模式相关的 UI 可见性和状态
func _update_fixed_value_ui() -> void:
	if not _exercise:
		return

	if _exercise.has_fixed_value_mode():
		_fixed_checkbox.visible = true
		_fixed_checkbox.button_pressed = _fixed_value_mode_enabled

		if _fixed_value_mode_enabled:
			_populate_fixed_value_dropdown()
			_fixed_dropdown.visible = true
			_restore_dropdown_selection()
		else:
			_fixed_dropdown.visible = false
			_fixed_custom_input.visible = false
	else:
		_fixed_checkbox.visible = false
		_fixed_dropdown.visible = false
		_fixed_custom_input.visible = false


## 用练习返回的预设选项填充下拉菜单（末尾追加"自定义..."）
func _populate_fixed_value_dropdown() -> void:
	_fixed_dropdown.clear()
	var labels: Array = _exercise.get_fixed_value_display_options()
	for label in labels:
		_fixed_dropdown.add_item(label)
	if _exercise.has_custom_fixed_value():
		_fixed_dropdown.add_item("自定义...")


## 根据当前选中的值恢复下拉菜单的选中项
func _restore_dropdown_selection() -> void:
	if _is_custom_value:
		_fixed_dropdown.select(_fixed_dropdown.item_count - 1)  # 最后一项 = "自定义..."
		_fixed_custom_input.visible = true
		_fixed_custom_input.text = _custom_value_text
		_fixed_custom_input.placeholder_text = _exercise.get_fixed_value_custom_placeholder()
		return

	var labels: Array = _exercise.get_fixed_value_display_options()
	for i in range(labels.size()):
		if absf(_exercise.parse_fixed_value_text(labels[i]) - _selected_fixed_value) < 0.01:
			_fixed_dropdown.select(i)
			_fixed_custom_input.visible = false
			return

	# 未匹配到预设值，默认选第一个
	if labels.size() > 0:
		_selected_fixed_value = _exercise.parse_fixed_value_text(labels[0])
		_fixed_dropdown.select(0)
	_fixed_custom_input.visible = false


## 固定数值模式复选框切换
func _on_fixed_value_checkbox_toggled(checked: bool) -> void:
	_fixed_value_mode_enabled = checked

	if checked:
		if _exercise and _exercise.has_fixed_value_mode():
			_populate_fixed_value_dropdown()
			_fixed_dropdown.visible = true

			# 首次打开时默认选中第一个预设值
			var labels: Array = _exercise.get_fixed_value_display_options()
			if _selected_fixed_value == 0.0 and labels.size() > 0:
				_selected_fixed_value = _exercise.parse_fixed_value_text(labels[0])
			_restore_dropdown_selection()

			_regenerate_with_fixed_value()
	else:
		_fixed_dropdown.visible = false
		_fixed_custom_input.visible = false
		_is_custom_value = false
		_regenerate_without_fixed_value()


## 固定数值下拉菜单选择变更
func _on_fixed_value_dropdown_selected(index: int) -> void:
	var item_text: String = _fixed_dropdown.get_item_text(index)

	if item_text == "自定义...":
		_is_custom_value = true
		_fixed_custom_input.visible = true
		_fixed_custom_input.text = _custom_value_text
		_fixed_custom_input.placeholder_text = _exercise.get_fixed_value_custom_placeholder()
		_fixed_custom_input.grab_focus()
	else:
		_is_custom_value = false
		_fixed_custom_input.visible = false
		_selected_fixed_value = _exercise.parse_fixed_value_text(item_text)
		_regenerate_with_fixed_value()


## 自定义数值输入框回车提交
func _on_fixed_value_custom_submitted(text: String) -> void:
	var value: float = _exercise.parse_fixed_value_text(text)
	if value < 0.0 or not _exercise.is_valid_fixed_value(value):
		return  # 非法输入：忽略并保留当前练习
	_selected_fixed_value = value
	_custom_value_text = text
	_regenerate_with_fixed_value()


## 以当前选中的固定数值重新生成练习（不增加回合数）
func _regenerate_with_fixed_value() -> void:
	var display_text: String = ""
	if _is_custom_value:
		display_text = _custom_value_text
	else:
		var idx: int = _fixed_dropdown.selected
		if idx >= 0:
			display_text = _fixed_dropdown.get_item_text(idx)
	GameManager.session_options = _exercise.build_fixed_value_session_options(_selected_fixed_value, display_text)
	GameManager.regenerate_exercise()


## 关闭固定数值模式，重新生成普通练习（不增加回合数）
func _regenerate_without_fixed_value() -> void:
	GameManager.session_options = _exercise.build_random_session_options()
	GameManager.regenerate_exercise()
