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

	# 评价档位（绝对像素 3/5/10）
	length_exercise._target_length = 100.0
	length_exercise._user_length = 100.0
	var r_flawless: Dictionary = length_exercise.validate()
	assert(r_flawless["rating"] == BaseExercise.Rating.FLAWLESS, "exact answer should be flawless")
	assert(absf(r_flawless["score"] - 100.0) < 0.001, "exact answer should score 100")
	assert(r_flawless["length_error_px"] == 0.0, "exact answer error should be 0")

	length_exercise._user_length = 104.0
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PERFECT, "4px error should be perfect")
	length_exercise._user_length = 108.0
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PASS, "8px error should be pass")
	length_exercise._user_length = 112.0
	assert(length_exercise.validate()["rating"] == BaseExercise.Rating.PRACTICE, "12px error should be practice")

	# 会话参数构造
	var opts: Dictionary = length_exercise.build_fixed_value_session_options(0.4, "2/5")
	assert(opts == {"is_fixed_length_mode": true, "fixed_ratio": 0.4, "fixed_ratio_text": "2/5"},
		"fixed session options mismatch: %s" % opts)
	assert(length_exercise.build_random_session_options() == {"is_fixed_length_mode": false},
		"random session options mismatch")

	print("CHECK_OK")
	quit(0)
