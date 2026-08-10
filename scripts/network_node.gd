extends Node3D
class_name NetworkNode
## One graph node, drawn as a stylized server rack (see `ServerRack`). This script
## owns only the STATE → STRIP COLOR mapping and click detection; the rack itself
## handles the geometry and idle animation. `Level` drives role (normal/target) and
## the per-tick vision highlight; the violet "you are here" tint is read straight
## from `GameState.player_node` (read-only — the tick loop is never touched).

signal clicked(id: int)

enum Role { NORMAL, TARGET }

## Centralized state palette: [color, base_energy, pulse_amp, pulse_speed].
## The strip (and its light) is the only bright thing on the rack, so state reads
## purely as a change of this one accent against the dark chassis.
const S_NORMAL := { "color": Color(0.16, 0.45, 0.95), "energy": 1.4, "amp": 0.12, "speed": 1.4 }
const S_TARGET := { "color": Color(0.15, 0.95, 0.6), "energy": 1.9, "amp": 0.3, "speed": 2.2 }
const S_PLAYER := { "color": Color(0.486, 0.361, 1.0), "energy": 2.4, "amp": 0.35, "speed": 2.6 }
const S_VISION := { "color": Color(1.0, 0.24, 0.2), "energy": 2.7, "amp": 0.6, "speed": 6.0 }

var id: int = -1
var neighbors: PackedInt32Array = PackedInt32Array()

@onready var _rack: ServerRack = $Rack
@onready var _area: Area3D = $Area3D

var _role: int = Role.NORMAL
var _highlighted: bool = false
var _is_player: bool = false


func setup(node_id: int, neighbor_ids: PackedInt32Array) -> void:
	id = node_id
	neighbors = neighbor_ids


func set_role(role: int) -> void:
	_role = role
	_apply_state()


func _ready() -> void:
	_area.input_event.connect(_on_area_input_event)
	_apply_state()


func set_highlight(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	_apply_state()


func _apply_state() -> void:
	if _rack == null:
		return
	# Priority: guard vision (danger) > player node (you) > target > neutral.
	var s: Dictionary
	if _highlighted:
		s = S_VISION
	elif _is_player:
		s = S_PLAYER
	elif _role == Role.TARGET:
		s = S_TARGET
	else:
		s = S_NORMAL
	_rack.set_state(s.color, s.energy, s.amp, s.speed)


func _process(_delta: float) -> void:
	# Reflect "player is standing here" as a state change only when it flips, so the
	# rack's own animation isn't restarted every frame.
	var here := id == GameState.player_node
	if here != _is_player:
		_is_player = here
		_apply_state()


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(id)
