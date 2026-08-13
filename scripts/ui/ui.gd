extends CanvasLayer
class_name UI
## Status overlays + HUD. The message panel and backdrop fade in on an event;
## the HUD tracks the tick counter. Restart reloads the current scene.
## Every control ignores the mouse so the overlay never eats 3D node clicks.

const RESTART_DELAY := 1.1
const FADE_TIME := 0.35

const C_DETECTED := Color(0.85, 0.25, 0.28)
const C_COMPLETE := Color(0.15, 0.62, 0.36)

@onready var _backdrop: ColorRect = $Backdrop
@onready var _message: CenterContainer = $MessageCenter
@onready var _panel_border: PanelContainer = $MessageCenter/Panel
@onready var _title: Label = $MessageCenter/Panel/VBox/Title
@onready var _subtitle: Label = $MessageCenter/Panel/VBox/Subtitle
@onready var _hud: Label = $Hud


func _ready() -> void:
	_backdrop.modulate.a = 0.0
	_message.visible = false
	_message.modulate.a = 0.0
	_update_hud(0)
	GameState.player_spotted.connect(_on_player_spotted)
	GameState.level_won.connect(_on_level_won)
	GameState.tick_advanced.connect(_update_hud)


func _update_hud(tick: int) -> void:
	var tag := "  ✦" if LevelManager.is_procedural() else ""
	_hud.text = "LVL %d%s   ·   TICK %02d" % [LevelManager.level_number(), tag, tick]


func _on_player_spotted() -> void:
	_show("DETECTED", "Reinitializing process…", C_DETECTED)
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()


func _on_level_won() -> void:
	if LevelManager.has_next():
		_show("LEVEL COMPLETE", "Advancing to the next cluster…", C_COMPLETE)
		await get_tree().create_timer(RESTART_DELAY).timeout
		LevelManager.advance()
		get_tree().reload_current_scene()
	else:
		_show("ALL CLEAR", "Every cluster breached undetected", C_COMPLETE)


func _show(title: String, subtitle: String, color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_message.visible = true

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, FADE_TIME)
	tween.tween_property(_message, "modulate:a", 1.0, FADE_TIME)
	# Subtle rise as it fades in.
	_panel_border.position.y = 14.0
	tween.tween_property(_panel_border, "position:y", 0.0, FADE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
