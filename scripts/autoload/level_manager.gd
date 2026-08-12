extends Node
## Ordered level progression. Autoload singleton. Discovers every
## `res://levels/level_*.tres` at startup, sorted by filename, and tracks which
## one is current so a scene reload loads the right level. Adding a new level is
## still just dropping a `level_NN.tres` in `levels/` — no code changes, matching
## the data-driven rule. Holds only the index + the path list; no scene refs.

var _paths: PackedStringArray = PackedStringArray()
var _index: int = 0


func _ready() -> void:
	_scan()


func _scan() -> void:
	var found: Array[String] = []
	var dir := DirAccess.open("res://levels")
	if dir != null:
		for f in dir.get_files():
			var name := f
			# Exported builds may list resources as `*.tres.remap`.
			if name.ends_with(".remap"):
				name = name.trim_suffix(".remap")
			if name.begins_with("level_") and name.ends_with(".tres"):
				var p := "res://levels/" + name
				if p not in found:
					found.append(p)
	found.sort()
	_paths = PackedStringArray(found)


## The LevelData for the current level, or null if none were found.
func current_level() -> LevelData:
	if _paths.is_empty():
		return null
	return load(_paths[_index]) as LevelData


## 1-based number of the current level, for display.
func level_number() -> int:
	return _index + 1


func total() -> int:
	return _paths.size()


func has_next() -> bool:
	return _index < _paths.size() - 1


## Advance to the next level if there is one; returns whether it advanced.
func advance() -> bool:
	if has_next():
		_index += 1
		return true
	return false


func reset_to_first() -> void:
	_index = 0
