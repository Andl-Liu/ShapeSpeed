extends BaseExercise


# ── 常量 ──

## 线段端点距区域边缘的最小距离（逻辑像素）
const EDGE_MARGIN := 10.0

## 线段长度范围（逻辑像素）
const LINE_LENGTH_MIN := 50.0
const LINE_LENGTH_MAX := 300.0

## 评价档位（两端点匹配后的平均绝对偏差，逻辑像素）
const FLAWLESS_ERROR_PX := 1.0
const PERFECT_ERROR_PX := 3.0
const PASS_ERROR_PX := 10.0


# ── 公开属性（由 ExerciseFactory 在 generate() 之前设置）──

## 颜色相关
@export var color_target  := Settings.COLORS.target
@export var color_user    := Settings.COLORS.user
@export var color_correct := Settings.COLORS.correct

## 线宽相关
@export var line_width_main := Settings.LINE_WIDTH.main


# ── 内部状态 ──

var _target_a: Vector2 = Settings.CANVAS.default_center - Vector2(90.0, 0.0)
var _target_b: Vector2 = Settings.CANVAS.default_center + Vector2(90.0, 0.0)
var _user_a: Vector2 = _target_a
var _user_b: Vector2 = _target_b


# ── 辅助 ──

## 判断逻辑点是否位于"距区域边缘 ≥ EDGE_MARGIN"的边界框内
func _is_in_bounds(point: Vector2) -> bool:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_pos: float = size.x - EDGE_MARGIN
	return (
		point.x >= min_pos and point.x <= max_pos and
		point.y >= min_pos and point.y <= max_pos
	)


## 将点夹取到边界框内（用户拖拽时使用）
func _clamp_to_bounds(point: Vector2) -> Vector2:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_pos: float = size.x - EDGE_MARGIN
	return Vector2(
		clampf(point.x, min_pos, max_pos),
		clampf(point.y, min_pos, max_pos)
	)


## 随机采样一条完全落在边界框内的线段（长度 [MIN, MAX]，随机方向）
func _sample_segment() -> Array:
	var length: float = randf_range(LINE_LENGTH_MIN, LINE_LENGTH_MAX)
	var angle_deg: float = randf_range(0.0, 180.0)
	var dir: Vector2 = GeometryUtils.line_endpoint(Vector2.ZERO, angle_deg, 1.0)

	# 端点1 的可行范围：保证端点1 与端点2 = p + dir*length 均在边界框内
	var min_pos: float = EDGE_MARGIN
	var max_pos: float = Settings.CANVAS.default_size.x - EDGE_MARGIN
	var x_range := Vector2(
		max(min_pos, min_pos - dir.x * length),
		min(max_pos, max_pos - dir.x * length)
	)
	var y_range := Vector2(
		max(min_pos, min_pos - dir.y * length),
		min(max_pos, max_pos - dir.y * length)
	)

	var p: Vector2 = Vector2(randf_range(x_range.x, x_range.y), randf_range(y_range.x, y_range.y))
	return [p, p + dir * length]


## 将两个用户端点与两个目标端点做最小距离匹配（交换顺序也计为正确）。
## 返回 { "errors": Array, "error": float }；error = 两个匹配距离的平均值。
func _match_user_to_target() -> Dictionary:
	var d_aa: float = _user_a.distance_to(_target_a)
	var d_ab: float = _user_a.distance_to(_target_b)
	var d_ba: float = _user_b.distance_to(_target_a)
	var d_bb: float = _user_b.distance_to(_target_b)

	# 两种对应关系：直连 (A→a, B→b) 或交叉 (A→b, B→a)，取总偏差更小者
	var identity_total: float = d_aa + d_bb
	var swapped_total: float = d_ab + d_ba

	if identity_total <= swapped_total:
		return { "errors": [d_aa, d_bb], "error": identity_total / 2.0 }
	return { "errors": [d_ab, d_ba], "error": swapped_total / 2.0 }


## 根据平均绝对偏差返回评价等级
func _compute_rating(error_px: float) -> BaseExercise.Rating:
	if error_px <= FLAWLESS_ERROR_PX:
		return BaseExercise.Rating.FLAWLESS
	if error_px <= PERFECT_ERROR_PX:
		return BaseExercise.Rating.PERFECT
	if error_px <= PASS_ERROR_PX:
		return BaseExercise.Rating.PASS
	return BaseExercise.Rating.PRACTICE


## 生成结束后校验当前状态是否满足边界约束
func _validate_bounds() -> bool:
	return (
		_is_in_bounds(_target_a) and _is_in_bounds(_target_b) and
		_is_in_bounds(_user_a) and _is_in_bounds(_user_b)
	)


# ── BaseExercise 核心方法实现 ──

func generate(_difficulty: int) -> void:
	difficulty = _difficulty

	# 目标线段
	var target: Array = _sample_segment()
	_target_a = target[0]
	_target_b = target[1]

	# 初始用户线段：独立随机，两个端点均为可控点
	var initial: Array = _sample_segment()
	_user_a = initial[0]
	_user_b = initial[1]

	assert(_validate_bounds(), "Generated free segment geometry exceeds edge margin!")

	is_generated = true
	geometry_changed.emit()


func validate() -> Dictionary:
	assert(is_generated, "validate() called before generate()")

	var match_info: Dictionary = _match_user_to_target()
	var avg_error: float = match_info["error"]
	var rating: BaseExercise.Rating = _compute_rating(avg_error)
	# 与"过关"档（10px）对齐的评分容差
	var accuracy: float = clampf(1.0 - avg_error / PASS_ERROR_PX, 0.0, 1.0)
	var score: float = accuracy * 100.0

	var result := {
		"score": score,
		"accuracy": accuracy,
		"average_error_px": avg_error,
		"endpoint_errors_px": match_info["errors"],
		"rating": rating,
		"target_a": _target_a,
		"target_b": _target_b,
		"user_a": _user_a,
		"user_b": _user_b,
	}

	exercise_completed.emit(result)
	return result


func get_target_draw_date() -> Array:
	return [
		{
			"type": "line",
			"from": _target_a,
			"to": _target_b,
			"color": color_target,
			"width": line_width_main,
		},
		{
			"type": "circle",
			"center": _target_a,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_target,
		},
		{
			"type": "circle",
			"center": _target_b,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_target,
		},
	]


func get_copy_draw_date() -> Array:
	return [
		{
			"type": "line",
			"from": _user_a,
			"to": _user_b,
			"color": color_user,
			"width": line_width_main,
		},
		{
			"type": "control_point",
			"center": _user_a,
			"radius": Settings.CANVAS.control_point_radius,
			"color": color_user,
		},
		{
			"type": "control_point",
			"center": _user_b,
			"radius": Settings.CANVAS.control_point_radius,
			"color": color_user,
		},
	]


## 提交后叠加在临摹区的正确答案：绿色目标线段 + 两端点标记
func get_answer_draw_date() -> Array:
	return [
		{
			"type": "line",
			"from": _target_a,
			"to": _target_b,
			"color": color_correct,
			"width": line_width_main,
		},
		{
			"type": "circle",
			"center": _target_a,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_correct,
		},
		{
			"type": "circle",
			"center": _target_b,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_correct,
		},
	]


func get_hint_text() -> String:
	return ""


# ── 可选覆写 ──

func get_interaction_mode() -> BaseExercise.InteractionMode:
	return BaseExercise.InteractionMode.FREE_MOVE


## 两个端点均可自由拖动；位置夹取到边界框内
func on_point_dragged(point_id: int, proposed_position: Vector2) -> Vector2:
	var clamped: Vector2 = _clamp_to_bounds(proposed_position)
	if point_id == 0:
		_user_a = clamped
	else:
		_user_b = clamped
	geometry_changed.emit()
	return clamped


## 提交后偏差提示
func get_error_display_text(result: Dictionary) -> String:
	return "偏差 %.1fpx" % result.get("average_error_px", 0.0)
