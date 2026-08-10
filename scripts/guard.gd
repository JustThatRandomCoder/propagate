extends Node3D
class_name Guard
## The patrolling security process, drawn as a taller server rack with a warm amber
## status strip so it is unmistakable against the red scan it casts on nearby nodes.
## `advance()` steps the fixed patrol route (wrapping) and returns the new node id;
## `move_to` tweens the ROOT awaitably. The idle bob lives on the `Bob` child so it
## never fights the movement tween. Vision is computed by `Level`, not here.

const MOVE_TIME := 0.35
const BOB_AMP := 0.04
const BOB_SPEED := 1.6

## Warm amber, animated a touch faster than the nodes to read as "actively scanning".
const AMBER := Color(1.0, 0.62, 0.16)

var patrol_route: PackedInt32Array = PackedInt32Array()
var _index: int = 0

@onready var _bob: Node3D = $Bob
@onready var _rack: ServerRack = $Bob/Rack

var _base_y: float = 0.0


func _ready() -> void:
	_base_y = _bob.position.y
	_rack.set_state(AMBER, 2.4, 0.5, 4.0)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_bob.position.y = _base_y + BOB_AMP * sin(t * BOB_SPEED)


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
