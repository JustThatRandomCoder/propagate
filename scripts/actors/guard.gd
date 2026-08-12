extends Node3D
class_name Guard
## The patrolling security process, drawn as a taller rounded amber sentinel so it
## is unmistakable against the square nodes and the red scan it casts. `advance()`
## steps the fixed patrol route (wrapping) and returns the new node id; `move_to`
## tweens the ROOT awaitably. The idle bob lives on the `Bob` child so it never
## fights the movement tween. Vision is computed by `Level`, not here.

const MOVE_TIME := 0.35
const BOB_AMP := 0.05
const BOB_SPEED := 1.7
const DROP_HEIGHT := 3.4
const DROP_TIME := 0.55

var patrol_route: PackedInt32Array = PackedInt32Array()
var _index: int = 0

@onready var _bob: Node3D = $Bob

var _base_y: float = 0.0


func _ready() -> void:
	_base_y = _bob.position.y


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


## Drop the sentinel in from above with a gravity-like bounce, after an optional delay.
func drop_in(delay: float = 0.0) -> void:
	var base := position.y
	position.y = base + DROP_HEIGHT
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(self, "position:y", base, DROP_TIME) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


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
