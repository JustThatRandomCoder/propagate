extends Node3D
class_name NetworkNode
## One graph node, drawn as a clean coloured board piece (see `NodePiece`). This
## script owns only the STATE → COLOUR mapping and click detection; the piece
## handles geometry and the colour ease. `Level` drives role (normal/target) and
## the per-tick vision highlight; the player "you are here" colour is read straight
## from `GameState.player_node` (read-only — the tick loop is never touched).

signal clicked(id: int)

enum Role { NORMAL, TARGET }

## Centralized, flat light-mode palette. Priority: vision > player > target > neutral.
const C_NORMAL := Color(0.63, 0.69, 0.79)
const C_TARGET := Color(0.24, 0.72, 0.46)
const C_PLAYER := Color(0.44, 0.38, 0.86)
const C_VISION := Color(0.92, 0.36, 0.36)

var id: int = -1
var neighbors: PackedInt32Array = PackedInt32Array()

@onready var _piece: NodePiece = $Piece
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
	if _piece == null:
		return
	var color: Color
	if _highlighted:
		color = C_VISION
	elif _is_player:
		color = C_PLAYER
	elif _role == Role.TARGET:
		color = C_TARGET
	else:
		color = C_NORMAL
	_piece.set_state(color)


func _process(_delta: float) -> void:
	# Reflect "player is standing here" as a state change only when it flips.
	var here := id == GameState.player_node
	if here != _is_player:
		_is_player = here
		_apply_state()


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(id)
