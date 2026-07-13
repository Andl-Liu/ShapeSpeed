class_name MathUtils

# 短距离角度差
static func angle_difference_deg(a: float, b: float):
	var difference = absf(a - b)
	return difference if difference < 180 else 360 - difference