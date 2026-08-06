extends Node3D
class_name Edge
## A thin emissive box stretched between two node positions — a glowing data link.
## Purely visual. `Level` toggles `set_highlight` on edges along the guard's vision
## cross. Nodes lie on the XZ plane, so orientation is a simple yaw around Y.

const THICKNESS := 0.06
const C_IDLE := Color(0.16, 0.5, 0.62)
const C_HOT := Color(1.0, 0.35, 0.26)

@onready var _mesh: MeshInstance3D = $Mesh

var _material: StandardMaterial3D
var _hot: bool = false
var _phase: float = 0.0


func span(from: Vector3, to: Vector3) -> void:
	_phase = randf() * TAU
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)

	var box := BoxMesh.new()
	box.size = Vector3(length, THICKNESS, THICKNESS)
	_mesh.mesh = box

	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.albedo_color = C_IDLE.darkened(0.6)
	_material.emission = C_IDLE
	_material.emission_energy_multiplier = 1.0
	_mesh.material_override = _material

	global_position = mid
	# Align local +X (the box's length axis) with the direction to `to`.
	var dir := to - from
	rotation = Vector3(0.0, atan2(-dir.z, dir.x), 0.0)


func set_highlight(on: bool) -> void:
	if on == _hot or _material == null:
		return
	_hot = on
	_material.emission = C_HOT if on else C_IDLE
	if not on:
		_material.emission_energy_multiplier = 1.0


func _process(_delta: float) -> void:
	if _material == null or not _hot:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_material.emission_energy_multiplier = 2.4 + 0.8 * sin(t * 6.0 + _phase)
