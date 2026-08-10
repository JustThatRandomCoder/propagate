extends Node3D
class_name Player
## Marker sitting above the current node: a small indigo core. `move_to` tweens the
## ROOT and is awaitable; a gentle idle bob lives on the `Visual` child so it never
## fights the movement tween.

const MOVE_TIME := 0.35
const BOB_AMP := 0.06
const BOB_SPEED := 2.0

@onready var _visual: Node3D = $Visual

var _base_y: float = 0.0


func _ready() -> void:
	_base_y = _visual.position.y


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_visual.position.y = _base_y + BOB_AMP * sin(t * BOB_SPEED)


func place_at(pos: Vector3) -> void:
	global_position = pos


## Tween to `pos`; returns after the tween finishes so callers can `await` it.
func move_to(pos: Vector3) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", pos, MOVE_TIME)
	await tween.finished
