extends Node3D
class_name ServerRack
## A stylized server-rack node built entirely from primitives (BoxMesh only).
## Dark, near-black metal chassis + stacked blades; the ONE bright thing is the
## emissive vertical status strip, which carries the node's STATE COLOR and is the
## rack's main light source (a shadowless OmniLight tied to the strip). Two tiny
## LEDs blink slowly to sell the "live hardware" read.
##
## Purely visual and reusable: `NetworkNode` and `Guard` both instance this scene
## and drive it through `set_state(color, energy, pulse_amp, pulse_speed)`. The rack
## owns its own idle animation (strip pulse + LED blink), so owners only push a new
## state when it actually changes.

@onready var _strip: MeshInstance3D = $Visual/Strip
@onready var _light: OmniLight3D = $Visual/StripLight
@onready var _leds: Array = [$Visual/Led0, $Visual/Led1, $Visual/Led2]

var _strip_mat: StandardMaterial3D
var _led_mats: Array = []

# Current state (set by the owner via set_state).
var _color: Color = Color(0.16, 0.45, 0.95)
var _energy: float = 1.4
var _pulse_amp: float = 0.12
var _pulse_speed: float = 1.4

var _phase: float = 0.0
var _led_phases: Array = []


func _ready() -> void:
	_phase = randf() * TAU
	# Per-instance strip material so recoloring one rack never touches the others.
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.emission_enabled = true
	_strip_mat.metallic = 0.0
	_strip_mat.roughness = 0.4
	_strip.material_override = _strip_mat

	for led in _leds:
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.metallic = 0.0
		m.roughness = 0.5
		led.material_override = m
		_led_mats.append(m)
		_led_phases.append(randf() * TAU)

	_apply_base()


## Push a new visual state. Only call this when the state actually changes — the
## rack animates itself every frame from these parameters.
func set_state(color: Color, energy: float, pulse_amp: float, pulse_speed: float) -> void:
	_color = color
	_energy = energy
	_pulse_amp = pulse_amp
	_pulse_speed = pulse_speed
	_apply_base()


func _apply_base() -> void:
	if _strip_mat == null:
		return
	# Dark tinted body glass behind the light, bright emissive on top.
	_strip_mat.albedo_color = _color.darkened(0.8)
	_strip_mat.emission = _color
	if _light != null:
		_light.light_color = _color
	for m in _led_mats:
		m.albedo_color = _color.darkened(0.7)
		m.emission = _color


func _process(_delta: float) -> void:
	if _strip_mat == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var wave := sin(t * _pulse_speed + _phase)
	var strip_energy: float = max(0.0, _energy + _pulse_amp * wave)
	_strip_mat.emission_energy_multiplier = strip_energy
	if _light != null:
		_light.light_energy = strip_energy * 0.5

	# Slow, offset blink on the tiny status LEDs.
	for i in _led_mats.size():
		var blink := 0.5 + 0.5 * sin(t * 2.2 + _led_phases[i])
		_led_mats[i].emission_energy_multiplier = 0.6 + 2.4 * blink
