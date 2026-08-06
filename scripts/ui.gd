extends CanvasLayer
class_name UI
## Two status overlays: "Detected — restarting" and "Level Complete".
## Restart reloads the current scene.

const RESTART_DELAY := 1.0

@onready var _detected: Label = $Detected
@onready var _complete: Label = $Complete


func _ready() -> void:
	_detected.visible = false
	_complete.visible = false
	GameState.player_spotted.connect(_on_player_spotted)
	GameState.level_won.connect(_on_level_won)


func _on_player_spotted() -> void:
	_detected.visible = true
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()


func _on_level_won() -> void:
	_complete.visible = true
