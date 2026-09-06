extends ColorRect
## One background-only refraction pass; actors and HUD draw above this layer.

const MAX_LENSES := 8
const MAX_STRANDS := 6
const FoldShader = preload("res://shaders/space_folds.gdshader")
var lens_count := 0
var strand_count := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -20
	material = ShaderMaterial.new()
	material.shader = FoldShader

func update_effects(game: Node2D) -> void:
	size = game.arena
	var lenses := PackedVector4Array()
	var styles := PackedVector4Array()
	var strands := PackedVector4Array()
	var strand_styles := PackedVector4Array()
	var boss: Node2D = game.boss
	if is_instance_valid(boss) and boss.visible:
		if boss.kind in ["black", "white"] and boss.phase in ["warning", "active"]:
			var active: bool = boss.phase == "active"
			lenses.append(Vector4(boss.well_position.x, boss.well_position.y, 164.0 if active else 112.0, 1.0 if active else 0.3))
			styles.append(Vector4(31.0 if active else 25.0, 1.0 if boss.kind == "white" else -1.0, 0.0, boss.animation_time))
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
				styles.append(Vector4(rock.radius * 0.85, -1.0, 1.0, boss.animation_time))
			if rock.fold_life > 0.0 and strands.size() < MAX_STRANDS:
				var alpha: float = rock.fold_life / rock.RELEASE_FADE_SECONDS
				strands.append(Vector4(rock.fold_origin.x, rock.fold_origin.y, rock.position.x, rock.position.y))
				strand_styles.append(Vector4(16.0 + rock.radius * 0.2, alpha, boss.animation_time, -1.0))
		for enemy in game.enemies:
			if not enemy.summoned or enemy.fold_life <= 0.0:
				continue
			if lenses.size() < MAX_LENSES:
				lenses.append(Vector4(enemy.position.x, enemy.position.y, 58.0, 0.5))
				styles.append(Vector4(22.0, -1.0, 1.0, boss.animation_time))
			if strands.size() < MAX_STRANDS:
				strands.append(Vector4(enemy.fold_origin.x, enemy.fold_origin.y, enemy.position.x, enemy.position.y))
				strand_styles.append(Vector4(20.0, enemy.fold_life / enemy.RELEASE_FADE_SECONDS, boss.animation_time, -1.0))
	lens_count = lenses.size()
	strand_count = strands.size()
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
	visible = lens_count > 0 or strand_count > 0
