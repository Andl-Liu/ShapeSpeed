extends BaseExercise


# ── 常量 ──

## 原图/辅助/正确答案线距区域边缘的最小距离（逻辑像素）
const EDGE_MARGIN := 10.0

## 原图线段长度范围（逻辑像素）
const LINE_LENGTH_MIN := 50.0
const LINE_LENGTH_MAX := 300.0

## 等分答案线的最短长度（逻辑像素）
const MIN_ANSWER_LENGTH := 30.0

## 自定义比值的合法范围（r = 答案长 / 原图长）
const CUSTOM_RATIO_MIN := 0.1
const CUSTOM_RATIO_MAX := 9.0


# ── 公开属性（由 ExerciseFactory 在 generate() 之前设置）──

## 是否启用固定数值模式（等分/延长）
@export var is_fixed_length_mode: bool = false

## 固定数值模式下的目标比值 r = 答案长 / 原图长
@export var fixed_ratio: float = 1.0

## 固定数值模式下用户选择/输入的显示文本（用于提示，如 "2/5"、"3"）
@export var fixed_ratio_text: String = ""

## 颜色相关
@export var color_target    := Settings.COLORS.target
@export var color_user      := Settings.COLORS.user
@export var color_auxiliary := Settings.COLORS.auxiliary
@export var color_correct   := Settings.COLORS.correct

## 线宽相关
@export var line_width_main := Settings.LINE_WIDTH.main
@export var line_width_aux  := Settings.LINE_WIDTH.auxiliary


# ── 内部状态 ──

var _anchor: Vector2 = Settings.CANVAS.default_center      # 锚点 A
var _line_angle_deg: float = 0.0                           # 线段方向角
var _original_length: float = Settings.CANVAS.default_line_length  # 原图长度 L
var _target_length: float = _original_length               # 答案长度 r·L
var _user_length: float = 0.0                              # 可控点距锚点的距离 t


# ── 辅助 ──

## 返回单位方向向量（沿线段倾斜方向）
func _get_direction() -> Vector2:
	return GeometryUtils.line_endpoint(Vector2.ZERO, _line_angle_deg, 1.0)


## 判断逻辑点是否位于"距区域边缘 ≥ EDGE_MARGIN"的边界框内
func _is_in_bounds(point: Vector2) -> bool:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_x: float = size.x - EDGE_MARGIN
	var max_y: float = size.y - EDGE_MARGIN
	return (
		point.x >= min_pos and point.x <= max_x and
		point.y >= min_pos and point.y <= max_y
	)


## 按方向向量计算可行的锚点矩形，保证 A + dir * extent 仍在边界框内。
## 返回 { "x_range": Vector2, "y_range": Vector2 }；区间可能为空（min > max）。
func _feasible_anchor_ranges(dir: Vector2, extent: float) -> Dictionary:
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_x: float = size.x - EDGE_MARGIN
	var max_y: float = size.y - EDGE_MARGIN

	var x_range := Vector2(
		max(min_pos, min_pos - dir.x * extent),
		min(max_x, max_x - dir.x * extent)
	)
	var y_range := Vector2(
		max(min_pos, min_pos - dir.y * extent),
		min(max_y, max_y - dir.y * extent)
	)
	return { "x_range": x_range, "y_range": y_range }


## 在可行锚点矩形内随机采样；矩形无效时返回区域中心（调用方需重试）
func _sample_anchor(dir: Vector2, extent: float) -> Vector2:
	var ranges: Dictionary = _feasible_anchor_ranges(dir, extent)
	var x_range: Vector2 = ranges["x_range"]
	var y_range: Vector2 = ranges["y_range"]

	var size: Vector2 = Settings.CANVAS.default_size
	var fallback := Vector2(size.x / 2.0, size.y / 2.0)

	if x_range.x > x_range.y or y_range.x > y_range.y:
		return fallback

	return Vector2(randf_range(x_range.x, x_range.y), randf_range(y_range.x, y_range.y))


## 可控点沿方向线可到达的最大距离 t（保证不越出边界框）
func _max_user_t() -> float:
	var dir: Vector2 = _get_direction()
	var min_pos: float = EDGE_MARGIN
	var max_pos: float = Settings.CANVAS.default_size.x - EDGE_MARGIN
	var t_max: float = INF

	if absf(dir.x) > 0.0001:
		t_max = minf(t_max, (max_pos - _anchor.x) / dir.x if dir.x > 0.0 else (_anchor.x - min_pos) / -dir.x)
	if absf(dir.y) > 0.0001:
		t_max = minf(t_max, (max_pos - _anchor.y) / dir.y if dir.y > 0.0 else (_anchor.y - min_pos) / -dir.y)

	return t_max


## 生成结束后校验当前状态是否满足边界约束
func _validate_bounds() -> bool:
	if not _is_in_bounds(_anchor):
		return false
	var dir: Vector2 = _get_direction()
	# 辅助线端点 B
	if not _is_in_bounds(_anchor + dir * _original_length):
		return false
	# 正确答案端点
	if not _is_in_bounds(_anchor + dir * _target_length):
		return false
	# 初始可控点（等分/延长在 B，等长复刻在 A）
	var initial_t: float = _original_length if is_fixed_length_mode else 0.0
	if not _is_in_bounds(_anchor + dir * initial_t):
		return false
	return true


## 根据绝对像素偏差返回评价等级
func _compute_rating(error_px: float) -> BaseExercise.Rating:
	var tiers: Dictionary = Settings.get_rating_tiers("length")
	if error_px <= tiers["flawless"]:
		return BaseExercise.Rating.FLAWLESS
	if error_px <= tiers["perfect"]:
		return BaseExercise.Rating.PERFECT
	if error_px <= tiers["pass"]:
		return BaseExercise.Rating.PASS
	return BaseExercise.Rating.PRACTICE


# ── BaseExercise 核心方法实现 ──

func generate(_difficulty: int) -> void:
	difficulty = _difficulty

	var ratio: float = fixed_ratio if is_fixed_length_mode else 1.0
	_target_length = 0.0  # 占位，稍后统一计算

	# 等分模式下答案线不得短于 MIN_ANSWER_LENGTH
	var min_length: float = LINE_LENGTH_MIN
	if ratio < 1.0:
		min_length = maxf(LINE_LENGTH_MIN, MIN_ANSWER_LENGTH / ratio)

	# 绑定长度 = max(原图长, 答案长)；等分(r<1)时原图最长，延长(r≥1)时答案最长
	var extent_ratio: float = maxf(1.0, ratio)

	var found := false
	for i in range(64):
		_line_angle_deg = randf_range(0.0, 180.0)
		_original_length = randf_range(min_length, LINE_LENGTH_MAX)
		var dir: Vector2 = _get_direction()
		var extent: float = _original_length * extent_ratio
		_anchor = _sample_anchor(dir, extent)
		if _is_in_bounds(_anchor) and _is_in_bounds(_anchor + dir * extent):
			found = true
			break

	if not found:
		# 回退：对角方向 max(|cos|,|sin|) 最小，能容纳最长的线段
		_line_angle_deg = 45.0 if randi() % 2 == 0 else 135.0
		var dir: Vector2 = _get_direction()
		var max_component: float = maxf(absf(dir.x), absf(dir.y))
		var max_extent: float = (Settings.CANVAS.default_size.x - 2.0 * EDGE_MARGIN) / max_component
		_original_length = minf(_original_length, max_extent / extent_ratio)
		_original_length = maxf(_original_length, min_length)
		var extent: float = _original_length * extent_ratio
		_anchor = _sample_anchor(dir, extent)

	_target_length = _original_length * ratio

	# 初始用户长度：等长复刻从锚点拉出；等分/延长从辅助线远端开始
	_user_length = _original_length if is_fixed_length_mode else 0.0

	assert(_validate_bounds(), "Generated length geometry exceeds edge margin!")

	is_generated = true
	geometry_changed.emit()


func validate() -> Dictionary:
	assert(is_generated, "validate() called before generate()")

	var length_error_px: float = absf(_user_length - _target_length)
	var rating: BaseExercise.Rating = _compute_rating(length_error_px)
	# 评分容差与"过关"档对齐，延续"过关=容差=0分"的模式
	var pass_px: float = Settings.get_pass_threshold("length")
	var accuracy: float = clampf(1.0 - length_error_px / pass_px, 0.0, 1.0)
	var score: float = accuracy * 100.0

	var result := {
		"score": score,
		"accuracy": accuracy,
		"length_error_px": length_error_px,
		"rating": rating,
		"user_length": _user_length,
		"target_length": _target_length,
	}

	exercise_completed.emit(result)
	return result


func get_target_draw_date() -> Array:
	var data: Array = []
	var dir: Vector2 = _get_direction()

	# 原图主线：从锚点 A 沿方向延伸原图长度 L
	data.append({
		"type": "line",
		"from": _anchor,
		"to": _anchor + dir * _original_length,
		"color": color_target,
		"width": line_width_main,
	})

	# 锚点标记
	data.append({
		"type": "circle",
		"center": _anchor,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_target,
	})

	return data


func get_copy_draw_date() -> Array:
	var data: Array = []
	var dir: Vector2 = _get_direction()

	# 等分/延长：临摹区显示与原图相同的辅助线
	if is_fixed_length_mode:
		data.append({
			"type": "line",
			"from": _anchor,
			"to": _anchor + dir * _original_length,
			"color": color_auxiliary,
			"width": line_width_aux,
			"dashed": true,
		})

	# 用户线段（从锚点拉到可控点；长度过短时省略绘制）
	if _user_length > 0.5:
		data.append({
			"type": "line",
			"from": _anchor,
			"to": _anchor + dir * _user_length,
			"color": color_user,
			"width": line_width_main,
		})

	# 锚点标记
	data.append({
		"type": "circle",
		"center": _anchor,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_user,
	})

	# 可控点
	data.append({
		"type": "control_point",
		"center": _anchor + dir * _user_length,
		"radius": Settings.CANVAS.control_point_radius,
		"color": color_user,
	})

	return data


## 提交后叠加在临摹区的正确答案：绿色答案线段 + 答案点标记
func get_answer_draw_date() -> Array:
	var data: Array = []
	var dir: Vector2 = _get_direction()
	var answer_end: Vector2 = _anchor + dir * _target_length

	data.append({
		"type": "line",
		"from": _anchor,
		"to": answer_end,
		"color": color_correct,
		"width": line_width_main,
	})

	data.append({
		"type": "circle",
		"center": answer_end,
		"radius": Settings.CANVAS.center_dot_radius,
		"color": color_correct,
	})

	return data


func get_hint_text() -> String:
	if not is_fixed_length_mode:
		return ""

	var text: String = fixed_ratio_text
	if text.is_empty():
		text = "%.2f" % fixed_ratio

	if fixed_ratio < 1.0:
		return text  # 等分，如 "2/5"
	return "%s倍" % text  # 延长，如 "3倍"


# ── 可选覆写 ──

func get_interaction_mode() -> BaseExercise.InteractionMode:
	return BaseExercise.InteractionMode.LINE_CONSTAINED


## 可控点只能沿线段方向移动；t 夹取到 [0, 不越界最大距离]
func on_point_dragged(_point_id: int, proposed_position: Vector2) -> Vector2:
	var dir: Vector2 = _get_direction()
	var t: float = (proposed_position - _anchor).dot(dir)
	t = clampf(t, 0.0, _max_user_t())
	_user_length = t
	geometry_changed.emit()
	return _anchor + dir * t


## 提交后偏差提示
func get_error_display_text(result: Dictionary) -> String:
	return "偏差 %.1fpx" % result.get("length_error_px", 0.0)


# ── 固定数值模式 ──

func has_fixed_value_mode() -> bool:
	return true


## 预设比值（分数=等分，倍数=延长）
func get_fixed_value_options() -> Array:
	return [0.5, 1.0 / 3.0, 0.25, 0.2, 0.4, 2.0, 3.0]


## 下拉显示文本
func get_fixed_value_display_options() -> Array:
	return ["1/2", "1/3", "1/4", "1/5", "2/5", "2", "3"]


## 解析自定义输入："a/b"（正整数分数）或正数小数/整数；无效返回 -1.0
func parse_fixed_value_text(text: String) -> float:
	var t: String = text.strip_edges()

	if "/" in t:
		var parts: PackedStringArray = t.split("/")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var num: int = parts[0].to_int()
			var den: int = parts[1].to_int()
			if num > 0 and den > 0:
				return float(num) / float(den)
		return -1.0

	if t.is_valid_float():
		var value: float = t.to_float()
		return value if value > 0.0 else -1.0

	return -1.0


## 自定义比值合法范围：0.1 ≤ r ≤ 9（保证答案线可放入区域）
func is_valid_fixed_value(value: float) -> bool:
	return value >= CUSTOM_RATIO_MIN and value <= CUSTOM_RATIO_MAX


func get_fixed_value_custom_placeholder() -> String:
	return "输入自定义长度（如 2/5 或 3）..."


## 固定数值模式会话参数
func build_fixed_value_session_options(fixed_value: float, display_text: String = "") -> Dictionary:
	return {
		"is_fixed_length_mode": true,
		"fixed_ratio": fixed_value,
		"fixed_ratio_text": display_text,
	}


## 普通（等长复刻）模式会话参数
func build_random_session_options() -> Dictionary:
	return { "is_fixed_length_mode": false }
