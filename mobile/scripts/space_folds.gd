extends ColorRect
## One background-only refraction pass; actors and HUD draw above this layer.

const MAX_LENSES := 8
const MAX_STRANDS := 6
const PlayerWell = preload("res://scripts/player_well.gd")
const FoldShader = preload("res://shaders/space_folds.gdshader")
var lens_count := 0
var strand_count := 0

## Construct defaults before this object enters the scene tree; do not depend on ready child nodes here.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -20
	material = ShaderMaterial.new()
	material.shader = FoldShader

## Pack visible lens and tether geometry into fixed-size shader arrays, keeping GPU work bounded.
func update_effects(game: Node2D) -> void:
	size = game.arena
	var lenses := PackedVector4Array()
	var styles := PackedVector4Array()
	var strands := PackedVector4Array()
	var strand_styles := PackedVector4Array()
	var boss: Node2D = game.boss
	# Reserve the first lenses for player feedback. These rings must distort the
	# same starfield as the wells rather than looking like flat HUD circles.
	if game.combat.shield_time > 0.0 and lenses.size() < MAX_LENSES:
		# The shield is intentionally extreme: it should visibly drag stars and
		# nebulae around the hull even on a small, bright phone display.
		lenses.append(Vector4(game.ship.position.x, game.ship.position.y, 152.0, 13.5))
		styles.append(Vector4(47.0, 1.0, 3.0, game.visual_time))
	for pulse in game.combat.warp_pulses:
		if lenses.size() >= MAX_LENSES:
			break
		var progress: float = clampf(pulse.age / 0.42, 0.0, 1.0)
		var radius: float = 42.0 + progress * 44.0
		lenses.append(Vector4(pulse.at.x, pulse.at.y, radius + 55.0, 1.65 * (1.0 - progress)))
		styles.append(Vector4(radius, -1.0, 2.0, game.visual_time * 1.7))
	for wave in game.gravity_fields.shockwaves:
		if lenses.size() >= MAX_LENSES:
			break
		var progress: float = clampf((wave.age - 0.35) / 0.75, 0.0, 1.0)
		var radius: float = maxf(14.0, wave.radius * progress)
		lenses.append(Vector4(wave.at.x, wave.at.y, radius + 70.0, 1.8 * (1.0 - progress)))
		styles.append(Vector4(radius, 1.0, 2.0, game.visual_time))
	for effect in game.gravity_fields.exits:
		if lenses.size() >= MAX_LENSES:
			break
		var black: bool = effect.kind == "black"
		var age: float = effect.age
		var radius: float = effect.radius + clampf(age / 0.95, 0.0, 1.0) * 180.0
		if black and age < 0.55:
			radius = (effect.radius + 95.0) * (1.0 - age / 0.55)
		lenses.append(Vector4(effect.at.x, effect.at.y, radius + 75.0, 1.5 * (1.0 - age / 1.2)))
		styles.append(Vector4(maxf(radius, 2.0), -1.0 if black else 1.0, 2.0, game.visual_time))
	if is_instance_valid(boss) and game.boss_is_shielded() and lenses.size() < MAX_LENSES:
		var guards: Array = game.enemies.filter(func(enemy: Node2D) -> bool: return enemy.shield_guard)
		var shield_strength := float(guards.size()) / maxf(1.0, boss.guard_total)
		lenses.append(Vector4(boss.body_position.x, boss.body_position.y, 145.0, 0.75 + shield_strength * 0.65))
		styles.append(Vector4(76.0, 1.0, 2.0, game.visual_time * 0.65))
	for well in game.lingering_wells:
		if well.kind in ["asteroid", "swarm"] and lenses.size() < MAX_LENSES:
			var core: Vector2 = well.body_position + Vector2(0, 42)
			lenses.append(Vector4(core.x, core.y, 65.0, 0.4))
			styles.append(Vector4(15.0, -1.0, 1.0, well.animation_time))
		if well.kind not in ["black", "white"]:
			continue
		if lenses.size() >= MAX_LENSES:
			break
		if well is PlayerWell and well.phase == "warning":
			lenses.append(Vector4(well.cannon_position.x, well.cannon_position.y, 57.0, 0.85))
			styles.append(Vector4(10.0, -1.0, 1.0, well.animation_time))
			continue
		lenses.append(Vector4(well.well_position.x, well.well_position.y, 164.0 * well.well_scale, 1.0))
		styles.append(Vector4(31.0 * well.well_scale, 1.0 if well.kind == "white" else -1.0, 0.0, well.animation_time))
	if is_instance_valid(boss) and boss.visible:
		if boss.kind in ["black", "white"] and boss.phase in ["warning", "active"]:
			var active: bool = boss.phase == "active"
			lenses.append(Vector4(boss.well_position.x, boss.well_position.y, 164.0 * boss.well_scale if active else 112.0, 1.0 if active else 0.3))
			styles.append(Vector4(31.0 * boss.well_scale if active else 25.0, 1.0 if boss.kind == "white" else -1.0, 0.0, boss.animation_time))
			if boss.cannon_active:
				lenses.append(Vector4(boss.cannon_position.x, boss.cannon_position.y, 57.0, 0.85))
				styles.append(Vector4(10.0, 1.0, 1.0, boss.animation_time))
				var tail: Vector2 = boss.cannon_position - boss.cannon_velocity.normalized() * 112.0
				strands.append(Vector4(tail.x, tail.y, boss.cannon_position.x, boss.cannon_position.y))
				strand_styles.append(Vector4(20.0, 0.75, boss.animation_time, 1.0))
		elif boss.kind in ["asteroid", "swarm"] and boss.phase in ["active", "clearing"]:
			lenses.append(Vector4(boss.body_position.x, boss.body_position.y, 87.0, 0.28))
			styles.append(Vector4(36.0, -1.0, 1.0, boss.animation_time))
	for rock in game.asteroids:
		if lenses.size() < MAX_LENSES:
			var strength := 0.65 if rock.motion_phase != "flight" else 0.3
			lenses.append(Vector4(rock.position.x, rock.position.y, rock.radius + 39.0, strength))
			styles.append(Vector4(rock.radius * 0.85, -1.0, 1.0, game.visual_time))
		if rock.fold_life > 0.0 and strands.size() < MAX_STRANDS:
			var alpha: float = rock.fold_life / rock.RELEASE_FADE_SECONDS
			strands.append(Vector4(rock.fold_origin.x, rock.fold_origin.y, rock.position.x, rock.position.y))
			strand_styles.append(Vector4(16.0 + rock.radius * 0.2, alpha, game.visual_time, -1.0))
	for enemy in game.enemies:
		if not enemy.summoned or enemy.fold_life <= 0.0:
			continue
		if lenses.size() < MAX_LENSES:
			lenses.append(Vector4(enemy.position.x, enemy.position.y, 58.0, 0.5))
			styles.append(Vector4(22.0, -1.0, 1.0, game.visual_time))
		if strands.size() < MAX_STRANDS:
			strands.append(Vector4(enemy.fold_origin.x, enemy.fold_origin.y, enemy.position.x, enemy.position.y))
			strand_styles.append(Vector4(20.0, enemy.fold_life / enemy.RELEASE_FADE_SECONDS, game.visual_time, -1.0))
	lens_count = mini(lenses.size(), MAX_LENSES)
	strand_count = mini(strands.size(), MAX_STRANDS)
	lenses.resize(MAX_LENSES)
	styles.resize(MAX_LENSES)
	strands.resize(MAX_STRANDS)
	strand_styles.resize(MAX_STRANDS)
	material.set_shader_parameter("arena_size", size)
	material.set_shader_parameter("lens_count", lens_count)
	material.set_shader_parameter("lenses", lenses)
	material.set_shader_parameter("lens_styles", styles)
	material.set_shader_parameter("strand_count", strand_count)
	material.set_shader_parameter("strands", strands)
	material.set_shader_parameter("strand_styles", strand_styles)
	material.set_shader_parameter("refraction_strength", game.progress.distortion_strength)
	visible = lens_count > 0 or strand_count > 0
