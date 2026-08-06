extends Node3D
class_name Player
## Marker mesh sitting on the current node. `move_to` tweens and is awaitable.

const MOVE_TIME := 0.35

@onready var _mesh: MeshInstance3D = $Mesh


func place_at(pos: Vector3) -> void:
	global_position = pos


## Tween to `pos`; returns after the tween finishes so callers can `await` it.
func move_to(pos: Vector3) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", pos, MOVE_TIME)
	await tween.finished
