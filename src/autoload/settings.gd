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

# ── 每练习评价档位配置 ──

## 各练习评级默认值（无暇/完美固定，过关档可由用户在设置界面调整）
const RATING_DEFAULTS := {
	"angle_fixed_center": {
		"flawless": 0.3, "perfect": 1.0, "pass": 2.0,
		"unit": "°", "step": 1.0, "min": 1.0, "max": 10.0,
	},
	"angle_fixed_end": {
		"flawless": 0.3, "perfect": 1.0, "pass": 2.0,
		"unit": "°", "step": 1.0, "min": 1.0, "max": 10.0,
	},
	"length": {
		"flawless": 1.0, "perfect": 2.0, "pass": 8.0,
		"unit": "px", "step": 1.0, "min": 1.0, "max": 100.0,
	},
	"free_segment": {
		"flawless": 1.0, "perfect": 3.0, "pass": 10.0,
		"unit": "px", "step": 1.0, "min": 1.0, "max": 100.0,
	},
	"geometry": {
		"flawless": 3.0, "perfect": 5.0, "pass": 15.0,
		"unit": "px", "step": 1.0, "min": 1.0, "max": 100.0,
	},
}

## 用户设置保存位置（user:// 本地，不影响仓库与服务器）
const SETTINGS_FILE := "user://shapespeed_settings.cfg"

## 运行期评级配置：type → { flawless, perfect, pass, unit, step, min, max }
var _rating_settings: Dictionary = {}


func _ready() -> void:
	_load_rating_settings()


## 返回某练习的完整评级配置（含用户调整后的过关值）
func get_rating_config(type: String) -> Dictionary:
	_ensure_loaded()
	return _rating_settings.get(type, {})


## 返回某练习的三档阈值：{ "flawless", "perfect", "pass" }
func get_rating_tiers(type: String) -> Dictionary:
	var config: Dictionary = get_rating_config(type)
	return {
		"flawless": config.get("flawless", 0.0),
		"perfect": config.get("perfect", 0.0),
		"pass": config.get("pass", 0.0),
	}


## 返回某练习的过关阈值
func get_pass_threshold(type: String) -> float:
	return get_rating_tiers(type)["pass"]


## 调整某练习的过关阈值（夹取到该练习范围并立即保存到本地）
func set_pass_threshold(type: String, value: float) -> void:
	_ensure_loaded()
	if not _rating_settings.has(type):
		return
	var config: Dictionary = _rating_settings[type]
	config["pass"] = clampf(value, config["min"], config["max"])
	_save_rating_settings()


## 确保运行期配置已初始化（_ready 未执行时按需加载）
func _ensure_loaded() -> void:
	if _rating_settings.is_empty():
		_load_rating_settings()


## 用默认值初始化运行期配置，再从本地文件载入用户调整
func _load_rating_settings() -> void:
	_rating_settings = {}
	for type in RATING_DEFAULTS:
		_rating_settings[type] = RATING_DEFAULTS[type].duplicate()

	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return

	for type in _rating_settings:
		if cfg.has_section_key("ratings", type):
			var config: Dictionary = _rating_settings[type]
			var loaded: float = cfg.get_value("ratings", type, config["pass"])
			config["pass"] = clampf(loaded, config["min"], config["max"])


## 把用户调整过的过关阈值写入本地文件
func _save_rating_settings() -> void:
	var cfg := ConfigFile.new()
	for type in _rating_settings:
		cfg.set_value("ratings", type, _rating_settings[type]["pass"])
	cfg.save(SETTINGS_FILE)


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
	"control_point_radius": 4.0,
}
