extends BaseExercise


# ── 常量 ──

## 顶点距区域边缘的最小距离（逻辑像素）
const EDGE_MARGIN := 10.0

## 多边形最小边长（逻辑像素）
const MIN_EDGE_LENGTH := 25.0

## 顶点最小/最大半径（相对多边形中心，逻辑像素）
const MIN_VERTEX_RADIUS := 40.0
const MAX_VERTEX_RADIUS := 180.0

## 外接半径范围（保证中心采样区间非空：R ≤ 240）
const OUTER_RADIUS_MIN := 70.0
const OUTER_RADIUS_MAX := MAX_VERTEX_RADIUS

## 评价档位（顶点匹配后的平均绝对偏差，逻辑像素）
const FLAWLESS_ERROR_PX := 3.0
const PERFECT_ERROR_PX := 5.0
const PASS_ERROR_PX := 15.0


# ── 公开属性（由 ExerciseFactory 在 generate() 之前设置）──

## 是否启用固定顶点数模式
@export var is_fixed_vertex_mode: bool = false

## 固定顶点数（3/4/5）
@export var fixed_vertex_count: int = 3

## 固定模式下用户选择的显示文本（如 "三角形"，用于提示）
@export var fixed_vertex_text: String = ""

## 颜色相关
@export var color_target  := Settings.COLORS.target
@export var color_user    := Settings.COLORS.user
@export var color_correct := Settings.COLORS.correct

## 线宽相关
@export var line_width_main := Settings.LINE_WIDTH.main


# ── 内部状态 ──

var _target_vertices: Array = []
var _user_vertices: Array = []


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


## 多边形相邻边（含首尾闭合边）的最短长度
func _min_edge_length(vertices: Array) -> float:
	var min_len: float = INF
	for i in range(vertices.size()):
		min_len = minf(min_len, vertices[i].distance_to(vertices[(i + 1) % vertices.size()]))
	return min_len


## 随机生成一个不规则凸多边形：中心 + 排序角度 + 随机半径。
## 所有顶点必然落在距边缘 ≥ EDGE_MARGIN 的框内；最短边不达标时重试。
func _generate_convex_polygon(count: int) -> Array:
	var vertices: Array = []
	var size: Vector2 = Settings.CANVAS.default_size
	var min_pos: float = EDGE_MARGIN
	var max_pos: float = size.x - EDGE_MARGIN

	for attempt in range(64):
		var outer_radius: float = randf_range(OUTER_RADIUS_MIN, OUTER_RADIUS_MAX)
		var center: Vector2 = Vector2(
			randf_range(min_pos + outer_radius, max_pos - outer_radius),
			randf_range(min_pos + outer_radius, max_pos - outer_radius)
		)

		var angles: Array = []
		for i in range(count):
			angles.append(randf_range(0.0, TAU))
		angles.sort()

		vertices = []
		for i in range(count):
			var radius: float = randf_range(MIN_VERTEX_RADIUS, outer_radius)
			var a: float = angles[i]
			vertices.append(center + Vector2(cos(a), sin(a)) * radius)

		if _min_edge_length(vertices) >= MIN_EDGE_LENGTH:
			return vertices

	return vertices


## 顶点全排列搜索：用户顶点与目标顶点的最小总匹配距离。
## 返回 { "total": float, "errors": Array }；errors 按目标顶点顺序排列。
func _search_min_match(depth: int, total: float, errors: Array, used: Array) -> Dictionary:
	var n: int = _target_vertices.size()
	if depth == n:
		return { "total": total, "errors": errors.duplicate() }

	var best: Dictionary = { "total": INF, "errors": [] }
	for i in range(n):
		if used[i]:
			continue
		used[i] = true
		var d: float = _user_vertices[i].distance_to(_target_vertices[depth])
		errors.append(d)
		var candidate: Dictionary = _search_min_match(depth + 1, total + d, errors, used)
		errors.pop_back()
		used[i] = false
		if candidate["total"] < best["total"]:
			best = candidate
	return best


## 对两个顶点集合做最小匹配（允许任意顺序对应），返回总距离与逐点偏差
func _match_user_to_target() -> Dictionary:
	var n: int = _target_vertices.size()
	var used: Array = []
	for i in range(n):
		used.append(false)
	return _search_min_match(0, 0.0, [], used)


## 根据平均绝对偏差返回评价等级
func _compute_rating(error_px: float) -> BaseExercise.Rating:
	if error_px <= FLAWLESS_ERROR_PX:
		return BaseExercise.Rating.FLAWLESS
	if error_px <= PERFECT_ERROR_PX:
		return BaseExercise.Rating.PERFECT
	if error_px <= PASS_ERROR_PX:
		return BaseExercise.Rating.PASS
	return BaseExercise.Rating.PRACTICE


## 顶点数 → 显示名称
func _vertex_count_name(count: int) -> String:
	match count:
		3: return "三角形"
		4: return "四边形"
		_: return "五边形"


## 生成多边形轮廓线段数据（首尾闭合）
func _polygon_outline_data(vertices: Array, color: Color) -> Array:
	var data: Array = []
	for i in range(vertices.size()):
		data.append({
			"type": "line",
			"from": vertices[i],
			"to": vertices[(i + 1) % vertices.size()],
			"color": color,
			"width": line_width_main,
		})
	return data


## 生成结束后的边界校验
func _validate_bounds() -> bool:
	for v in _target_vertices:
		if not _is_in_bounds(v):
			return false
	for v in _user_vertices:
		if not _is_in_bounds(v):
			return false
	return true


# ── BaseExercise 核心方法实现 ──

func generate(_difficulty: int) -> void:
	difficulty = _difficulty

	var count: int = fixed_vertex_count if is_fixed_vertex_mode else (3 + randi() % 3)
	_target_vertices = _generate_convex_polygon(count)
	_user_vertices = _generate_convex_polygon(count)

	assert(_validate_bounds(), "Generated geometry exceeds edge margin!")

	is_generated = true
	geometry_changed.emit()


func validate() -> Dictionary:
	assert(is_generated, "validate() called before generate()")

	var match_info: Dictionary = _match_user_to_target()
	var avg_error: float = match_info["total"] / float(_target_vertices.size())
	var rating: BaseExercise.Rating = _compute_rating(avg_error)
	# 与"过关"档（10px）对齐的评分容差
	var accuracy: float = clampf(1.0 - avg_error / PASS_ERROR_PX, 0.0, 1.0)

	var result := {
		"score": accuracy * 100.0,
		"accuracy": accuracy,
		"average_error_px": avg_error,
		"vertex_errors_px": match_info["errors"],
		"rating": rating,
		"vertex_count": _target_vertices.size(),
		"target_vertices": _target_vertices,
		"user_vertices": _user_vertices,
	}

	exercise_completed.emit(result)
	return result


func get_target_draw_date() -> Array:
	var data: Array = _polygon_outline_data(_target_vertices, color_target)
	for v in _target_vertices:
		data.append({
			"type": "circle",
			"center": v,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_target,
		})
	return data


func get_copy_draw_date() -> Array:
	var data: Array = _polygon_outline_data(_user_vertices, color_user)
	for v in _user_vertices:
		data.append({
			"type": "control_point",
			"center": v,
			"radius": Settings.CANVAS.control_point_radius,
			"color": color_user,
		})
	return data


## 提交后叠加在临摹区的正确答案：绿色多边形轮廓 + 顶点标记
func get_answer_draw_date() -> Array:
	var data: Array = _polygon_outline_data(_target_vertices, color_correct)
	for v in _target_vertices:
		data.append({
			"type": "circle",
			"center": v,
			"radius": Settings.CANVAS.center_dot_radius,
			"color": color_correct,
		})
	return data


func get_hint_text() -> String:
	if not is_fixed_vertex_mode:
		return ""
	if not fixed_vertex_text.is_empty():
		return fixed_vertex_text
	return _vertex_count_name(fixed_vertex_count)


# ── 可选覆写 ──

func get_interaction_mode() -> BaseExercise.InteractionMode:
	return BaseExercise.InteractionMode.FREE_MOVE


## 每个顶点均可自由拖动；位置夹取到边界框内
func on_point_dragged(point_id: int, proposed_position: Vector2) -> Vector2:
	var clamped: Vector2 = _clamp_to_bounds(proposed_position)
	if point_id >= 0 and point_id < _user_vertices.size():
		_user_vertices[point_id] = clamped
	geometry_changed.emit()
	return clamped


## 提交后偏差提示
func get_error_display_text(result: Dictionary) -> String:
	return "偏差 %.1fpx" % result.get("average_error_px", 0.0)


# ── 固定数值模式 ──

func has_fixed_value_mode() -> bool:
	return true


## 固定顶点数只有三项，不提供自定义输入
func has_custom_fixed_value() -> bool:
	return false


func get_fixed_value_options() -> Array:
	return [3.0, 4.0, 5.0]


func get_fixed_value_display_options() -> Array:
	return ["三角形", "四边形", "五边形"]


## 解析下拉文本 → 顶点数；无效返回 -1.0
func parse_fixed_value_text(text: String) -> float:
	var t: String = text.strip_edges()
	match t:
		"三角形": return 3.0
		"四边形": return 4.0
		"五边形": return 5.0
	return -1.0


## 合法顶点数：3/4/5
func is_valid_fixed_value(value: float) -> bool:
	var count: int = roundi(value)
	return count >= 3 and count <= 5


## 固定顶点数模式会话参数
func build_fixed_value_session_options(fixed_value: float, display_text: String = "") -> Dictionary:
	return {
		"is_fixed_vertex_mode": true,
		"fixed_vertex_count": roundi(fixed_value),
		"fixed_vertex_text": display_text,
	}


## 随机模式会话参数
func build_random_session_options() -> Dictionary:
	return { "is_fixed_vertex_mode": false }
