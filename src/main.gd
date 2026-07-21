extends Node2D


# ── 常量 ──

const AREA_PADDING := 20.0         # 两个区域之间的间距
const BG_TARGET := Color(0.15, 0.15, 0.18, 1.0)   # 原图区背景
const BG_COPY   := Color(0.15, 0.15, 0.18, 1.0)   # 临摹区背景（和原图区一致）
const BORDER_COLOR := Color(0.35, 0.35, 0.40, 1.0)


# ── 内部状态 ──

var _exercise: BaseExercise = null
var _is_rotating: bool = false
var _prev_mouse_angle_deg: float = 0.0

## 两个区域的屏幕坐标矩形（每帧 _draw 前更新）
var _original_rect := Rect2()
var _copy_rect := Rect2()


# ── 子节点引用 ──

@onready var _submit_btn: Button = $UI/SubmitBtn
@onready var _hint_label: Label = $UI/HintLabel
@onready var _score_label: Label = $UI/ScoreLabel
@onready var _back_btn: Button = $UI/BackBtn


# ── 生命周期 ──

func _ready() -> void:
	# 连接 GameManager 信号
	GameManager.exercise_started.connect(_on_exercise_started)
	GameManager.result_ready.connect(_on_result_ready)
	GameManager.state_changed.connect(_on_state_changed)

	_submit_btn.pressed.connect(_on_submit_pressed)
	_back_btn.pressed.connect(_on_back_pressed)

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

	# 提交后：先画原图参考（半透明，在用户线段下方）
	if GameManager.get_state() == GameManager.State.SHOWING_RESULT and _exercise:
		_draw_geometry(_exercise.get_target_draw_date(), _copy_rect, 0.3)

	# 再画用户线段（在上方）
	_draw_geometry(_exercise.get_copy_draw_date() if _exercise else [], _copy_rect)


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
	var font := ThemeDB.fallback_font
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
	var scale: float = area_rect.size.x / logical_size.x
	var area_center := area_rect.position + area_rect.size / 2.0
	var logical_center: Vector2 = Settings.CANVAS.default_center

	for item in draw_data:
		var item_type: String = item.get("type", "")
		var color: Color = item["color"]
		if alpha < 1.0:
			color = Color(color.r, color.g, color.b, color.a * alpha)

		match item_type:
			"line":
				var from_local: Vector2 = _logical_to_screen(item["from"], area_center, logical_center, scale)
				var to_local: Vector2 = _logical_to_screen(item["to"], area_center, logical_center, scale)
				draw_line(from_local, to_local, color, item.get("width", 2.0), true)

			"circle":
				var c: Vector2 = _logical_to_screen(item["center"], area_center, logical_center, scale)
				var r: float = item["radius"] * scale
				draw_circle(c, r, color)

			"angle_arc":
				# 角度弧线（固定角度模式可用）
				var c: Vector2 = _logical_to_screen(item["center"], area_center, logical_center, scale)
				var r: float = item["radius"] * scale
				var from_rad: float = deg_to_rad(-item["from_angle_deg"])
				var to_rad: float = deg_to_rad(-item["to_angle_deg"])
				draw_arc(c, r, from_rad, to_rad, 32, color, 1.5, true)


func _logical_to_screen(logical_pos: Vector2, area_center: Vector2, logical_center: Vector2, scale: float) -> Vector2:
	# 1. 计算相对于逻辑中心的偏移
	var offset: Vector2 = logical_pos - logical_center
	# 2. 缩放到屏幕像素
	var scaled: Vector2 = offset * scale
	# 3. 平移到屏幕区域中心
	return area_center + scaled


# ── 输入处理 ──

func _input(event: InputEvent) -> void:
	if GameManager.get_state() != GameManager.State.PLAYING:
		return
	if not _exercise:
		return
	if _exercise.get_interaction_mode() != BaseExercise.InteractionMode.ROTATION:
		return

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


## 计算鼠标位置相对于临摹区中心的角度（度，Godot 坐标系：右=0，下=90）
func _mouse_to_angle(mouse_pos: Vector2) -> float:
	var center: Vector2 = _copy_rect.position + _copy_rect.size / 2.0
	var delta: Vector2 = mouse_pos - center
	return rad_to_deg(delta.angle())  # Godot Y-down: angle increases clockwise


## 两个角度之间的最短带符号差值（度），结果 (-180, 180]
func _shortest_angle_delta(from_deg: float, to_deg: float) -> float:
	var delta: float = fmod(to_deg - from_deg + 180.0, 360.0) - 180.0
	return delta


# ── 信号回调 ──

func _on_exercise_started(exercise: BaseExercise) -> void:
	_exercise = exercise
	_exercise.geometry_changed.connect(queue_redraw)
	_is_rotating = false

	_submit_btn.text = "提交"
	_submit_btn.disabled = false
	_hint_label.text = _exercise.get_hint_text()
	_hint_label.visible = not _hint_label.text.is_empty()
	_score_label.text = "第 %d 题 | 正确: %d | 连胜: %d" % [
		GameManager.get_round(),
		GameManager.get_correct_count(),
		GameManager.get_streak(),
	]

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

	var angle_err: float = result.get("angle_error", 0.0)
	var rating: String = _rating_display_text(result.get("rating", BaseExercise.Rating.PRACTICE))

	_score_label.text = "第 %d 题 | 正确: %d | 连胜: %d | %s" % [
		GameManager.get_round(),
		GameManager.get_correct_count(),
		GameManager.get_streak(),
		rating,
	]

	_hint_label.text = "偏差 %.1f°" % angle_err
	_hint_label.visible = true

	queue_redraw()


func _on_back_pressed() -> void:
	GameManager.reset_session()
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_state_changed(_state: GameManager.State) -> void:
	pass


## 将练习返回的 Rating 枚举映射为展示文字
func _rating_display_text(rating: BaseExercise.Rating) -> String:
	match rating:
		BaseExercise.Rating.FLAWLESS: return "★ 无暇"
		BaseExercise.Rating.PERFECT:  return "★ 完美"
		BaseExercise.Rating.PASS:     return "✓ 过关"
		_:                            return "继续练习"
