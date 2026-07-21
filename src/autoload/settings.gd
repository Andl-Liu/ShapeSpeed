extends Node

const DIFFICULTY := {
	0: {
		# Easy
		"angle_tolerance": 2.0,
		"length_tolerance": 0.05,
		"position_toerance": 0.05,
		"angle_range": [5.0, 175.0]
	}
}

static func get_settings(difficulty: int, key: String):
	return DIFFICULTY[difficulty][key]

# 视觉主题 （所有练习共用）
const COLORS := {
	"target":    Color(0.29, 0.56, 0.85, 1.0),   # 蓝
	"user":      Color(0.91, 0.53, 0.23, 1.0),   # 橙
	"auxiliary": Color(0.53, 0.53, 0.53, 1.0),   # 灰
	"correct":   Color(0.27, 0.80, 0.38, 1.0),   # 绿（校验通过）
	"incorrect": Color(0.90, 0.30, 0.30, 1.0),   # 红（校验不通过）
}

const LINE_WIDTH := {
	"main": 3.0,
	"auxiliary": 1.5,
}

# ── 画布布局（所有练习共用） ──
const CANVAS := {
	"default_size":        Vector2(500, 500),
	"default_center":      Vector2(250, 250),
	"default_line_length": 180.0,
	"center_dot_radius":   4.0,
	"angle_arc_radius":    30.0,
	"control_point_radius": 12.0, 
}
