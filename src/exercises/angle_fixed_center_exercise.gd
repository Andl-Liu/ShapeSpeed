extends BaseExercise


# ── 公开属性（由 ExerciseFactory 在 generate() 之前设置） ──

## 旋转中心在区域中的位置（逻辑坐标）
@export var center: Vector2 = Settings.CANVAS.default_center

## 线段全长（逻辑像素）
@export var line_length: float = Settings.CANVAS.default_line_length

## 是否启用固定角度模式
@export var is_fixed_angle_mode: bool = false

## 固定角度模式下，辅助线与目标线之间的夹角（度）
@export var fixed_angle_value_deg: float = 30.0

## 初始用户角度偏离目标角度的最小/最大范围（度）
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


# ── 辅助 ──

## 根据角度偏差返回评价等级——本练习的判定标准
func _compute_rating(error_deg: float) -> BaseExercise.Rating:
	if error_deg <= 0.3:  return BaseExercise.Rating.FLAWLESS
	if error_deg <= 1.0:  return BaseExercise.Rating.PERFECT
	if error_deg <= 2.0:  return BaseExercise.Rating.PASS
	return BaseExercise.Rating.PRACTICE


## 返回以 center 为中点、沿给定角度的线段的 (from, to) 端点对
func _angle_to_endpoints(angle_deg: float, length: float) -> Dictionary:
	var half: float = length / 2.0
	var forward: Vector2 = GeometryUtils.line_endpoint(center, angle_deg, half)
	var backward: Vector2 = center - (forward - center)
	return { "from": backward, "to": forward }


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

	# 3. 决定用户的初始角度：在目标角度附近偏移，确保用户有事可做
	var offset: float = randf_range(initial_offset_min_deg, initial_offset_max_deg)
	if randi() % 2 == 0:
		offset = -offset
	_user_angle_deg = _target_angle_deg + offset

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

	# 目标线段：以 center 为中点
	var ep := _angle_to_endpoints(_target_angle_deg, line_length)
	data.append({
		"type": "line",
		"from": ep["from"],
		"to": ep["to"],
		"color": color_target,
		"width": line_width_main,
	})

	# 圆心标记
	data.append({
		"type": "circle",
		"center": center,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_target,
	})

	# 固定角度模式：辅助线 + 角度弧线
	if is_fixed_angle_mode:
		var aux_ep := _angle_to_endpoints(_aux_line_angle_deg, line_length)
		data.append({
			"type": "line",
			"from": aux_ep["from"],
			"to": aux_ep["to"],
			"color": color_auxiliary,
			"width": line_width_aux,
			"dashed": true,
		})
		data.append({
			"type": "angle_arc",
			"center": center,
			"radius": Settings.CANVAS.angle_arc_radius,
			"from_angle_deg": _target_angle_deg,
			"to_angle_deg": _aux_line_angle_deg,
			"color": color_auxiliary,
		})

	return data


func get_copy_draw_date() -> Array:
	var data: Array = []

	# 用户线段：以 center 为中点
	var ep := _angle_to_endpoints(_user_angle_deg, line_length)
	data.append({
		"type": "line",
		"from": ep["from"],
		"to": ep["to"],
		"color": color_user,
		"width": line_width_main,
	})

	# 圆心标记
	data.append({
		"type": "circle",
		"center": center,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_user,
	})

	# 固定角度模式：在临摹区也画辅助线
	if is_fixed_angle_mode:
		var aux_ep := _angle_to_endpoints(_aux_line_angle_deg, line_length)
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


# ── 可选覆盖 ──

func get_interaction_mode() -> BaseExercise.InteractionMode:
	return BaseExercise.InteractionMode.ROTATION


func on_rotation_input(delta_angle_deg: float) -> void:
	_user_angle_deg += delta_angle_deg
	_user_angle_deg = MathUtils.normalize_angle_deg(_user_angle_deg)
	geometry_changed.emit()
