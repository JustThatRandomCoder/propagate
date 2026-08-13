extends Node
## Endless, escalating progression. Autoload singleton. The first few levels are
## the authored `res://levels/level_*.tres` (a gentle intro); after those it hands
## out procedurally generated levels of ever-rising difficulty (see
## `LevelGenerator`). A per-run seed makes every playthrough different, while a
## given level index is deterministic within the run — so getting caught and
## retrying gives the *same* board, not a new one. Holds only the index + seed.

var _authored: PackedStringArray = PackedStringArray()
var _index: int = 0
var _run_seed: int = 0
var _rng := RandomNumberGenerator.new()
var _cache_index: int = -1
var _cache_level: LevelData = null


func _ready() -> void:
	_scan_authored()
	_run_seed = randi()


func _scan_authored() -> void:
	var found: Array[String] = []
	var dir := DirAccess.open("res://levels")
	if dir != null:
		for f in dir.get_files():
			var name := f
			if name.ends_with(".remap"):
				name = name.trim_suffix(".remap")
			if name.begins_with("level_") and name.ends_with(".tres"):
				var p := "res://levels/" + name
				if p not in found:
					found.append(p)
	found.sort()
	_authored = PackedStringArray(found)


## The LevelData for the current level: authored while within the intro, then
## procedurally generated. Cached so a retry (scene reload) reuses the same board.
func current_level() -> LevelData:
	if _index == _cache_index and _cache_level != null:
		return _cache_level
	var ld: LevelData
	if _index < _authored.size():
		ld = load(_authored[_index]) as LevelData
	else:
		# Start the generated run already hard, then ramp steeply.
		var difficulty := _index - _authored.size() + 2
		_rng.seed = _run_seed + _index * 1000003
		ld = LevelGenerator.generate(difficulty, _rng)
	_cache_index = _index
	_cache_level = ld
	return ld


## 1-based number of the current level, for display.
func level_number() -> int:
	return _index + 1


## True once the current level is procedurally generated (past the authored intro).
func is_procedural() -> bool:
	return _index >= _authored.size()


## Endless — there is always a next (harder) level.
func has_next() -> bool:
	return true


func advance() -> bool:
	_index += 1
	return true


func reset_to_first() -> void:
	_index = 0
