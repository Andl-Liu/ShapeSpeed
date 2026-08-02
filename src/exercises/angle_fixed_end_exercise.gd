extends BaseExercise


# ── 公开属性（由 ExerciseFactory 在 generate() 之前设置）──

## 固定端在区域中的位置（逻辑坐标）
@export var fixed_end: Vector2 = Settings.CANVAS.default_center

## 线段全长（逻辑像素）
@export var line_length: float = Settings.CANVAS.default_line_length

## 是否启用固定角度模式
@export var is_fixed_angle_mode: bool = false

## 固定角度模式下，辅助线与目标线之间的夹角（度）
@export var fixed_angle_value_deg: float = 30.0

## 初始用户角度偏移目标角度的最小/最大范围（度）
@export var initial_offset_min_deg: float = 25.0
@export var initial_offset_max_deg: float = 90.0

## 颜色相关
@export var color_target    := Settings.COLORS.target
@export var color_user      := Settings.COLORS.user
@export var color_auxiliary := Settings.COLORS.auxiliary

## 线宽相关
@export var line_width_main := Settings.LINE_WIDTH.main
@export var line_width_aux  := Settings.LINE_WIDTH.auxiliary


# ── 内部状态 ──

var _target_angle_deg: float = 0.0
var _user_angle_deg: float = 0.0
var _aux_line_angle_deg: float = 0.0   # 辅助线在区域中的绝对角度


# ── 常量 ──

## 原图区域线条距区域边缘的最小距离（逻辑像素）
const EDGE_MARGIN := 10.0


# ── 辅助 ──

## 根据角度偏差返回评价等级——本练习的判定标准
func _compute_rating(error_deg: float) -> BaseExercise.Rating:
	if error_deg <= 0.3:  return BaseExercise.Rating.FLAWLESS
	if error_deg <= 1.0:  return BaseExercise.Rating.PERFECT
	if error_deg <= 2.0:  return BaseExercise.Rating.PASS
	return BaseExercise.Rating.PRACTICE


## 返回从 fixed_end 出发、沿给定角度、长度为 length 的线段端点对
func _angle_to_endpoints(angle_deg: float, length: float) -> Dictionary:
	var direction: Vector2 = GeometryUtils.line_endpoint(Vector2.ZERO, angle_deg, length)
	return { "from": fixed_end, "to": fixed_end + direction }


## 返回辅助线端点对：以 fixed_end 为中点、沿辅助角、总长 line_length
func _aux_endpoints() -> Dictionary:
	var half: float = line_length / 2.0
	var forward: Vector2 = GeometryUtils.line_endpoint(Vector2.ZERO, _aux_line_angle_deg, half)
	return { "from": fixed_end - forward, "to": fixed_end + forward }


## 判断逻辑点是否位于“距区域边缘 ≥ EDGE_MARGIN”的边界框内
func _is_in_bounds(point: Vector2) -> bool:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_x: float = size.x - EDGE_MARGIN
	var max_y: float = size.y - EDGE_MARGIN
	return (
		point.x >= min_pos and point.x <= max_x and
		point.y >= min_pos and point.y <= max_y
	)


## 按目标角计算可行的固定端矩形（x、y 各取边界交集），保证：
## 主线端点、辅助线两端点（固定角度模式下）均在边界框内。
## 返回 { "x_range": Vector2, "y_range": Vector2 }；区间可能为空（min > max）。
func _feasible_fixed_end_ranges(target_angle_deg: float) -> Dictionary:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_x: float = size.x - EDGE_MARGIN
	var max_y: float = size.y - EDGE_MARGIN

	# 主线自由端相对固定端的偏移
	var main_dir: Vector2 = GeometryUtils.line_endpoint(Vector2.ZERO, target_angle_deg, line_length)

	var x_range := Vector2(min_pos, max_x)
	var y_range := Vector2(min_pos, max_y)

	# 主线自由端约束：fixed_end + main_dir 须在边界框内
	x_range = Vector2(max(min_pos, min_pos - main_dir.x), min(max_x, max_x - main_dir.x))
	y_range = Vector2(max(min_pos, min_pos - main_dir.y), min(max_y, max_y - main_dir.y))

	# 固定角度模式：辅助线两端（fixed_end ± half * aux_dir）也须在边界框内
	if is_fixed_angle_mode:
		var aux_dir: Vector2 = GeometryUtils.line_endpoint(Vector2.ZERO, _aux_line_angle_deg, line_length / 2.0)
		x_range = Vector2(
			max(x_range.x, min_pos + absf(aux_dir.x)),
			min(x_range.y, max_x - absf(aux_dir.x))
		)
		y_range = Vector2(
			max(y_range.x, min_pos + absf(aux_dir.y)),
			min(y_range.y, max_y - absf(aux_dir.y))
		)

	return { "x_range": x_range, "y_range": y_range }


## 在可行固定端矩形内随机采样；矩形无效时回退到边界框中心。
func _sample_feasible_fixed_end(target_angle_deg: float) -> Vector2:
	var ranges: Dictionary = _feasible_fixed_end_ranges(target_angle_deg)
	var x_range: Vector2 = ranges["x_range"]
	var y_range: Vector2 = ranges["y_range"]

	var size: Vector2 = Settings.CANVAS.default_size
	var fallback := Vector2(size.x / 2.0, size.y / 2.0)

	if x_range.x > x_range.y or y_range.x > y_range.y:
		return fallback

	return Vector2(randf_range(x_range.x, x_range.y), randf_range(y_range.x, y_range.y))


## 生成结束后校验当前状态是否满足边界约束
func _validate_bounds() -> bool:
	if not _is_in_bounds(fixed_end):
		return false
	var target_ep: Dictionary = _angle_to_endpoints(_target_angle_deg, line_length)
	if not _is_in_bounds(target_ep["to"]):
		return false
	if is_fixed_angle_mode:
		var aux_ep: Dictionary = _aux_endpoints()
		if not _is_in_bounds(aux_ep["from"]) or not _is_in_bounds(aux_ep["to"]):
			return false
	return true


# ── BaseExercise 核心方法实现 ──

func generate(_difficulty: int) -> void:
	difficulty = _difficulty

	# 1. 从难度配置中取角度范围，随机生成目标角度
	var angle_min: float = Settings.get_settings(difficulty, "angle_range")[0]
	var angle_max: float = Settings.get_settings(difficulty, "angle_range")[1]
	_target_angle_deg = randf_range(angle_min, angle_max)

	# 2. 决定辅助线的绝对角度
	if is_fixed_angle_mode:
		_aux_line_angle_deg = _target_angle_deg + fixed_angle_value_deg
	else:
		_aux_line_angle_deg = 0.0  # 不使用

	# 3. 采样固定端：保证原图区域主线与辅助线均不越界
	fixed_end = _sample_feasible_fixed_end(_target_angle_deg)

	# 4. 决定用户的初始角度：在目标角度附近偏移，确保用户有事可做
	var offset: float = randf_range(initial_offset_min_deg, initial_offset_max_deg)
	if randi() % 2 == 0:
		offset = -offset
	_user_angle_deg = _target_angle_deg + offset

	assert(_validate_bounds(), "Generated target geometry exceeds edge margin!")

	is_generated = true
	geometry_changed.emit()


func validate() -> Dictionary:
	assert(is_generated, "validate() called before generate()")

	var angle_error: float = MathUtils.angle_difference_deg(_target_angle_deg, _user_angle_deg)
	var tolerance: float = Settings.get_settings(difficulty, "angle_tolerance")
	var accuracy: float = clampf(1.0 - angle_error / tolerance, 0.0, 1.0)
	var score: float = accuracy * 100.0

	var rating: BaseExercise.Rating = _compute_rating(angle_error)

	var result := {
		"score": score,
		"accuracy": accuracy,
		"angle_error": angle_error,
		"rating": rating,
		"target_angle": _target_angle_deg,
		"user_angle": _user_angle_deg,
	}

	exercise_completed.emit(result)
	return result


func get_target_draw_date() -> Array:
	var data: Array = []

	# 目标主线：从固定端沿目标角延伸 line_length
	var ep := _angle_to_endpoints(_target_angle_deg, line_length)
	data.append({
		"type": "line",
		"from": ep["from"],
		"to": ep["to"],
		"color": color_target,
		"width": line_width_main,
	})

	# 固定端标记
	data.append({
		"type": "circle",
		"center": fixed_end,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_target,
	})

	# 固定角度模式：辅助线
	if is_fixed_angle_mode:
		var aux_ep := _aux_endpoints()
		data.append({
			"type": "line",
			"from": aux_ep["from"],
			"to": aux_ep["to"],
			"color": color_auxiliary,
			"width": line_width_aux,
			"dashed": true,
		})

	return data


func get_copy_draw_date() -> Array:
	var data: Array = []

	# 用户主线：从固定端沿用户角延伸 line_length
	var ep := _angle_to_endpoints(_user_angle_deg, line_length)
	data.append({
		"type": "line",
		"from": ep["from"],
		"to": ep["to"],
		"color": color_user,
		"width": line_width_main,
	})

	# 固定端标记
	data.append({
		"type": "circle",
		"center": fixed_end,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_user,
	})

	# 固定角度模式：在临摹区也画辅助线
	if is_fixed_angle_mode:
		var aux_ep := _aux_endpoints()
		data.append({
			"type": "line",
			"from": aux_ep["from"],
			"to": aux_ep["to"],
			"color": color_auxiliary,
			"width": line_width_aux,
			"dashed": true,
		})

	return data


func get_hint_text() -> String:
	if is_fixed_angle_mode:
		return "%d°" % int(fixed_angle_value_deg)
	return ""


# ── 可选覆写 ──

func get_interaction_mode() -> BaseExercise.InteractionMode:
	return BaseExercise.InteractionMode.ROTATION


## 旋转以固定端为圆心
func get_rotation_center() -> Vector2:
	return fixed_end


func on_rotation_input(delta_angle_deg: float) -> void:
	_user_angle_deg += delta_angle_deg
	_user_angle_deg = MathUtils.normalize_angle_deg(_user_angle_deg)
	geometry_changed.emit()


# ── 固定数值模式 ──

func has_fixed_value_mode() -> bool:
	return true

## 返回固定角度模式下的预设角度选项（度）
func get_fixed_value_options() -> Array:
	return [30.0, 45.0, 60.0, 90.0]
