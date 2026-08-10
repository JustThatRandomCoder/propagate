extends Node3D
class_name NodePiece
## One graph node drawn as a clean, flat-colored board piece: a light pad with a
## solid coloured block on top. No emission, no glow — the state reads purely from
## the block's albedo. `NetworkNode` drives it via `set_state(color)`; the colour
## eases smoothly on change so state transitions feel intentional, not flat.

const TWEEN_TIME := 0.22

@onready var _block: MeshInstance3D = $Block
@onready var _cap: MeshInstance3D = $Cap

var _block_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _color: Color = Color(0.62, 0.68, 0.78)
var _tween: Tween


func _ready() -> void:
	_block_mat = StandardMaterial3D.new()
	_block_mat.roughness = 0.55
	_block_mat.metallic = 0.0
	_block.material_override = _block_mat

	_cap_mat = StandardMaterial3D.new()
	_cap_mat.roughness = 0.4
	_cap_mat.metallic = 0.0
	_cap.material_override = _cap_mat

	_apply(_color, true)


## Set the piece colour. Eases to the new colour unless `instant`.
func set_state(color: Color) -> void:
	if color == _color:
		return
	_color = color
	_apply(color, false)


func _apply(color: Color, instant: bool) -> void:
	if _block_mat == null:
		return
	var cap := color.lightened(0.18)
	if instant:
		_block_mat.albedo_color = color
		_cap_mat.albedo_color = cap
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_block_mat, "albedo_color", color, TWEEN_TIME)
	_tween.tween_property(_cap_mat, "albedo_color", cap, TWEEN_TIME)
