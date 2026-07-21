class_name GeometryUtils

# 给定起点、角度和长度，输出终点
static func line_endpoint(origin:Vector2, angle_deg: float, length: float) -> Vector2:
	var angle_rad = deg_to_rad(angle_deg)
	return origin + Vector2(cos(angle_rad), sin(angle_rad)) * length
	
# 线段的角度（度）
static func line_angle(from:Vector2, to:Vector2) -> float:
	return rad_to_deg(from.angle_to_point(to))

# 线段的长度
static func line_length(from:Vector2, to:Vector2) -> float:
	return from.distance_to(to)

# 返回直线上距离目标点最近的点
# clamp_to_segment决定是否把结果限制在线段上
static func closest_point_on_line(point: Vector2, line_start: Vector2, line_end: Vector2, clamp_to_segement: bool) -> Vector2:
	var d = line_end - line_start
	var d_len_sq = d.length_squared()

	if d_len_sq == 0 :
		return line_start

	var v = point - line_start
	var t = v.dot(d) / d_len_sq

	if clamp_to_segement :
		t = clamp(t, 0.0, 1.0)
	
	return line_start + t * d
