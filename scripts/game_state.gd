extends Node
## Global run state for a single level attempt.
##
## Autoload singleton. Holds only state + signals — no scene references, no graph
## data. `Level` reads/writes these fields and reacts to the signals.

signal player_spotted
signal level_won
signal tick_advanced(tick: int)

var player_node: int = -1
var tick: int = 0
var game_over: bool = false
var won: bool = false


## Reset all state. Called by `Level` when it (re)builds a level.
func reset(start_node: int) -> void:
	player_node = start_node
	tick = 0
	game_over = false
	won = false


func advance_tick() -> void:
	tick += 1
	tick_advanced.emit(tick)


func spot_player() -> void:
	game_over = true
	player_spotted.emit()


func win_level() -> void:
	game_over = true
	won = true
	level_won.emit()
