extends SceneTree


# ── 工具函数 ──

## 收集绘制数据中的所有点位（线端点、圆心、可控点）
func _collect_points(draw_data: Array) -> Array:
	var points: Array = []
	for item in draw_data:
		match item.get("type", ""):
			"line":
				points.append(item["from"])
				points.append(item["to"])
			"circle", "control_point":
				points.append(item["center"])
	return points


## 断言所有点位均在 [10, 490] 边界框内
func _assert_points_in_bounds(points: Array, tag: String) -> void:
	for p in points:
		assert(p.x >= 10.0 and p.x <= 490.0, "%s out of bounds x: %s" % [tag, p])
		assert(p.y >= 10.0 and p.y <= 490.0, "%s out of bounds y: %s" % [tag, p])


## 多边形相邻边（含首尾闭合边）的最短长度
func _min_edge_length(vertices: Array) -> float:
	var min_len: float = INF
	for i in range(vertices.size()):
		min_len = minf(min_len, vertices[i].distance_to(vertices[(i + 1) % vertices.size()]))
	return min_len


## 对长度练习指定模式跑 N 次生成，校验边界、长度范围与答案约束
func _check_length_generation(exercise, ratio: float, ratio_text: String, iterations: int) -> void:
	exercise.is_fixed_length_mode = true
	exercise.fixed_ratio = ratio
	exercise.fixed_ratio_text = ratio_text
	for i in range(iterations):
		exercise.generate(0)
		assert(exercise._original_length >= 50.0 and exercise._original_length <= 300.0,
			"original length out of range: %s" % exercise._original_length)
		assert(absf(exercise._target_length - exercise._original_length * ratio) < 0.001,
			"target length mismatch: %s vs %s" % [exercise._target_length, exercise._original_length * ratio])
		# 等分模式：答案线最短 30px
		if ratio < 1.0:
			assert(exercise._target_length >= 30.0, "division answer too short: %s" % exercise._target_length)
		_assert_points_in_bounds(_collect_points(exercise.get_target_draw_date()), "length target")
		_assert_points_in_bounds(_collect_points(exercise.get_copy_draw_date()), "length copy")
		_assert_points_in_bounds(_collect_points(exercise.get_answer_draw_date()), "length answer")


func _init() -> void:
	# ══ 角度练习（一端固定）══
	const AngleScript := preload("res://src/exercises/angle_fixed_end_exercise.gd")
	var angle_exercise: BaseExercise = AngleScript.new()
	assert(angle_exercise != null, "new() returned null")
	assert(angle_exercise.get_rotation_center() == angle_exercise.fixed_end, "rotation center mismatch")

	for i in range(200):
		angle_exercise.generate(0)
		_assert_points_in_bounds(_collect_points(angle_exercise.get_target_draw_date()), "angle target")

	angle_exercise.is_fixed_angle_mode = true
	angle_exercise.fixed_angle_value_deg = 45.0
	for i in range(200):
		angle_exercise.generate(0)
		_assert_points_in_bounds(_collect_points(angle_exercise.get_target_draw_date()), "angle fixed target")

	var angle_result: Dictionary = angle_exercise.validate()
	assert(angle_result.has("score") and angle_result.has("rating"), "validate result incomplete")

	# ══ 长度练习 ══
	const LengthScript := preload("res://src/exercises/length_exercise.gd")
	var length_exercise = LengthScript.new()
	assert(length_exercise != null, "length new() returned null")

	# 普通模式（等长复刻）：随机生成 200 次
	for i in range(200):
		length_exercise.is_fixed_length_mode = false
		length_exercise.generate(0)
		assert(length_exercise._original_length >= 50.0 and length_exercise._original_length <= 300.0,
			"equal-mode length out of range: %s" % length_exercise._original_length)
		assert(absf(length_exercise._target_length - length_exercise._original_length) < 0.001, "equal ratio mismatch")
		assert(length_exercise._user_length == 0.0, "equal mode should start at anchor")
		_assert_points_in_bounds(_collect_points(length_exercise.get_target_draw_date()), "length equal target")
		_assert_points_in_bounds(_collect_points(length_exercise.get_copy_draw_date()), "length equal copy")
		_assert_points_in_bounds(_collect_points(length_exercise.get_answer_draw_date()), "length equal answer")

	# 等分与延长模式：各跑 200 次
	_check_length_generation(length_exercise, 0.2, "1/5", 200)
	_check_length_generation(length_exercise, 0.4, "2/5", 200)
	_check_length_generation(length_exercise, 2.0, "2", 200)
	_check_length_generation(length_exercise, 3.0, "3", 200)

	# 提示文本
	length_exercise.is_fixed_length_mode = true
	length_exercise.fixed_ratio = 3.0
	length_exercise.fixed_ratio_text = "3"
	assert(length_exercise.get_hint_text() == "3倍", "extend hint mismatch: %s" % length_exercise.get_hint_text())
	length_exercise.fixed_ratio = 0.4
	length_exercise.fixed_ratio_text = "2/5"
	assert(length_exercise.get_hint_text() == "2/5", "division hint mismatch: %s" % length_exercise.get_hint_text())

	# 自定义输入解析
	assert(absf(length_exercise.parse_fixed_value_text("2/5") - 0.4) < 0.0001, "parse 2/5 failed")
	assert(absf(length_exercise.parse_fixed_value_text("3") - 3.0) < 0.0001, "parse 3 failed")
	assert(absf(length_exercise.parse_fixed_value_text("0.4") - 0.4) < 0.0001, "parse 0.4 failed")
	assert(length_exercise.parse_fixed_value_text("1/0") < 0.0, "parse 1/0 should fail")
	assert(length_exercise.parse_fixed_value_text("abc") < 0.0, "parse abc should fail")
	assert(length_exercise.parse_fixed_value_text("-2") < 0.0, "parse -2 should fail")
	assert(length_exercise.is_valid_fixed_value(0.4), "0.4 should be valid")
	assert(length_exercise.is_valid_fixed_value(9.0), "9 should be valid")
	assert(not length_exercise.is_valid_fixed_value(0.05), "0.05 should be invalid")
	assert(not length_exercise.is_valid_fixed_value(10.0), "10 should be invalid")

	# 交互约束：可控点只能沿方向线移动、负方向夹取、不越界
	length_exercise.is_fixed_length_mode = false
	length_exercise._anchor = Vector2(100, 100)
	length_exercise._line_angle_deg = 0.0
	length_exercise._original_length = 100.0
	length_exercise._target_length = 100.0
	length_exercise._user_length = 0.0
	length_exercise.is_generated = true

	var projected: Vector2 = length_exercise.on_point_dragged(0, Vector2(150, 130))
	assert(projected == Vector2(150, 100), "drag should project onto line: %s" % projected)
	assert(absf(length_exercise._user_length - 50.0) < 0.001, "user length should be 50")

	length_exercise.on_point_dragged(0, Vector2(80, 100))
	assert(length_exercise._user_length == 0.0, "negative drag should clamp to 0")

	length_exercise.on_point_dragged(0, Vector2(600, 100))
	assert(length_exercise._user_length <= 390.0 + 0.001, "drag should be clamped to margin box")

	# 评价档位（按 Settings 配置的默认阈值）
	length_exercise._target_length = 100.0
	length_exercise._user_length = 100.0
	var r_flawless: Dictionary = length_exercise.validate()
	assert(r_flawless["rating"] == BaseExercise.Rating.FLAWLESS, "exact answer should be flawless")
	assert(absf(r_flawless["score"] - 100.0) < 0.001, "exact answer should score 100")
	assert(r_flawless["length_error_px"] == 0.0, "exact answer error should be 0")

	var len_tiers: Dictionary = Settings.get_rating_tiers("length")
	length_exercise._user_length = 100.0 + len_tiers["perfect"]
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PERFECT, "perfect-tier error should be perfect")
	length_exercise._user_length = 100.0 + len_tiers["pass"]
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PASS, "pass-tier error should be pass")
	length_exercise._user_length = 100.0 + len_tiers["pass"] + 1.0
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PRACTICE, "beyond pass should be practice")

	# 会话参数构造
	var opts: Dictionary = length_exercise.build_fixed_value_session_options(0.4, "2/5")
	assert(opts == {"is_fixed_length_mode": true, "fixed_ratio": 0.4, "fixed_ratio_text": "2/5"},
		"fixed session options mismatch: %s" % opts)
	assert(length_exercise.build_random_session_options() == {"is_fixed_length_mode": false},
		"random session options mismatch")

	# 方向模式：竖直 → dx≈0；水平 → dy≈0；大倍数延长触发回退时仍保持模式方向
	assert(length_exercise.has_gear_button(), "length should show gear button")
	length_exercise.is_fixed_length_mode = false
	length_exercise.direction_mode = 1
	for i in range(100):
		length_exercise.generate(0)
		var v_line: Dictionary = length_exercise.get_target_draw_date()[0]
		assert(absf(v_line["from"].x - v_line["to"].x) < 0.001, "vertical mode should have dx≈0")

	length_exercise.direction_mode = 2
	for i in range(100):
		length_exercise.generate(0)
		var h_line: Dictionary = length_exercise.get_target_draw_date()[0]
		assert(absf(h_line["from"].y - h_line["to"].y) < 0.001, "horizontal mode should have dy≈0")

	length_exercise.is_fixed_length_mode = true
	length_exercise.fixed_ratio = 9.0
	length_exercise.direction_mode = 1
	for i in range(50):
		length_exercise.generate(0)
		var vf_line: Dictionary = length_exercise.get_target_draw_date()[0]
		assert(absf(vf_line["from"].x - vf_line["to"].x) < 0.001, "vertical fixed mode should stay vertical")

	length_exercise.is_fixed_length_mode = false
	length_exercise.direction_mode = 0

	# ══ 自由线段练习 ══
	const FreeSegmentScript := preload("res://src/exercises/free_segment_exercise.gd")
	var free_exercise = FreeSegmentScript.new()
	assert(free_exercise != null, "free segment new() returned null")
	assert(not free_exercise.has_fixed_value_mode(), "free segment should have no fixed value mode")

	# 生成 200 次：目标/初始线段均满足边界与长度约束
	for i in range(200):
		free_exercise.generate(0)
		var target_len: float = free_exercise._target_a.distance_to(free_exercise._target_b)
		assert(target_len >= 50.0 and target_len <= 300.0,
			"free target length out of range: %s" % target_len)
		_assert_points_in_bounds(_collect_points(free_exercise.get_target_draw_date()), "free target")
		_assert_points_in_bounds(_collect_points(free_exercise.get_copy_draw_date()), "free copy")
		_assert_points_in_bounds(_collect_points(free_exercise.get_answer_draw_date()), "free answer")

	# 精确复刻 → 无暇、满分
	free_exercise._target_a = Vector2(100, 100)
	free_exercise._target_b = Vector2(300, 100)
	free_exercise._user_a = Vector2(100, 200)
	free_exercise._user_b = Vector2(300, 200)
	free_exercise.is_generated = true

	var dragged_a: Vector2 = free_exercise.on_point_dragged(0, Vector2(100, 100))
	assert(dragged_a == Vector2(100, 100), "drag point 0 failed: %s" % dragged_a)
	free_exercise.on_point_dragged(1, Vector2(300, 100))

	var r_exact: Dictionary = free_exercise.validate()
	assert(r_exact["rating"] == BaseExercise.Rating.FLAWLESS, "exact copy should be flawless")
	assert(absf(r_exact["score"] - 100.0) < 0.001, "exact copy should score 100")
	assert(r_exact["average_error_px"] == 0.0, "exact copy error should be 0")

	# 交换两个端点顺序也应无暇（最小匹配）
	free_exercise._user_a = Vector2(300, 100)
	free_exercise._user_b = Vector2(100, 100)
	var r_swap: Dictionary = free_exercise.validate()
	assert(r_swap["rating"] == BaseExercise.Rating.FLAWLESS, "swapped copy should be flawless")

	# 单端点偏移 → 平均偏差 = 偏移/2，按 Settings 阈值判定
	var fs_tiers: Dictionary = Settings.get_rating_tiers("free_segment")
	free_exercise._user_a = Vector2(300 + 2.0 * fs_tiers["perfect"], 100)
	free_exercise._user_b = Vector2(100, 100)
	var r_perfect: Dictionary = free_exercise.validate()
	assert(r_perfect["rating"] == BaseExercise.Rating.PERFECT, "perfect-tier avg should be perfect")
	assert(absf(r_perfect["average_error_px"] - fs_tiers["perfect"]) < 0.001, "avg error mismatch")

	free_exercise._user_a = Vector2(300 + 2.0 * fs_tiers["pass"], 100)
	assert(free_exercise.validate()["rating"] == BaseExercise.Rating.PASS, "pass-tier avg should be pass")

	free_exercise._user_a = Vector2(300 + 2.0 * fs_tiers["pass"] + 2.0, 100)
	assert(free_exercise.validate()["rating"] == BaseExercise.Rating.PRACTICE, "beyond pass should be practice")

	# 越界拖拽被夹取到边界框内
	var clamped: Vector2 = free_exercise.on_point_dragged(0, Vector2(600, 100))
	assert(clamped == Vector2(490, 100), "drag should clamp to margin box: %s" % clamped)

	# ══ 几何练习 ══
	const GeometryScript := preload("res://src/exercises/geometry_exercise.gd")
	var geometry_exercise = GeometryScript.new()
	assert(geometry_exercise != null, "geometry new() returned null")
	assert(geometry_exercise.has_fixed_value_mode(), "geometry should have fixed value mode")
	assert(not geometry_exercise.has_custom_fixed_value(), "geometry should have no custom value")

	# 随机模式 200 次：顶点数 3~5、边界、最短边
	for i in range(200):
		geometry_exercise.is_fixed_vertex_mode = false
		geometry_exercise.generate(0)
		var count: int = geometry_exercise._target_vertices.size()
		assert(count >= 3 and count <= 5, "vertex count out of range: %s" % count)
		assert(geometry_exercise._user_vertices.size() == count, "user vertex count mismatch")
		_assert_points_in_bounds(_collect_points(geometry_exercise.get_target_draw_date()), "geo target")
		_assert_points_in_bounds(_collect_points(geometry_exercise.get_copy_draw_date()), "geo copy")
		_assert_points_in_bounds(_collect_points(geometry_exercise.get_answer_draw_date()), "geo answer")
		assert(_min_edge_length(geometry_exercise._target_vertices) >= 25.0, "target min edge too short")
		assert(_min_edge_length(geometry_exercise._user_vertices) >= 25.0, "user min edge too short")

	# 固定模式 3/4/5：各 200 次，顶点数匹配
	for vc in [3, 4, 5]:
		geometry_exercise.is_fixed_vertex_mode = true
		geometry_exercise.fixed_vertex_count = vc
		for i in range(200):
			geometry_exercise.generate(0)
			assert(geometry_exercise._target_vertices.size() == vc, "fixed vertex count mismatch")
			assert(geometry_exercise._user_vertices.size() == vc, "fixed user vertex count mismatch")
			_assert_points_in_bounds(_collect_points(geometry_exercise.get_target_draw_date()), "geo fixed target")
			_assert_points_in_bounds(_collect_points(geometry_exercise.get_copy_draw_date()), "geo fixed copy")

	# 评价用例（三角形）
	geometry_exercise.is_fixed_vertex_mode = true
	geometry_exercise.fixed_vertex_count = 3
	geometry_exercise._target_vertices = [Vector2(100, 100), Vector2(300, 100), Vector2(200, 300)]
	geometry_exercise._user_vertices = [Vector2(100, 100), Vector2(300, 100), Vector2(200, 300)]
	geometry_exercise.is_generated = true

	var g_exact: Dictionary = geometry_exercise.validate()
	assert(g_exact["rating"] == BaseExercise.Rating.FLAWLESS, "exact polygon should be flawless")
	assert(absf(g_exact["score"] - 100.0) < 0.001, "exact polygon should score 100")
	assert(g_exact["average_error_px"] == 0.0, "exact polygon error should be 0")

	# 顶点顺序打乱（旋转映射）→ 仍无暇
	geometry_exercise._user_vertices = [Vector2(200, 300), Vector2(100, 100), Vector2(300, 100)]
	assert(geometry_exercise.validate()["rating"] == BaseExercise.Rating.FLAWLESS, "rotated order should be flawless")

	# 单顶点偏移 → 平均偏差 = 偏移/3，按 Settings 阈值判定
	var geo_tiers: Dictionary = Settings.get_rating_tiers("geometry")
	geometry_exercise._user_vertices = [
		Vector2(100 + 3.0 * geo_tiers["perfect"], 100), Vector2(300, 100), Vector2(200, 300)
	]
	var g_perfect: Dictionary = geometry_exercise.validate()
	assert(g_perfect["rating"] == BaseExercise.Rating.PERFECT, "perfect-tier avg should be perfect")
	assert(absf(g_perfect["average_error_px"] - geo_tiers["perfect"]) < 0.001, "avg error mismatch")

	geometry_exercise._user_vertices = [
		Vector2(100 + 3.0 * geo_tiers["pass"], 100), Vector2(300, 100), Vector2(200, 300)
	]
	assert(geometry_exercise.validate()["rating"] == BaseExercise.Rating.PASS, "pass-tier avg should be pass")

	geometry_exercise._user_vertices = [
		Vector2(100 + 3.0 * geo_tiers["pass"] + 3.0, 100), Vector2(300, 100), Vector2(200, 300)
	]
	assert(geometry_exercise.validate()["rating"] == BaseExercise.Rating.PRACTICE, "beyond pass should be practice")

	# 越界拖拽被夹取到边界框内
	var g_clamped: Vector2 = geometry_exercise.on_point_dragged(0, Vector2(600, 100))
	assert(g_clamped == Vector2(490, 100), "geometry drag should clamp: %s" % g_clamped)

	# 固定数值 API
	assert(absf(geometry_exercise.parse_fixed_value_text("三角形") - 3.0) < 0.0001, "parse 三角形 failed")
	assert(absf(geometry_exercise.parse_fixed_value_text("四边形") - 4.0) < 0.0001, "parse 四边形 failed")
	assert(absf(geometry_exercise.parse_fixed_value_text("五边形") - 5.0) < 0.0001, "parse 五边形 failed")
	assert(geometry_exercise.parse_fixed_value_text("六边形") < 0.0, "parse 六边形 should fail")
	assert(geometry_exercise.is_valid_fixed_value(3.0), "3 should be valid")
	assert(geometry_exercise.is_valid_fixed_value(5.0), "5 should be valid")
	assert(not geometry_exercise.is_valid_fixed_value(6.0), "6 should be invalid")
	assert(geometry_exercise.get_fixed_value_display_options() == ["三角形", "四边形", "五边形"],
		"geometry display options mismatch")
	assert(geometry_exercise.build_fixed_value_session_options(3.0, "三角形") == {
		"is_fixed_vertex_mode": true, "fixed_vertex_count": 3, "fixed_vertex_text": "三角形"
	}, "geometry fixed session mismatch")
	assert(geometry_exercise.build_random_session_options() == {"is_fixed_vertex_mode": false},
		"geometry random session mismatch")
	geometry_exercise.is_fixed_vertex_mode = true
	geometry_exercise.fixed_vertex_text = "三角形"
	assert(geometry_exercise.get_hint_text() == "三角形", "geometry hint mismatch")

	# ══ 设置 API：过关阈值可调整、夹取、恢复 ══
	var saved_pass: Dictionary = {}
	for t in ["angle_fixed_center", "angle_fixed_end", "length", "free_segment", "geometry"]:
		saved_pass[t] = Settings.get_pass_threshold(t)

	Settings.set_pass_threshold("length", 12.0)
	assert(Settings.get_pass_threshold("length") == 12.0, "pass threshold should update")
	length_exercise._target_length = 100.0
	length_exercise._user_length = 110.0  # 10 > 默认 8，但 ≤ 新阈值 12
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PASS, "custom pass should apply")
	length_exercise._user_length = 113.0  # > 新阈值 12
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PRACTICE, "beyond custom pass should be practice")

	Settings.set_pass_threshold("length", 999.0)
	assert(Settings.get_pass_threshold("length") == 100.0, "pass should clamp to max")
	Settings.set_pass_threshold("length", 0.0)
	assert(Settings.get_pass_threshold("length") == 1.0, "pass should clamp to min")

	for t in saved_pass:
		Settings.set_pass_threshold(t, saved_pass[t])

	print("CHECK_OK")
	quit(0)
