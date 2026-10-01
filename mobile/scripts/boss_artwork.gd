extends Node2D
## Reference-matched, pre-rendered armor on a small 2D mesh. The subdivision
## lets detached ring sections float without moving hitboxes or attack origins.
## Only one textured surface and one pooled smoke surface exist per live boss.
const TEXTURES := {
	"black": preload("res://assets/bosses/black-hole.png"),
	"white": preload("res://assets/bosses/white-hole.png"),
	"asteroid": preload("res://assets/bosses/asteroid-forge.png")
}
const Finish = preload("res://shaders/boss_hull.gdshader")
const Damage = preload("res://scripts/hull_damage.gd")
const SIZE := 272.0
const GRID := 16
var kind := "black"
var surface: MeshInstance2D
var finish: ShaderMaterial
var damage_visual: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	surface = MeshInstance2D.new()
	surface.texture = TEXTURES.get(kind, TEXTURES.black)
	surface.mesh = make_mesh()
	finish = ShaderMaterial.new()
	finish.shader = Finish
	finish.set_shader_parameter("boss_kind", 0 if kind == "black" else (1 if kind == "white" else 2))
	surface.material = finish
	add_child(surface)
	damage_visual = Damage.new()
	add_child(damage_visual)
	damage_visual.configure(Vector2.ONE * SIZE * 0.72, false)

## A fixed 16x16 grid provides smooth cosmetic motion with bounded GPU cost.
func make_mesh() -> ArrayMesh:
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in range(GRID + 1):
		for x in range(GRID + 1):
			var uv := Vector2(x, y) / float(GRID)
			uvs.append(uv)
			vertices.append((uv - Vector2.ONE * 0.5) * SIZE)
	for y in range(GRID):
		for x in range(GRID):
			var i := y * (GRID + 1) + x
			indices.append_array(PackedInt32Array([i, i+1, i+GRID+1, i+1, i+GRID+2, i+GRID+1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

## Damage spreads over fractions of boss health, never individual player hits.
## The core flickers, armor scars, then smoke develops as the hull weakens.
func refresh(clock: float, remaining: float, flash: float, charging: bool, delta: float = 0.0) -> void:
	if not is_instance_valid(surface):
		return
	var wear := clampf((1.0 - remaining) * 2.8, 0.0, 2.0)
	finish.set_shader_parameter("visual_time", clock)
	finish.set_shader_parameter("hull_damage", wear)
	finish.set_shader_parameter("damage_time", clock)
	finish.set_shader_parameter("hit_flash", clampf(flash / 0.07, 0.0, 1.0))
	finish.set_shader_parameter("charging", 1.0 if charging else 0.0)
	damage_visual.advance(delta, 2 if remaining <= 0.36 else (1 if remaining <= 0.72 else 0))
