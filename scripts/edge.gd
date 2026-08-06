extends Node3D
class_name Edge
## A thin box stretched between two node positions. Purely visual, no logic.
## Nodes lie on the XZ plane, so edges are oriented by a simple yaw around Y.

const THICKNESS := 0.08
const COLOR := Color(0.35, 0.40, 0.50)

@onready var _mesh: MeshInstance3D = $Mesh


func span(from: Vector3, to: Vector3) -> void:
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)

	var box := BoxMesh.new()
	box.size = Vector3(length, THICKNESS, THICKNESS)
	_mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	_mesh.material_override = mat

	global_position = mid
	# Align local +X (the box's length axis) with the direction to `to`.
	var dir := to - from
	rotation = Vector3(0.0, atan2(-dir.z, dir.x), 0.0)
