extends Node2D


# ── 常量 ──

const AREA_PADDING := 20.0         # 两个区域之间的间距
const BG_TARGET := Color(0.15, 0.15, 0.18, 1.0)   # 原图区背景
const BG_COPY   := Color(0.15, 0.15, 0.18, 1.0)   # 临摹区背景（和原图区一致）
const BORDER_COLOR := Color(0.35, 0.35, 0.40, 1.0)
const AREA_LABEL_FONT := preload("res://assets/fonts/SmileySans-Oblique.otf")
const LONG_PRESS_MS := 400       # 长按判定阈值（毫秒）
const TAP_SLOP_PX := 10.0        # 点击判定允许的最大位移（屏幕像素）


# ── 内部状态 ──

var _exercise: BaseExercise = null
var _is_rotating: bool = false
var _prev_mouse_angle_deg: float = 0.0
var _dragging_point_id: int = -1
var _elapsed_seconds: float = 0.0
var _displayed_seconds: int = -1
var _time_up_played: bool = false
var _active_point_id: int = -1           # 点击激活的可控点序号（-1 = 无）
var _blank_drag_active: bool = false     # 是否正在通过空白长按相对拖动
var _blank_press_pending: bool = false   # 空白处按住，等待长按判定
var _press_position: Vector2 = Vector2.ZERO   # 最近一次按下的屏幕位置
var _press_time_msec: int = 0                 # 最近一次按下的时间戳
var _last_drag_position: Vector2 = Vector2.ZERO  # 相对拖动时上一次的位置
var _drag_pop_played: bool = false            # 本次按下是否已播过拖动提示音
var _direction_mode: int = 0                  # 长度练习方向模式：0=随机 1=竖直 2=水平

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
@onready var _time_label: Label = $UI/TimeLabel

@onready var _fixed_checkbox: CheckBox = $UI/FixedValueCheckBox
@onready var _fixed_dropdown: OptionButton = $UI/FixedValueDropdown
@onready var _fixed_custom_input: LineEdit = $UI/FixedValueCustomInput
@onready var _gear_btn: Button = $UI/GearButton
@onready var _direction_panel: PanelContainer = $UI/DirectionPanel
@onready var _direction_random_radio: CheckBox = $UI/DirectionPanel/Margin/VBox/DirectionRandomRadio
@onready var _direction_vertical_radio: CheckBox = $UI/DirectionPanel/Margin/VBox/DirectionVerticalRadio
@onready var _direction_horizontal_radio: CheckBox = $UI/DirectionPanel/Margin/VBox/DirectionHorizontalRadio


# ── 生命周期 ──

func _ready() -> void:
	# 连接 GameManager 信号
	GameManager.exercise_started.connect(_on_exercise_started)
	GameManager.result_ready.connect(_on_result_ready)
	GameManager.state_changed.connect(_on_state_changed)

	_submit_btn.pressed.connect(_on_submit_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	_gear_btn.pressed.connect(_on_gear_button_pressed)

	# 固定数值模式 UI 连接
	_fixed_checkbox.toggled.connect(_on_fixed_value_checkbox_toggled)
	_fixed_dropdown.item_selected.connect(_on_fixed_value_dropdown_selected)
	_fixed_custom_input.text_submitted.connect(_on_fixed_value_custom_submitted)
	_direction_random_radio.toggled.connect(_on_direction_radio_toggled.bind(0))
	_direction_vertical_radio.toggled.connect(_on_direction_radio_toggled.bind(1))
	_direction_horizontal_radio.toggled.connect(_on_direction_radio_toggled.bind(2))

	# 启动第一题
	GameManager.start_new_exercise()


# ── 时间与计时模式 ──

func _process(delta: float) -> void:
	if GameManager.get_state() != GameManager.State.PLAYING:
		return

	# 空白长按满阈值后立即升级为相对拖动，避免依赖移动事件触发
	_try_start_blank_drag()

	_elapsed_seconds += delta
	var seconds: int = int(_elapsed_seconds)
	if seconds != _displayed_seconds:
		_displayed_seconds = seconds
		_time_label.text = "时间: %ds" % seconds

	# 计时模式：最后两秒播放提示音，达到目标秒数自动提交（提交后状态变化，本函数随即停止）
	if GameManager.timed_mode_enabled:
		if not _time_up_played and _elapsed_seconds >= GameManager.timed_mode_seconds - 2.0:
			_time_up_played = true
			AudioManager.play_time_up()
		if _elapsed_seconds >= GameManager.timed_mode_seconds:
			GameManager.submit_current_exercise()


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

	var control_point_index := 0
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
				# 未激活、未拖动的可控点显示灰色；激活中或被拖动的点显示原色
				var point_color: Color = color
				if control_point_index != _active_point_id and control_point_index != _dragging_point_id:
					point_color = Settings.COLORS.auxiliary
					if alpha < 1.0:
						point_color = Color(point_color.r, point_color.g, point_color.b, point_color.a * alpha)
				draw_circle(cp, cp_radius, point_color)
				control_point_index += 1


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


## 控制点输入：
## - 按住可控点 → 直接拖动（现状）
## - 快速点击可控点 → 激活/取消激活（灰色↔原色）
## - 按住空白 → 长按后相对拖动已激活的点；快速点击空白 → 取消激活
func _handle_point_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_position = mb.position
			_press_time_msec = Time.get_ticks_msec()
			_drag_pop_played = false
			if _copy_rect.has_point(mb.position):
				var hit_id: int = _hit_test_control_point(mb.position)
				if hit_id >= 0:
					# 按住可控点：立即开始直接拖动
					_dragging_point_id = hit_id
					_blank_press_pending = false
					_blank_drag_active = false
				else:
					# 按住空白：等待长按，用于相对拖动激活的点
					_dragging_point_id = -1
					_blank_press_pending = true
			else:
				_dragging_point_id = -1
				_blank_press_pending = false
		else:
			_release_point_drag(mb.position)

	elif event is InputEventMouseMotion:
		if _dragging_point_id >= 0:
			if _blank_drag_active:
				# 空白相对拖动：激活点跟随手指位移（不跳到手指位置）
				_apply_blank_drag_delta(event.position - _last_drag_position)
				_last_drag_position = event.position
				queue_redraw()
			else:
				# 直接拖动：点跟随手指绝对位置（现状）
				if not _drag_pop_played:
					_drag_pop_played = true
					AudioManager.play_pop()
				var proposed: Vector2 = _screen_to_logical(event.position, _copy_rect)
				_exercise.on_point_dragged(_dragging_point_id, proposed)
				queue_redraw()

		elif _blank_press_pending:
			if _try_start_blank_drag():
				# 升级的同一事件内立即应用位移，消除长按后点慢半拍的延迟
				_apply_blank_drag_delta(event.position - _last_drag_position)
				_last_drag_position = event.position


## 空白长按满阈值且有点被激活时，把长按升级为相对拖动。
## 以按下位置为拖动基准，保证开始移动后点立即跟随完整位移。
func _try_start_blank_drag() -> bool:
	if not _blank_press_pending or _active_point_id < 0:
		return false
	if Time.get_ticks_msec() - _press_time_msec < LONG_PRESS_MS:
		return false
	_blank_press_pending = false
	_dragging_point_id = _active_point_id
	_blank_drag_active = true
	_last_drag_position = _press_position
	_drag_pop_played = true
	AudioManager.play_pop()
	queue_redraw()
	return true


## 应用一次空白相对拖动（screen_delta 为屏幕位移）
func _apply_blank_drag_delta(screen_delta: Vector2) -> void:
	if _dragging_point_id < 0:
		return
	var current: Vector2 = _get_control_point_position(_dragging_point_id)
	var proposed: Vector2 = current + _screen_delta_to_logical(screen_delta)
	_exercise.on_point_dragged(_dragging_point_id, proposed)


## 松开：区分点击与拖动，更新激活状态并清理拖拽状态
func _release_point_drag(release_position: Vector2) -> void:
	if _blank_press_pending:
		# 空白处快速松开且无位移 = 点击空白 → 取消激活；有位移视为滑动，忽略
		var moved: float = _press_position.distance_to(release_position)
		var duration: int = Time.get_ticks_msec() - _press_time_msec
		if moved <= TAP_SLOP_PX and duration < LONG_PRESS_MS:
			_active_point_id = -1
	elif _dragging_point_id >= 0 and not _blank_drag_active:
		# 直接在可控点上快速松开且无位移 = 点击 → 切换激活状态
		var moved: float = _press_position.distance_to(release_position)
		var duration: int = Time.get_ticks_msec() - _press_time_msec
		if moved <= TAP_SLOP_PX and duration < LONG_PRESS_MS:
			if _active_point_id == _dragging_point_id:
				_active_point_id = -1
			else:
				_active_point_id = _dragging_point_id

	_dragging_point_id = -1
	_blank_drag_active = false
	_blank_press_pending = false
	queue_redraw()


## 返回指定可控点当前的逻辑坐标（按临摹绘制数据中的顺序）
func _get_control_point_position(point_id: int) -> Vector2:
	var idx: int = 0
	for item in _exercise.get_copy_draw_date():
		if item.get("type", "") != "control_point":
			continue
		if idx == point_id:
			return item["center"]
		idx += 1
	return Settings.CANVAS.default_center


## 屏幕位移 → 逻辑位移
func _screen_delta_to_logical(screen_delta: Vector2) -> Vector2:
	var logical_size: Vector2 = Settings.CANVAS.default_size
	var scale_current: float = _copy_rect.size.x / logical_size.x
	return screen_delta / scale_current


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
	_active_point_id = -1
	_blank_drag_active = false
	_blank_press_pending = false
	_drag_pop_played = false
	_elapsed_seconds = 0.0
	_displayed_seconds = -1
	_time_up_played = false
	_time_label.text = "时间: 0s"

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
	# 方向模式 UI 更新
	_update_direction_ui()

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

	# 结果音效：过关及以上播 correct，继续练习播 fail
	if result.get("rating", BaseExercise.Rating.PRACTICE) == BaseExercise.Rating.PRACTICE:
		AudioManager.play_fail()
	else:
		AudioManager.play_correct()

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
	_apply_direction_to_session_options()
	GameManager.regenerate_exercise()


## 关闭固定数值模式，重新生成普通练习（不增加回合数）
func _regenerate_without_fixed_value() -> void:
	GameManager.session_options = _exercise.build_random_session_options()
	_apply_direction_to_session_options()
	GameManager.regenerate_exercise()


# ── 齿轮参数面板 UI 逻辑（随机/竖直/水平，长度练习） ──

## 根据当前练习更新齿轮按钮的可见性，并同步面板内方向选项的选中状态
func _update_direction_ui() -> void:
	var show: bool = _exercise != null and _exercise.has_gear_button()
	_gear_btn.visible = show
	if not show:
		_direction_panel.visible = false
		return

	# 从当前练习同步方向模式（首次进入默认随机），用 no_signal 避免触发重新生成
	if "direction_mode" in _exercise:
		_direction_mode = _exercise.direction_mode
	_direction_random_radio.set_pressed_no_signal(_direction_mode == 0)
	_direction_vertical_radio.set_pressed_no_signal(_direction_mode == 1)
	_direction_horizontal_radio.set_pressed_no_signal(_direction_mode == 2)


## 齿轮按钮：展开/收起方向参数面板
func _on_gear_button_pressed() -> void:
	_direction_panel.visible = not _direction_panel.visible


## 方向单选项切换：更新模式并重新生成当前练习（不增加回合数）
func _on_direction_radio_toggled(pressed: bool, mode: int) -> void:
	if not pressed:
		return
	if _direction_mode == mode:
		return
	_direction_mode = mode
	_apply_direction_to_session_options()
	GameManager.regenerate_exercise()


## 把当前方向模式写入会话参数（仅对支持方向模式的练习）
func _apply_direction_to_session_options() -> void:
	if _exercise and _exercise.has_gear_button():
		GameManager.session_options["direction_mode"] = _direction_mode
