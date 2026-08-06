extends Node3D
class_name NetworkNode
## One graph node: an emissive mesh + an Area3D for click detection + its data.
## Emits `clicked(id)` when its Area3D is clicked. `Level` wires this up and drives
## role (normal/target) and the per-tick vision highlight. Visuals only here.

signal clicked(id: int)

enum Role { NORMAL, TARGET }

const C_NORMAL := Color(0.12, 0.62, 0.95)
const C_TARGET := Color(0.22, 1.0, 0.55)
const C_VISION := Color(1.0, 0.30, 0.24)

var id: int = -1
var neighbors: PackedInt32Array = PackedInt32Array()

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _area: Area3D = $Area3D

var _role: int = Role.NORMAL
var _highlighted: bool = false
var _material: StandardMaterial3D
var _phase: float = 0.0
# Pulse tuning per visual state: base energy, amplitude, speed, scale wobble.
var _base_energy: float = 1.0
var _amp: float = 0.25
var _speed: float = 2.0
var _scale_amp: float = 0.0


func setup(node_id: int, neighbor_ids: PackedInt32Array) -> void:
	id = node_id
	neighbors = neighbor_ids


func set_role(role: int) -> void:
	_role = role
	_apply_state()


func _ready() -> void:
	_phase = randf() * TAU
	_material = StandardMaterial3D.new()
	_material.metallic = 0.2
	_material.roughness = 0.35
	_material.emission_enabled = true
	_mesh.material_override = _material
	_apply_state()
	_area.input_event.connect(_on_area_input_event)


func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	_apply_state()


func _apply_state() -> void:
	if _material == null:
		return
	var color: Color
	if _highlighted:
		color = C_VISION
		_base_energy = 2.2
		_amp = 0.9
		_speed = 6.5
		_scale_amp = 0.06
	elif _role == Role.TARGET:
		color = C_TARGET
		_base_energy = 1.7
		_amp = 0.55
		_speed = 3.0
		_scale_amp = 0.05
	else:
		color = C_NORMAL
		_base_energy = 1.0
		_amp = 0.25
		_speed = 2.0
		_scale_amp = 0.0
	_material.albedo_color = color.darkened(0.75)
	_material.emission = color


func _process(_delta: float) -> void:
	if _material == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var wave := sin(t * _speed + _phase)
	_material.emission_energy_multiplier = _base_energy + _amp * wave
	if _scale_amp > 0.0:
		var s := 1.0 + _scale_amp * wave
		_mesh.scale = Vector3(s, s, s)
	elif _mesh.scale != Vector3.ONE:
		_mesh.scale = Vector3.ONE


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(id)
