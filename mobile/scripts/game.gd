extends Node2D
## Owns the run state; the UI and actors handle their own presentation.

const Ship = preload("res://scripts/ship.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Progress = preload("res://scripts/progress.gd")
const Sound = preload("res://scripts/sound.gd")
const Interface = preload("res://scripts/interface.gd")
const Boss = preload("res://scripts/boss.gd")
const Asteroid = preload("res://scripts/asteroid.gd")
const SpaceBackground = preload("res://scripts/space_background.gd")
const SpaceFolds = preload("res://scripts/space_folds.gd")
const WeaponSystem = preload("res://scripts/weapon_system.gd")
const Pickup = preload("res://scripts/pickup.gd")
const POINTS_PER_ENEMY := 100
const MAX_LIVES := 3
const MAX_ENEMIES := 14
const BOSS_KINDS := ["black", "white", "asteroid", "swarm"]
enum State { MENU, PLAYING, PAUSED, WON, LOST }

var state := State.MENU
var selected_mode := "endless"
var encounter := "endless"
var loss_reason := "The next run starts with a clean slate."
var boss: Node2D
var asteroids: Array[Node2D] = []
var pickups: Array[Node2D] = []
var weapons = WeaponSystem.new()
var bosses_defeated := 0
var boss_timer := 40.0
var boss_warning := 0.0
var lingering_wells: Array[Node2D] = []
## Includes detached gravity wells and finite asteroid/alien barrages after boss death.
var returning_to_cruise := false
var laser: Node2D
var laser_exposure: Dictionary = {}
## Keys are instance IDs, values are uninterrupted contact seconds; absent targets reset.
var pending_boss := ""
var boss_deck: Array[String] = []
var recovery_time := 0.0
var wave_timer := 0.5
var asteroid_timer := 5.0
var save_timer := 10.0
var kills_since_drop := 0
var advanced_drop_sector := -1
var pickup_notice := ""
var pickup_notice_time := 0.0
var score := 0
var lives := 3
var elapsed := 0.0
var visual_time := 0.0
var shot_timer := 0.0
var enemy_shot_timer := 2.0
var damage_flash := 0.0
var best_at_start := 0
var arena := Vector2(540, 960)
var top_inset := 36.0
var bottom_inset := 28.0
var pointer_id := -1
var previous_pointer_x := 0.0
var enemies: Array[Node2D] = []
var projectiles: Array[Node2D] = []
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var progress = Progress.new()
var ship = Ship.new()
var sound = Sound.new()
var interface = Interface.new()
var space_background = SpaceBackground.new()
var space_folds = SpaceFolds.new()

## Godot calls this once after the node joins the scene; initialize child nodes and cached resources here.
func _ready() -> void:
	rng.randomize()
	space_background.z_index = -30
	add_child(space_background)
	add_child(space_folds)
	add_child(ship)
	add_child(sound)
	sound.enabled = progress.sound_enabled
	interface.game = self
	interface.z_index = 50
	add_child(interface)
	get_viewport().size_changed.connect(update_layout)
	update_layout()
	show_title()

## Recompute safe-area insets and scale existing positions on resize, including mobile display cutouts.
func update_layout() -> void:
	var old_arena := arena
	arena = get_viewport_rect().size
	top_inset = 36.0
	bottom_inset = 28.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if screen.y > 0 and safe.size.y > 0:
			top_inset = maxf(top_inset, float(safe.position.y) / screen.y * arena.y + 12.0)
			bottom_inset = maxf(bottom_inset, float(screen.y - safe.end.y) / screen.y * arena.y + 12.0)
	if state == State.MENU:
		ship.position = Vector2(arena.x * 0.5, arena.y * 0.475)
	else:
		var resize_scale := arena / old_arena
		ship.position *= resize_scale
		ship.target_x = ship.position.x
		if is_instance_valid(boss):
			boss.well_position *= resize_scale
	interface.size = arena
	interface.refresh()
	refresh_space()
	queue_redraw()

## Leave gameplay, clear owned actors, and restore the title-screen ship pose.
func show_title() -> void:
	clear_actors()
	state = State.MENU
	sound.silence()
	pointer_id = -1
	ship.reset_ship(Vector2(arena.x * 0.5, arena.y * 0.475))
	ship.scale = Vector2.ONE * 1.65
	interface.refresh()

## Reset run-local score, lives, weapons, timers and actors. An optional boss kind is a developer/test shortcut.
func start_run(mode: String = "") -> void:
	clear_actors()
	encounter = "endless"
	selected_mode = "endless"
	loss_reason = "The next run starts with a clean slate."
	score = 0
	lives = 3
	elapsed = 0.0
	bosses_defeated = 0
	weapons.level = 0
	boss_timer = rng.randf_range(38.0, 48.0)
	wave_timer = 0.4
	asteroid_timer = rng.randf_range(4.0, 7.0)
	save_timer = 10.0
	kills_since_drop = 0
	advanced_drop_sector = -1
	pickup_notice = ""
	pickup_notice_time = 0.0
	boss_deck.clear()
	shot_timer = 0.22
	enemy_shot_timer = 2.4
	damage_flash = 0.0
	pointer_id = -1
	best_at_start = progress.best_for(encounter)
	state = State.PLAYING
	ship.reset_ship(cruise_position())
	sound.set_boss_music(false)
	sound.set_paused(false)
	# Explicit modes are developer entry points for encounter tests only.
	if mode in BOSS_KINDS:
		begin_boss(mode)
	interface.refresh()
	refresh_space()

## Return the normal lower-center ship position in logical viewport pixels.
func cruise_position() -> Vector2:
	return Vector2(arena.x * 0.5, arena.y - bottom_inset - 152.0)

## Immediately reset the ship only for emergency recovery; victory return uses bounded movement in the physics loop.
func restore_cruise_position() -> void:
	ship.position = cruise_position()
	ship.target_x = ship.position.x
	ship.rotation = 0.0
	ship.lean = 0.0
	pointer_id = -1

## Free every run-owned actor, including persistent laser and detached attacks, when restarting or returning to title.
func clear_actors() -> void:
	if is_instance_valid(laser):
		laser.queue_free()
	laser = null
	sound.set_laser(false)
	for well in lingering_wells:
		well.queue_free()
	lingering_wells.clear()
	returning_to_cruise = false
	laser_exposure.clear()
	for actor in enemies + projectiles + asteroids + pickups:
		actor.queue_free()
	if is_instance_valid(boss):
		boss.queue_free()
		boss = null
	enemies.clear()
	projectiles.clear()
	asteroids.clear()
	pickups.clear()
	particles.clear()
	boss_warning = 0.0
	pending_boss = ""
	recovery_time = 0.0

## Run fixed-step gameplay in dependency order: director, ship, bosses, hazards, projectiles, laser, then pickups.
func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	pickup_notice_time = maxf(0.0, pickup_notice_time - delta)
	save_timer -= delta
	if save_timer <= 0.0:
		progress.save()
		save_timer = 10.0
	update_director(delta)
	damage_flash = maxf(0.0, damage_flash - delta * 2.5)
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	ship.weapon_level = weapons.level
	if gravity_is_active():
		ship.animate(delta)
		ship.invulnerable = maxf(0, ship.invulnerable - delta)
	elif returning_to_cruise:
		ship.position = ship.position.move_toward(cruise_position(), 260.0 * delta)
		ship.target_x = ship.position.x
		ship.invulnerable = maxf(ship.invulnerable, 0.2)
		ship.animate(delta)
		if ship.position.distance_to(cruise_position()) < 0.1:
			returning_to_cruise = false
	else:
		ship.move_ship(delta, clampf(direction, -1, 1), arena.x)
	shot_timer -= delta
	if weapons.level != 3 and shot_timer <= 0.0:
		shot_timer += fire_player_shot()
	if is_instance_valid(boss):
		boss.step(delta)
		if state != State.PLAYING:
			return
	for well in lingering_wells.duplicate():
		well.step(delta)
		if state != State.PLAYING:
			return
	update_enemies(delta)
	if state != State.PLAYING:
		return
	update_asteroids(delta)
	if state != State.PLAYING:
		return
	update_projectiles(delta)
	update_laser(delta)
	if state == State.PLAYING:
		update_pickups(delta)
	interface.queue_redraw()

## Start at 1 and add one percentage point for every defeated boss.
func difficulty_percent() -> int:
	return 1 + bosses_defeated

## Convert the displayed percentage to the 50-percent reference used by firing and extra-drop probabilities.
func difficulty_scale() -> float:
	return float(difficulty_percent()) / 50.0

## Legacy pacing helper retained for compatibility; current movement and spawn timing do not use it.
func difficulty_pace() -> float:
	return maxf(0.65, difficulty_scale())

## Schedule regular waves, boss warnings and recoveries; do not start a new encounter while residual attacks remain.
func update_director(delta: float) -> void:
	if not lingering_wells.is_empty() or returning_to_cruise:
		return
	if is_instance_valid(boss):
		return
	if recovery_time > 0.0:
		recovery_time = maxf(0.0, recovery_time - delta)
		return
	if boss_warning > 0.0:
		boss_warning = maxf(0.0, boss_warning - delta)
		if boss_warning == 0.0:
			begin_boss(pending_boss)
		return
	boss_timer -= delta
	if boss_timer <= 0.0:
		pending_boss = next_boss_kind()
		boss_warning = 3.0
		for enemy in enemies:
			enemy.shield_guard = true
		sound.set_boss_music(true)
		interface.refresh()
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		spawn_enemy_group()
		wave_timer = rng.randf_range(1.5, 2.7)
	asteroid_timer -= delta
	if asteroid_timer <= 0.0:
		var radius: float = [20.0, 31.0, 43.0][rng.randi_range(0, 2)]
		spawn_asteroid(Vector2(rng.randf_range(45.0, arena.x - 45.0), -radius - 10.0),
			Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(145.0, 205.0)), radius)
		asteroid_timer = rng.randf_range(4.0, 7.0)

## Draw from a shuffled four-boss deck so each type appears once before the deck refills.
func next_boss_kind() -> String:
	if boss_deck.is_empty():
		boss_deck.assign(BOSS_KINDS)
		for i in range(boss_deck.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := boss_deck[i]
			boss_deck[i] = boss_deck[j]
			boss_deck[j] = swap
	return boss_deck.pop_back()

## Spawn a bounded random group with one shared reward token; its first destroyed ship guarantees a pickup.
func spawn_enemy_group() -> void:
	var count := mini(rng.randi_range(1, 5), MAX_ENEMIES - enemies.size())
	if count <= 0:
		return
	var group_center := rng.randf_range(90.0, arena.x - 90.0)
	var reward := {"dropped": false}
	for i in range(count):
		var x := clampf(group_center + (i - (count - 1) * 0.5) * 66.0 + rng.randf_range(-16.0, 16.0), 38.0, arena.x - 38.0)
		var alien = spawn_enemy(Vector2(x, -45.0 - i * 42.0), Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(95.0, 145.0)))
		alien.drop_group = reward

## Create and register an alien, applying durability progression, firing cadence and optional summoned motion.
func spawn_enemy(at: Vector2, velocity: Vector2, summoned: bool = false, fold_origin: Vector2 = Vector2.INF) -> Node2D:
	var enemy = Enemy.new()
	enemy.position = at
	enemy.previous_position = at
	enemy.velocity = velocity
	enemy.health = mini(9, 3 + floori(bosses_defeated / 2.0))
	enemy.phase = rng.randf_range(0.0, TAU)
	enemy.shot_timer = rng.randf_range(0.85, 1.7) / difficulty_scale()
	enemy.zigzag = not summoned and rng.randf() < 0.45
	enemy.summoned = summoned
	enemy.tint = Color("73eac4") if summoned else [Color("ffb86a"), Color("f1958d"), Color("baacf5")][rng.randi_range(0, 2)]
	if fold_origin != Vector2.INF:
		enemy.begin_pull(fold_origin)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

## Create the boss and recruit surviving aliens as orbiting guards without clearing the playfield.
func begin_boss(kind: String) -> void:
	boss_warning = 0.0
	pending_boss = ""
	boss = Boss.new()
	boss.game = self
	boss.kind = kind if kind in BOSS_KINDS else "black"
	# 35, 40, 44...: shrinking gains, asymptote at 100.
	boss.max_health = minf(99.0, floorf(100.0 - 780.0 / (12.0 + bosses_defeated)))
	boss.health = boss.max_health
	add_child(boss)
	boss.step(0.0)
	for i in range(enemies.size()):
		enemies[i].shield_guard = true
		enemies[i].guard_angle = TAU * float(i) / maxf(1.0, enemies.size())
	sound.set_boss_music(true)
	interface.refresh()

## Award victory once, detach unfinished attacks, create the gravity death well, and schedule a smooth cruise return.
func defeat_boss(defeated: Node2D) -> void:
	if state != State.PLAYING or defeated != boss:
		return
	var was_gravity: bool = defeated.kind in ["black", "white"]
	var at: Vector2 = defeated.body_position
	burst(at, Color("ffca8d"), 60)
	add_score(1500 + bosses_defeated * 250)
	bosses_defeated += 1
	if defeated.phase in ["warning", "active", "clearing"]:
		create_lingering_well(defeated, false)
	if was_gravity:
		create_lingering_well(defeated, true)
		if defeated.kind == "black":
			# Reverse the death particles so they collapse into the new core.
			for particle in particles:
				if particle.position.distance_to(at) < 1.0:
					particle.position += particle.velocity * 0.6
					particle.velocity = (at - particle.position) * 2.0
	defeated.queue_free()
	boss = null
	returning_to_cruise = true
	ship.invulnerable = maxf(ship.invulnerable, 2.5)
	guaranteed_drop(Vector2(ship.position.x, ship.position.y - 130.0))
	recovery_time = 3.0
	boss_timer = rng.randf_range(40.0, 55.0)
	wave_timer = 0.5
	asteroid_timer = 4.0
	sound.set_boss_music(false)
	sound.play_effect("boss_death")
	progress.save()
	interface.refresh()
	refresh_space()

## Return true while any surviving alien is assigned to the current boss's shield.
func boss_is_shielded() -> bool:
	return enemies.any(func(enemy: Node2D) -> bool: return enemy.shield_guard)

## Check both the live boss and detached wells, so tap controls continue after a gravity boss dies.
func gravity_is_active() -> bool:
	if is_instance_valid(boss) and boss.holds_steering():
		return true
	return lingering_wells.any(func(well: Node2D) -> bool: return well.holds_steering())

## Copy attack state into an independent node; death wells are larger and last eight seconds.
func create_lingering_well(source: Node2D, death_well: bool) -> void:
	var well = Boss.new()
	well.game = self
	well.kind = source.kind
	well.body_position = source.body_position
	well.lingering = true
	well.health = 1.0
	well.phase = "active" if death_well else source.phase
	well.phase_time = 0.0 if death_well else source.phase_time
	well.well_position = source.body_position if death_well else source.well_position
	well.well_duration = Boss.ACTIVE_SECONDS * (2.0 if death_well else 1.0)
	well.well_scale = 1.8 if death_well else 1.0
	well.cannon_active = not death_well and source.cannon_active
	well.cannon_position = source.cannon_position
	well.cannon_previous_position = source.cannon_previous_position
	well.cannon_velocity = source.cannon_velocity
	well.neutralise_time = source.neutralise_time
	well.asteroid_timer = source.asteroid_timer
	well.swarm_count = source.swarm_count
	well.swarm_reward = source.swarm_reward
	add_child(well)
	lingering_wells.append(well)

## Maintain one beam node and uninterrupted per-target exposure. Non-bosses die at 0.25 s; bosses take four hits/second.
func update_laser(delta: float) -> void:
	var active: bool = state == State.PLAYING and weapons.level == 3
	sound.set_laser(active)
	if not active:
		if is_instance_valid(laser):
			laser.queue_free()
		laser = null
		laser_exposure.clear()
		return
	if not is_instance_valid(laser):
		laser = Projectile.new()
		laser.continuous = true
		add_child(laser)
	laser.setup_laser(ship.position + Vector2(0, -44), Vector2(ship.position.x, top_inset + 140))
	laser.queue_redraw()
	var contacts: Dictionary = {}
	var targets: Array[Node2D] = []
	targets.append_array(enemies)
	targets.append_array(asteroids)
	if is_instance_valid(boss) and not boss_is_shielded():
		targets.append(boss)
	for actor in targets:
		var kind := "boss" if actor == boss else ("enemy" if enemies.has(actor) else "rock")
		if not target_is_exposed(actor, kind):
			continue
		var at: Vector2 = actor.body_position if kind == "boss" else actor.position
		var radius: float = Boss.HIT_RADIUS if kind == "boss" else (Enemy.HIT_RADIUS if kind == "enemy" else actor.radius)
		if not laser.intersects(at, radius):
			continue
		var id := actor.get_instance_id()
		var exposure: float = laser_exposure.get(id, 0.0) + delta
		if exposure >= 0.25:
			if kind == "boss":
				damage_target(actor, kind, int(exposure / 0.25))
				exposure = fmod(exposure, 0.25)
			else:
				damage_target(actor, kind, int(ceil(actor.health)))
				continue
		contacts[id] = exposure
	laser_exposure = contacts

## Explicitly remove hostile actors/projectiles for emergency recovery; ordinary boss victory does not call this.
func clear_hazards() -> void:
	for enemy in enemies.duplicate():
		remove_enemy(enemy)
	for rock in asteroids.duplicate():
		remove_asteroid(rock)
	for shot in projectiles.duplicate():
		remove_projectile(shot)

## Animate background and transient particles outside physics; freeze all visual time while paused.
func _process(delta: float) -> void:
	if state != State.PAUSED:
		visual_time += delta
		if state != State.PLAYING:
			ship.animate(delta)
		for i in range(particles.size() - 1, -1, -1):
			particles[i].life -= delta
			particles[i].position += particles[i].velocity * delta
			particles[i].velocity *= exp(-delta * 3.0)
			if particles[i].life <= 0:
				particles.remove_at(i)
	queue_redraw()
	interface.queue_redraw()
	refresh_space()

## Synchronize background and refraction shader data with the current actors and visual clock.
func refresh_space() -> void:
	space_background.update_background(arena, visual_time)
	space_folds.update_effects(self)

## Move ordinary aliens or orbit guards, resolve swept ship contact, and fire aimed shots at per-enemy intervals.
func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not enemies.has(enemy):
			continue
		if is_instance_valid(boss) and enemy.summoned:
			enemy.fold_origin = boss.body_position + Vector2(0, 42)
		if enemy.shield_guard:
			enemy.previous_position = enemy.position
			if is_instance_valid(boss):
				enemy.guard_angle += delta * 0.35
				var orbit: Vector2 = boss.body_position + Vector2(cos(enemy.guard_angle) * 110.0, sin(enemy.guard_angle) * 95.0)
				enemy.position = enemy.position.move_toward(orbit, 240.0 * delta)
			enemy.queue_redraw()
		else:
			enemy.advance(delta, ship.position)
		if enemy.motion_phase == "flight":
			enemy.position.x = clampf(enemy.position.x, 32.0, arena.x - 32.0)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, enemy.previous_position, enemy.position)
		if closest.distance_to(ship.position) < Ship.HIT_RADIUS + Enemy.HIT_RADIUS:
			remove_enemy(enemy)
			damage_ship()
			if state != State.PLAYING:
				return
			continue
		if enemy.position.y > arena.y + 65.0:
			remove_enemy(enemy)
			continue
		if enemy.motion_phase == "flight" and enemy.position.y > top_inset + 110.0 and enemy.position.y < ship.position.y - 90.0:
			enemy.shot_timer -= delta
			if enemy.shot_timer <= 0.0:
				var aim: Vector2 = (ship.position - enemy.position).normalized()
				spawn_hostile_shot(enemy.position + Vector2(0, 24), aim * (215.0 if enemy.summoned else 180.0))
				enemy.shot_timer = rng.randf_range(1.05, 1.9) / difficulty_scale()

## Delegate the current weapon pattern and return its cooldown to the automatic fire timer.
func fire_player_shot() -> float:
	return weapons.fire(self)

## Legacy single-enemy volley helper; normal enemies now fire using their individual timers.
func fire_enemy_shot() -> void:
	var shooter = enemies[rng.randi_range(0, enemies.size() - 1)]
	# Modest horizontal aim: the player can read and dodge the trajectory.
	spawn_hostile_shot(shooter.position + Vector2(0, 23), Vector2(clampf((ship.position.x - shooter.position.x) * 0.24, -72, 72), 245))

## Register a fixed-speed hostile projectile; difficulty changes firing intervals rather than bullet speed.
func spawn_hostile_shot(at: Vector2, velocity: Vector2) -> void:
	var shot = Projectile.new()
	shot.hostile = true
	shot.position = at
	shot.previous_position = shot.position
	shot.velocity = velocity
	add_child(shot)
	projectiles.append(shot)

## Sweep projectiles through exposed targets in travel order, process splash damage, and free expired/offscreen shots.
func update_projectiles(delta: float) -> void:
	for shot in projectiles.duplicate():
		if not projectiles.has(shot):
			continue
		shot.advance(delta)
		if shot.hostile:
			if shot.intersects(ship.position, Ship.HIT_RADIUS + 3.0):
				remove_projectile(shot)
				damage_ship()
				if state != State.PLAYING:
					return
		else:
			var targets: Array[Dictionary] = []
			for rock in asteroids:
				if target_is_exposed(rock, "rock") and shot.intersects(rock.position, rock.radius):
					targets.append({"actor": rock, "type": "rock", "at": rock.position})
			if is_instance_valid(boss) and target_is_exposed(boss, "boss") and shot.intersects(boss.body_position, Boss.HIT_RADIUS):
				targets.append({"actor": boss, "type": "boss", "at": boss.body_position})
			for enemy in enemies:
				if target_is_exposed(enemy, "enemy") and shot.intersects(enemy.position, Enemy.HIT_RADIUS):
					targets.append({"actor": enemy, "type": "enemy", "at": enemy.position})
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return shot.previous_position.distance_squared_to(a.at) < shot.previous_position.distance_squared_to(b.at))
			for target in targets:
				if not projectiles.has(shot):
					break
				var id: int = target.actor.get_instance_id()
				if shot.hit_ids.has(id):
					continue
				shot.hit_ids[id] = true
				damage_target(target.actor, target.type, shot.damage)
				if shot.blast_radius > 0.0:
					detonate_rocket(target.at, shot.blast_radius, target.actor)
				if not shot.piercing:
					if projectiles.has(shot):
						remove_projectile(shot)
					break
		if state != State.PLAYING:
			return
		if projectiles.has(shot) and (shot.expired or shot.position.y < -50 or shot.position.y > arena.y + 50 or shot.position.x < -80 or shot.position.x > arena.x + 80):
			remove_projectile(shot)

## Reject targets outside the playable area or still in boss arrival, including hits from lasers and splash.
func target_is_exposed(actor: Node2D, kind: String) -> bool:
	var at: Vector2 = actor.body_position if kind == "boss" else actor.position
	var radius: float = Boss.HIT_RADIUS if kind == "boss" else (actor.radius if kind == "rock" else Enemy.HIT_RADIUS)
	if kind == "boss" and actor.phase == "arrival":
		return false
	return at.x - radius >= 0.0 and at.x + radius <= arena.x and at.y - radius >= top_inset + 140.0 and at.y + radius <= arena.y

## Route damage by actor type while enforcing exposure and the boss's alien shield gate.
func damage_target(actor: Node2D, kind: String, amount: int) -> void:
	if not target_is_exposed(actor, kind):
		return
	if kind == "rock" and asteroids.has(actor):
		hit_asteroid(actor, amount)
	elif kind == "boss" and actor == boss:
		if not boss_is_shielded():
			boss.take_hit(amount)
	elif kind == "enemy" and enemies.has(actor):
		actor.health -= amount
		if actor.health <= 0:
			destroy_enemy(actor)

## Apply the rocket's area damage once per nearby target, excluding the target already hit directly.
func detonate_rocket(at: Vector2, radius: float, direct_target: Node2D) -> void:
	burst(at, Color("ffb86a"), 24)
	for enemy in enemies.duplicate():
		if enemy != direct_target and enemy.position.distance_to(at) <= radius + Enemy.HIT_RADIUS:
			damage_target(enemy, "enemy", 2)
	for rock in asteroids.duplicate():
		if rock != direct_target and rock.position.distance_to(at) <= radius + rock.radius:
			damage_target(rock, "rock", 2)
	if is_instance_valid(boss) and boss != direct_target and boss.body_position.distance_to(at) <= radius + Boss.HIT_RADIUS:
		damage_target(boss, "boss", 2)
	sound.play_effect("burst")

## Remove a shot from the active list before queueing deletion to keep same-frame iterations safe.
func remove_projectile(shot: Node2D) -> void:
	projectiles.erase(shot)
	shot.queue_free()

## Award score and the group's guaranteed/random pickup before removing the defeated alien.
func destroy_enemy(enemy: Node2D) -> void:
	if not enemies.has(enemy):
		return
	burst(enemy.position, enemy.tint, 18)
	if not enemy.drop_group.is_empty() and not enemy.drop_group.dropped:
		enemy.drop_group.dropped = true
		guaranteed_drop(enemy.position)
	else:
		maybe_drop_pickup(enemy.position)
	remove_enemy(enemy)
	add_score(POINTS_PER_ENEMY)
	sound.play_effect("burst")

## Remove an alien without kill rewards; used for escape, contact, and explicit cleanup.
func remove_enemy(enemy: Node2D) -> void:
	enemies.erase(enemy)
	enemy.queue_free()

## Ensure a pickup even at the actor cap, choosing life versus weapon while preserving advanced-tier rarity.
func guaranteed_drop(at: Vector2) -> void:
	# Keep the guarantee even when old, uncollected drops fill the actor budget.
	if pickups.size() >= 12:
		var oldest: Node2D = pickups.pop_front()
		oldest.queue_free()
	var pending := pickups.filter(func(drop: Node2D) -> bool: return drop.kind == "weapon").size()
	var projected: int = weapons.level + pending
	var kind := "life"
	if projected < 2:
		kind = "weapon" if rng.randf() < 0.65 else "life"
	elif projected < 4 and advanced_drop_sector != bosses_defeated and rng.randf() < 0.1:
		kind = "weapon"
		advanced_drop_sector = bosses_defeated
	spawn_pickup(at, kind)

## Roll optional extra drops using difficulty-scaled chances and the per-sector advanced weapon reservation.
func maybe_drop_pickup(at: Vector2) -> void:
	kills_since_drop += 1
	var roll := rng.randf()
	var pending := pickups.filter(func(drop: Node2D) -> bool: return drop.kind == "weapon").size()
	var advanced: bool = weapons.level + pending >= 2
	var drop_scale := difficulty_scale()
	if advanced:
		# Reserve the sector allowance when dropped, including uncollected drops.
		if weapons.level + pending < 4 and advanced_drop_sector != bosses_defeated and roll < minf(1.0, 0.005 * drop_scale):
			spawn_pickup(at, "weapon")
			advanced_drop_sector = bosses_defeated
			kills_since_drop = 0
	elif roll < minf(1.0, 0.02 * drop_scale):
		spawn_pickup(at, "weapon")
		kills_since_drop = 0
	if roll >= 1.0 - minf(1.0, 0.02 * drop_scale):
		spawn_pickup(at, "life")

## Create a bounded collectible inside the horizontal playfield; collection is handled separately.
func spawn_pickup(at: Vector2, kind: String) -> void:
	if pickups.size() >= 12:
		return
	var pickup = Pickup.new()
	pickup.kind = kind
	pickup.position = Vector2(clampf(at.x, 30.0, arena.x - 30.0), maxf(at.y, top_inset + 110.0))
	pickup.previous_position = pickup.position
	pickup.phase = rng.randf_range(0.0, TAU)
	add_child(pickup)
	pickups.append(pickup)

## Drift and magnetize drops, then collect using swept collision; suspend collection during tap-only gravity.
func update_pickups(delta: float) -> void:
	# Drops wait while gravity replaces steering with tapping.
	if gravity_is_active():
		return
	for pickup in pickups.duplicate():
		pickup.advance(delta)
		if pickup.position.distance_to(ship.position) < 135.0:
			pickup.position = pickup.position.move_toward(ship.position, 210.0 * delta)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, pickup.previous_position, pickup.position)
		if closest.distance_to(ship.position) <= Ship.HIT_RADIUS + Pickup.HIT_RADIUS:
			collect_pickup(pickup)
		elif pickup.position.y > arena.y + 45.0:
			pickups.erase(pickup)
			pickup.queue_free()

## Apply a hull repair or weapon tier, award surplus points, and update feedback without altering bullet cadence.
func collect_pickup(pickup: Node2D) -> void:
	if not pickups.has(pickup):
		return
	if pickup.kind == "life":
		if lives < MAX_LIVES:
			lives += 1
			pickup_notice = "HULL RESTORED +1"
		else:
			add_score(100)
			pickup_notice = "FULL HULL  +100"
	else:
		if weapons.level < WeaponSystem.MAX_LEVEL:
			weapons.upgrade()
			shot_timer = 0.0
			pickup_notice = weapons.weapon_name() + " ONLINE"
		else:
			add_score(150)
			pickup_notice = "MAX WEAPON  +150"
	pickup_notice_time = 2.0
	burst(pickup.position, Color("7cf3b7") if pickup.kind == "life" else Color("ffc56e"), 14)
	pickups.erase(pickup)
	pickup.queue_free()
	sound.play_effect("pickup")
	interface.refresh()

## Add points to the run and update the in-memory endless high score.
func add_score(points: int) -> void:
	score += points
	progress.record_score(encounter, score)

## Legacy developer selector; the public title screen always launches endless flight.
func select_mode(mode: String) -> void:
	selected_mode = mode
	interface.refresh()

## Create a rock with size-based durability plus progression, optionally starting an offscreen tethered pull.
func spawn_asteroid(at: Vector2, velocity: Vector2, radius: float, health: int = 0, fold_origin: Vector2 = Vector2.INF, aim_offset: Vector2 = Vector2.ZERO) -> void:
	var rock = Asteroid.new()
	rock.position = at
	rock.previous_position = at
	rock.velocity = velocity
	rock.radius = radius
	if health <= 0:
		health = (5 if radius < 26.0 else (8 if radius < 37.0 else 12)) + floori(bosses_defeated / 2.0)
	rock.health = health
	rock.spin = rng.randf_range(-2, 2)
	if fold_origin != Vector2.INF:
		rock.begin_pull(fold_origin, aim_offset)
	add_child(rock)
	asteroids.append(rock)

## Advance rocks, keep live-boss anchors aligned, and resolve swept ship contact or offscreen removal.
func update_asteroids(delta: float) -> void:
	for rock in asteroids.duplicate():
		if not asteroids.has(rock):
			continue
		if is_instance_valid(boss) and boss.kind == "asteroid":
			rock.fold_origin = boss.body_position + Vector2(0, 42)
		rock.advance(delta, ship.position)
		var closest := Geometry2D.get_closest_point_to_segment(ship.position, rock.previous_position, rock.position)
		if closest.distance_to(ship.position) <= rock.radius + Ship.HIT_RADIUS:
			remove_asteroid(rock)
			damage_ship()
			if state != State.PLAYING:
				return
		elif rock.position.y > arena.y + 60:
			remove_asteroid(rock)

## Subtract durability, flash the rock, and award points only once when it breaks.
func hit_asteroid(rock: Node2D, amount: int = 1) -> void:
	rock.health -= amount
	rock.flash = 0.08
	if rock.health <= 0:
		burst(rock.position, Color("d6b899"), 15)
		remove_asteroid(rock)
		add_score(25)
		sound.play_effect("burst")

## Remove a rock from the update list before scheduling its node for deletion.
func remove_asteroid(rock: Node2D) -> void:
	asteroids.erase(rock)
	rock.queue_free()

## Handle lethal gravity contact, consuming an upgrade-backed emergency life if one is available.
func lose_ship(reason: String) -> void:
	if state != State.PLAYING:
		return
	lives = 0
	if use_emergency_life():
		return
	ship.visible = false
	loss_reason = reason
	burst(ship.position, Color("ff816f"), 42)
	sound.play_effect("hit")
	finish_run(false)

## Apply one hull hit unless invulnerable, play dedicated feedback, and handle emergency life or game over.
func damage_ship() -> void:
	if state != State.PLAYING or ship.invulnerable > 0.0:
		return
	lives -= 1
	damage_flash = 0.6
	burst(ship.position, Color("ff816f"), 28)
	sound.play_effect("hit")
	if lives == 0:
		if use_emergency_life():
			return
		ship.visible = false
		finish_run(false)
		return
	ship.invulnerable = 1.6
	for shot in projectiles.duplicate():
		if shot.hostile:
			remove_projectile(shot)

## Consume the weapon upgrade to revive at one hull life, clear hazards, and reset the weapon to single.
func use_emergency_life() -> bool:
	if weapons.level <= 0:
		return false
	weapons.level = 0
	lives = 1
	ship.visible = true
	ship.invulnerable = 2.5
	restore_cruise_position()
	clear_hazards()
	if is_instance_valid(boss):
		boss.return_to_firefight()
	shot_timer = 0.0
	pickup_notice = "EMERGENCY LIFE · SINGLE SHOT"
	pickup_notice_time = 3.0
	sound.play_effect("pickup")
	interface.refresh()
	return true

## End a lost run and save records; the legacy win path delegates to endless boss victory handling.
func finish_run(won: bool) -> void:
	if state != State.PLAYING:
		return
	if won:
		if is_instance_valid(boss):
			defeat_boss(boss)
		return
	state = State.LOST
	update_laser(0.0)
	sound.silence()
	pointer_id = -1
	for shot in projectiles.duplicate():
		remove_projectile(shot)
	progress.save()
	interface.refresh()

## Freeze gameplay and sound while releasing the active drag to avoid stale input.
func pause_run() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	pointer_id = -1
	ship.target_x = ship.position.x
	sound.set_paused(true)
	progress.save()
	interface.refresh()

## Return from pause without restarting the encounter and re-enable the appropriate audio loop.
func resume_run() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	sound.set_paused(false)
	pointer_id = -1
	interface.refresh()

## Persist the mute preference and apply it to every active sound channel.
func toggle_sound() -> void:
	progress.sound_enabled = not progress.sound_enabled
	sound.enabled = progress.sound_enabled
	sound.sync_enabled()
	progress.save()
	interface.refresh()

## Append bounded short-lived particles; the cap prevents explosion-heavy weapons from growing work without limit.
func burst(at: Vector2, tint: Color, count: int) -> void:
	for i in range(mini(count, maxi(0, 256 - particles.size()))):
		var duration := rng.randf_range(0.25, 0.75)
		particles.append({"position": at, "velocity": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 220),
			"life": duration, "duration": duration, "tint": tint, "radius": rng.randf_range(1.5, 4.0)})

## Route unconsumed GUI input to dragging or tap neutralisation, including every surviving gravity well.
func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and gravity_is_active():
		var pressed_touch: bool = event is InputEventScreenTouch and event.pressed
		var pressed_mouse: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
		var pressed_space: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
		if pressed_touch or pressed_mouse or pressed_space:
			if is_instance_valid(boss):
				boss.resist()
			for well in lingering_wells:
				well.resist()
		# Pause remains available during a gravity attack; dragging is suspended.
		if not (event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_P]):
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if state == State.PLAYING:
				pause_run()
			elif state == State.PAUSED:
				resume_run()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and state in [State.MENU, State.WON, State.LOST]:
			start_run()
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -1 and event.position.y > top_inset + 110:
			pointer_id = event.index
			previous_pointer_x = event.position.x
		elif not event.pressed and event.index == pointer_id:
			pointer_id = -1
	elif event is InputEventScreenDrag:
		# A finger held through the end of a tap-only attack can resume dragging.
		if pointer_id == -1 and event.position.y > top_inset + 110:
			pointer_id = event.index
			previous_pointer_x = event.position.x - event.relative.x
		if event.index == pointer_id:
			drag_to(event.position.x)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer_id == -1 and event.position.y > top_inset + 110:
			pointer_id = -2
			previous_pointer_x = event.position.x
		elif not event.pressed and pointer_id == -2:
			pointer_id = -1
	elif event is InputEventMouseMotion and pointer_id == -2:
		drag_to(event.position.x)

## Apply finger displacement to the steering target instead of teleporting the ship beneath the finger.
func drag_to(x: float) -> void:
	ship.target_x = clampf(ship.target_x + x - previous_pointer_x, 35.0, arena.x - 35.0)
	previous_pointer_x = x

## Pause when the application loses focus or moves to the background.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if is_instance_valid(interface) and interface.is_inside_tree():
			pause_run()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		progress.save()

## Submit this object's visual geometry in local coordinates. Physics and collision rules are handled separately.
func _draw() -> void:
	if state == State.MENU:
		var center := Vector2(arena.x * 0.5, arena.y * 0.475)
		draw_arc(center, 106, 0.0, TAU, 90, Color("203248"), 1, true)
		draw_arc(center, 130, visual_time * 0.15, visual_time * 0.15 + PI * 1.15, 80, Color("284856"), 1, true)
		draw_circle(center + Vector2.from_angle(visual_time * 0.15) * 130, 3, Color("55e8d0"))
	for particle in particles:
		var tint: Color = particle.tint
		tint.a = particle.life / particle.duration
		draw_circle(particle.position, particle.radius, tint)
