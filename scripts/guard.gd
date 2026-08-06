extends Node3D
class_name Guard
## Marker mesh that walks a fixed patrol route of node ids. `advance()` steps the
## route index (wrapping) and returns the new node id; `move_to` tweens awaitably.
## Vision is computed by `Level` (it needs the graph adjacency), not here.

const MOVE_TIME := 0.35

var patrol_route: PackedInt32Array = PackedInt32Array()
var _index: int = 0

@onready var _mesh: MeshInstance3D = $Mesh


func setup(route: PackedInt32Array, start_index: int) -> void:
	patrol_route = route
	_index = start_index


## The node id the guard currently occupies.
func current_node() -> int:
	return patrol_route[_index]


func place_at(pos: Vector3) -> void:
	global_position = pos


## Step to the next route entry (wrapping) and return its node id.
func advance() -> int:
	_index = (_index + 1) % patrol_route.size()
	return current_node()


## Tween to `pos`; returns after the tween finishes so callers can `await` it.
func move_to(pos: Vector3) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", pos, MOVE_TIME)
	await tween.finished
