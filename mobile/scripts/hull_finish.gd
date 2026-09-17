extends RefCounted
## Shared painted-metal finish for the 2D fleet. Vertex colours supply smooth
## surface shading, while bevels and a moving specular band suggest raised armor.
## This submits only ordinary canvas geometry: there are no 3D nodes or lights.

static func plate(canvas: Node2D, points: PackedVector2Array, base: Color, energy: Color, clock: float) -> void:
	if points.size() < 3:
		return
	var center := Vector2.ZERO
	var area := 0.0
	for i in range(points.size()):
		center += points[i]
		area += points[i].cross(points[(i + 1) % points.size()])
	center /= float(points.size())
	var extent := 1.0
	for point in points:
		extent = maxf(extent, point.distance_to(center))
	var light := Vector2(-0.6, -0.8).rotated(-canvas.global_rotation)
	var colors := PackedColorArray()
	for point in points:
		var relative := (point - center) / extent
		var facing := relative.dot(light)
		var shade := base.darkened(0.30).lerp(base.lightened(0.42), clampf(0.52 + facing * 0.56, 0.0, 1.0))
		# A broad low-intensity reflection slides across the existing surface. It
		# stays below the energy conduits' brightness and never obscures details.
		var band := exp(-pow((relative.x + relative.y * 0.45 - sin(clock * 0.7) * 0.75) * 2.8, 2.0))
		shade = shade.lerp(Color("d9f2ff"), band * 0.22)
		colors.append(shade)
	var edge := points.duplicate()
	edge.append(points[0])
	# The dark separator preserves the silhouette even over a bright planet.
	canvas.draw_polyline(edge, Color("08121e"), 3.2, true)
	canvas.draw_polygon(points, colors)
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var normal := Vector2((b-a).y, -(b-a).x).normalized() * (1.0 if area > 0.0 else -1.0)
		var facing := normal.dot(light)
		var bevel := Color("43536c") if facing < 0.0 else Color("b9d5ea").lerp(energy.lightened(0.55), 0.2)
		canvas.draw_line(a, b, bevel, 1.25 if facing > 0.0 else 0.9, true)
