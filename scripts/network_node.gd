extends Node3D
class_name NetworkNode
## One graph node: a mesh + an Area3D for click detection + its data.
## Emits `clicked(id)` when its Area3D is clicked. `Level` wires this up.

signal clicked(id: int)

const COLOR_IDLE := Color(0.30, 0.55, 0.85)
const COLOR_HIGHLIGHT := Color(0.90, 0.20, 0.25)

var id: int = -1
var neighbors: PackedInt32Array = PackedInt32Array()

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _area: Area3D = $Area3D

var _material: StandardMaterial3D


func setup(node_id: int, neighbor_ids: PackedInt32Array) -> void:
	id = node_id
	neighbors = neighbor_ids


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_IDLE
	_mesh.material_override = _material
	_area.input_event.connect(_on_area_input_event)


func set_highlight(on: bool) -> void:
	if _material == null:
		return
	_material.albedo_color = COLOR_HIGHLIGHT if on else COLOR_IDLE


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(id)
