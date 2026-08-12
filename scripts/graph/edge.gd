extends Node3D
class_name Edge
## A thin flat link running along the floor between two node pads — a clean board
## connection, no glow. `Level` toggles `set_highlight` on edges along the guard's
## vision cross, which swaps the link to red. Nodes lie on the XZ plane, so
## orientation is a simple yaw around Y.

const WIDTH := 0.07
const HEIGHT := 0.02
## Sits just above the floor, below the blocks, so links read as board traces.
const Y_OFFSET := 0.02
const C_IDLE := Color(0.66, 0.7, 0.78)
const C_HOT := Color(0.92, 0.36, 0.36)

@onready var _mesh: MeshInstance3D = $Mesh

var _material: StandardMaterial3D
var _tween: Tween


func span(from: Vector3, to: Vector3) -> void:
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)

	var box := BoxMesh.new()
	box.size = Vector3(length, HEIGHT, WIDTH)
	_mesh.mesh = box

	_material = StandardMaterial3D.new()
	_material.metallic = 0.0
	_material.roughness = 0.8
	_material.albedo_color = C_IDLE
	_mesh.material_override = _material

	global_position = mid + Vector3(0.0, Y_OFFSET, 0.0)
	# Align local +X (the box's length axis) with the direction to `to`.
	var dir := to - from
	rotation = Vector3(0.0, atan2(-dir.z, dir.x), 0.0)


func set_highlight(on: bool) -> void:
	if _material == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color", C_HOT if on else C_IDLE, 0.18)
