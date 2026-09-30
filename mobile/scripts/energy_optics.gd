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
		var radius: float = core_radius(well)
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
	var radius: float = core_radius(well)+14.0
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

## Route electric links around white cores only. A black horizon always
## absorbs the stream; a target on its far side cannot claim a through-core hit.
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
			var radius: float=core_radius(well)
			if well.kind == "black" or route[i].distance_to(well.well_position) < radius or route[i+1].distance_to(well.well_position) < radius:
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

## During droplet coalescence the visible lobe and collision radius grow
## together; original well_scale still records mass for the eventual union.
static func core_radius(well: Node2D) -> float:
	return well.game.gravity_fields.core_radius(well)

## Projectile fields capture matter permanently until that field ends. The ID,
## rather than a Node reference, remains safe if two fields merge mid-flight.
static func capture_well(at: Vector2, wells: Array, capture_id: int) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for well in wells:
		if well.kind != "black": continue
		if well.get_instance_id() == capture_id: return well
		var distance: float = at.distance_to(well.well_position)
		if distance <= maxf(460.0,core_radius(well)+180.0) and distance < nearest_distance:
			nearest=well
			nearest_distance=distance
	return nearest

## Keep white-hole paths on a smooth exterior arc. Steering normally starts far
## outside this guard; it also handles a newly spawned core and a long frame.
## The visual-width margin keeps the entire plasma tip outside the white center.
static func white_safe_step(from: Vector2, proposed: Vector2, velocity: Vector2, wells: Array, margin: float = 12.0) -> Dictionary:
	var point := proposed
	var speed := velocity.length()
	for well in wells:
		if well.kind != "white": continue
		var radius := core_radius(well)+margin
		var closest := Geometry2D.get_closest_point_to_segment(well.well_position,from,point)
		if closest.distance_to(well.well_position) >= radius: continue
		var radial: Vector2=from-well.well_position
		var distance := radial.length()
		if distance < 0.001: radial=-velocity.normalized()
		else: radial/=distance
		if radial == Vector2.ZERO: radial=Vector2.DOWN
		var side := 1.0 if velocity.cross(radial)>=0.0 else -1.0
		# Arc chords are shorter than the arc itself. Two extra pixels keep the
		# bounded eight-pixel chord outside the exclusion radius as well.
		var orbit_radius := maxf(distance,radius+2.0)
		var travel := from.distance_to(point)
		point=well.well_position+radial.rotated(side*travel/orbit_radius)*orbit_radius
		var end_radial: Vector2=(point-well.well_position).normalized()
		velocity=(end_radial.orthogonal()*side+end_radial*0.22).normalized()*speed
	return {"point":point,"velocity":velocity}

## Curvature for matter repelled by white holes. It begins a broad turn before
## reaching the core; no reflected (billiard-ball) velocity is ever produced.
static func white_velocity(at: Vector2, velocity: Vector2, delta: float, wells: Array) -> Vector2:
	var speed := velocity.length()
	if speed < 0.01: return velocity
	var direction := velocity/speed
	for well in wells:
		if well.kind != "white": continue
		var offset: Vector2=at-well.well_position
		var distance := offset.length()
		var radius := core_radius(well)+12.0
		var reach := radius+220.0
		if distance < 0.001 or distance >= reach: continue
		var radial := offset/distance
		var approach := maxf(0.0,-direction.dot(radial))
		if approach <= 0.0: continue
		var side := 1.0 if direction.cross(radial)>=0.0 else -1.0
		var proximity := clampf((reach-distance)/(reach-radius),0.0,1.0)
		var desired := (radial.orthogonal()*side+radial*0.32).normalized()
		var turn := 1.0-exp(-delta*(8.0+speed/45.0)*proximity*proximity)
		direction=direction.lerp(desired,turn*sqrt(approach)).normalized()
	return direction*speed

## Advance a shot along small curved segments, never a chord through a core.
## Work is capped at 96 steps (normally 1–3); capture preserves weapon speed.
static func projectile_motion(from: Vector2, velocity: Vector2, delta: float, wells: Array, capture_id: int = 0, capture_spin: float = 0.0) -> Dictionary:
	var path: Array[Vector2]=[]
	if wells.is_empty():
		path.assign([from,from+velocity*delta])
		return {"path":path,"velocity":velocity,"capture":0,"spin":0.0}
	var point := from
	var speed := velocity.length()
	var count := clampi(ceili(speed*delta/8.0),1,96)
	var dt := delta/float(count)
	var capture := capture_id
	var spin := capture_spin
	for step in range(count):
		var well := capture_well(point,wells,capture)
		if well != null:
			var radial: Vector2=(point-well.well_position).normalized()
			if radial == Vector2.ZERO: radial=-velocity.normalized()
			if capture != well.get_instance_id() or spin == 0.0:
				spin=1.0 if velocity.cross(radial)>=0.0 else -1.0
			capture=well.get_instance_id()
			var distance: float=point.distance_to(well.well_position)
			var sink := lerpf(0.58,0.8,clampf(core_radius(well)/maxf(distance,1.0),0.0,1.0))
			var desired := (-radial*sink+radial.orthogonal()*spin*sqrt(1.0-sink*sink)).normalized()
			var direction := velocity.normalized().lerp(desired,1.0-exp(-dt*12.0)).normalized()
			# An outward or homing shot cannot break its capture. Preserve its
			# tangent momentum, but guarantee inward motion throughout the spiral.
			var inward := direction.dot(-radial)
			if inward < 0.35:
				direction=(direction+radial*(inward-0.35)).normalized()
			velocity=direction*speed
		else:
			capture=0
			spin=0.0
		velocity=white_velocity(point,velocity,dt,wells)
		var next := point+velocity*dt
		var safe := white_safe_step(point,next,velocity,wells)
		next=safe.point
		velocity=safe.velocity
		path.append_array([point,next])
		point=next
		# A swallowed shot stops here. The caller handles targets earlier on
		# its visible path before actually deleting it at the event horizon.
		if not first_core(path[-2],path[-1],wells).is_empty(): break
	return {"path":path,"velocity":velocity,"capture":capture,"spin":spin}

## Find the first core in travel order, not the straight chord between endpoints.
static func first_path_core(path: Array[Vector2], wells: Array) -> Dictionary:
	for index in range(0,path.size()-1,2):
		var hit := first_core(path[index],path[index+1],wells)
		if not hit.is_empty():
			hit["segment"]=index
			return hit
	return {}
