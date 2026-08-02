extends SceneTree


func _init() -> void:
	const ExerciseScript := preload("res://src/exercises/angle_fixed_end_exercise.gd")
	var exercise: BaseExercise = ExerciseScript.new()
	assert(exercise != null, "new() returned null")
	assert(exercise.get_rotation_center() == exercise.fixed_end, "rotation center mismatch")

	# 多次生成，验证原图区目标线与辅助线始终满足边界约束
	for i in range(200):
		exercise.generate(0)
		var target_data: Array = exercise.get_target_draw_date()
		var points: Array = []
		for item in target_data:
			if item["type"] == "line":
				points.append(item["from"])
				points.append(item["to"])
			elif item["type"] == "circle":
				points.append(item["center"])
		for p in points:
			assert(p.x >= 10.0 and p.x <= 490.0, "out of bounds x: %s" % p)
			assert(p.y >= 10.0 and p.y <= 490.0, "out of bounds y: %s" % p)

	# 固定角度模式同样验证
	exercise.is_fixed_angle_mode = true
	exercise.fixed_angle_value_deg = 45.0
	for i in range(200):
		exercise.generate(0)
		var target_data: Array = exercise.get_target_draw_date()
		for item in target_data:
			if item["type"] == "line":
				for p in [item["from"], item["to"]]:
					assert(p.x >= 10.0 and p.x <= 490.0, "fixed-mode out of bounds x: %s" % p)
					assert(p.y >= 10.0 and p.y <= 490.0, "fixed-mode out of bounds y: %s" % p)
			elif item["type"] == "circle":
				assert(item["center"].x >= 10.0 and item["center"].x <= 490.0, "dot out of bounds")
				assert(item["center"].y >= 10.0 and item["center"].y <= 490.0, "dot out of bounds")

	# validate 流程
	var result: Dictionary = exercise.validate()
	assert(result.has("score") and result.has("rating"), "validate result incomplete")

	print("CHECK_OK")
	quit(0)
