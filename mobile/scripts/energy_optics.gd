extends RefCounted
## Geometry shared by light weapons and fast projectiles. All paths are finite;
## no per-pixel ray marching or recursion is needed for large overlapping fields.

const MAX_ROUTE_POINTS := 384

## First physical core crossing along a segment, including an origin inside it.
static func first_core(from: Vector2, to: Vector2, wells: Array) -> Dictionary:
	var travel := to-from
	var length := travel.length()
	if length < 0.00001: return {}
	var direction := travel/length
	var nearest := length+1.0
	var found: Dictionary = {}
	for well in wells:
		var radius: float = 31.0*well.well_scale
		var offset: Vector2 = from-well.well_position
		var projection := offset.dot(direction)
		var discriminant := projection*projection-offset.length_squared()+radius*radius
		if discriminant < 0.0: continue
		var exit := -projection+sqrt(discriminant)
		if exit < 0.0: continue
		var entry := maxf(0.0,-projection-sqrt(discriminant))
		if entry <= length and entry < nearest:
			nearest=entry
			found={"well":well,"at":from+direction*entry,"distance":entry}
	return found

## Tangent -> circular arc -> tangent. The generous optical margin keeps every
## chord, the animated beam width and its halo outside the opaque event horizon.
static func bypass(from: Vector2, to: Vector2, well: Node2D, side: float) -> Array[Vector2]:
	var center: Vector2 = well.well_position
	var radius: float = 31.0*well.well_scale+14.0
	var a := from-center
	var b := to-center
	var result: Array[Vector2] = []
	var start := from
	var finish := to
	if a.length() < radius:
		start=center+a.normalized()*radius
		result.append_array([from,start])
	if b.length() < radius: finish=center+b.normalized()*radius
	var start_angle := (start-center).angle()+side*acos(clampf(radius/maxf(radius,start.distance_to(center)),0,1))
	var end_angle := (finish-center).angle()-side*acos(clampf(radius/maxf(radius,finish.distance_to(center)),0,1))
	var sweep := fposmod((end_angle-start_angle)*side,TAU)*side
	var previous := center+Vector2.from_angle(start_angle)*radius
	result.append_array([start,previous])
	var count := maxi(2,ceili(absf(sweep)*radius/15.0))
	count=mini(count,96)
	for i in range(1,count+1):
		var point := center+Vector2.from_angle(start_angle+sweep*float(i)/count)*radius
		result.append_array([previous,point])
		previous=point
	result.append_array([previous,finish])
	if finish != to: result.append_array([finish,to])
	return result

## Route one electric link around intersecting cores. If the destination itself
## is swallowed the link terminates at that horizon and cannot claim a hit.
static func route(from: Vector2, to: Vector2, wells: Array, side: float = 1.0) -> Array[Vector2]:
	var route: Array[Vector2]=[from,to]
	for pass_index in range(4):
		var rebuilt: Array[Vector2]=[]
		var changed := false
		for i in range(0,route.size()-1,2):
			# Enforce the bound before appending, not after a potentially explosive
			# rebuild around overlapping cores. Pairs stay intact when truncated.
			if rebuilt.size() >= MAX_ROUTE_POINTS: break
			var hit := first_core(route[i],route[i+1],wells)
			if hit.is_empty():
				rebuilt.append_array([route[i],route[i+1]])
				continue
			var well: Node2D=hit.well
			var radius: float=31.0*well.well_scale
			if route[i].distance_to(well.well_position) < radius or route[i+1].distance_to(well.well_position) < radius:
				rebuilt.append_array([route[i],hit.at])
				break
			var detour := bypass(route[i],route[i+1],well,side)
			var available := MAX_ROUTE_POINTS-rebuilt.size()
			rebuilt.append_array(detour.slice(0,available))
			changed=true
			if detour.size() > available: break
		route=rebuilt
		if not changed: break
	# Overlapping horizons may obstruct a previously routed arc. Absorb there
	# instead of risking a path through the opaque interior or unbounded work.
	var safe: Array[Vector2]=[]
	for i in range(0,route.size()-1,2):
		var hit := first_core(route[i],route[i+1],wells)
		if not hit.is_empty():
			safe.append_array([route[i],hit.at])
			break
		safe.append_array([route[i],route[i+1]])
	return safe
