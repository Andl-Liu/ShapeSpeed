class_name MathUtils


## 两条无向线段之间的最短角度差（绝对值，0–90）。
## 线段没有方向性——角度 θ 和 θ+180° 是同一条线，
## 因此用 180° 取模，差值上限为 90°（垂直）。
static func angle_difference_deg(a: float, b: float) -> float:
	var a_mod: float = fmod(a, 180.0)
	if a_mod < 0.0: a_mod += 180.0
	var b_mod: float = fmod(b, 180.0)
	if b_mod < 0.0: b_mod += 180.0
	var diff: float = absf(a_mod - b_mod)
	if diff > 90.0:
		diff = 180.0 - diff
	return diff


## 将角度规范到 [0, 360) 范围
static func normalize_angle_deg(angle: float) -> float:
	var result: float = fmod(angle, 360.0)
	if result < 0.0:
		result += 360.0
	return result
