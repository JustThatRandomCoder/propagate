extends Node3D
class_name Level
## Main scene. Loads a LevelData, builds the graph (nodes + edges), spawns the
## Player and Guard, and orchestrates the tick loop from the top. This is the ONLY
## place the tick resolution order lives — keep it exactly as specified in CLAUDE.md.

@export var level_data: LevelData
@export var node_scene: PackedScene
@export var edge_scene: PackedScene
@export var player_scene: PackedScene
@export var guard_scene: PackedScene

@onready var _nodes_root: Node3D = $Nodes
@onready var _edges_root: Node3D = $Edges

## node id -> NetworkNode instance
var _nodes: Dictionary = {}
## node id -> PackedInt32Array of neighbour ids (derived from edges)
var _adjacency: Dictionary = {}
## [{ edge: Edge, a: int, b: int }, …] — for highlighting the vision cross
var _edges: Array = []

var _player: Player
var _guard: Guard
var _input_locked: bool = true


func _ready() -> void:
	assert(level_data != null, "Level requires a LevelData resource.")
	GameState.reset(level_data.player_start)
	_build_adjacency()
	_build_nodes()
	_build_edges()
	_spawn_player()
	_spawn_guard()
	# Show the guard's starting vision so the first move can be planned.
	_apply_vision(_guard.current_node())
	_input_locked = false


# --- Graph construction -----------------------------------------------------

func _build_adjacency() -> void:
	for i in level_data.node_positions.size():
		_adjacency[i] = PackedInt32Array()
	for e in level_data.edges:
		_add_neighbor(e.x, e.y)
		_add_neighbor(e.y, e.x)


func _add_neighbor(from: int, to: int) -> void:
	var arr: PackedInt32Array = _adjacency[from]
	if to not in arr:
		arr.append(to)
		_adjacency[from] = arr


func _build_nodes() -> void:
	for i in level_data.node_positions.size():
		var node: NetworkNode = node_scene.instantiate()
		_nodes_root.add_child(node)
		node.setup(i, _adjacency[i])
		node.global_position = level_data.node_positions[i]
		node.clicked.connect(_on_node_clicked)
		_nodes[i] = node
	if _nodes.has(level_data.target_node):
		_nodes[level_data.target_node].set_role(NetworkNode.Role.TARGET)


func _build_edges() -> void:
	for e in level_data.edges:
		var edge: Edge = edge_scene.instantiate()
		_edges_root.add_child(edge)
		edge.span(level_data.node_positions[e.x], level_data.node_positions[e.y])
		_edges.append({ "edge": edge, "a": e.x, "b": e.y })


func _spawn_player() -> void:
	_player = player_scene.instantiate()
	add_child(_player)
	_player.place_at(level_data.node_positions[level_data.player_start])


func _spawn_guard() -> void:
	_guard = guard_scene.instantiate()
	add_child(_guard)
	_guard.setup(level_data.guard_patrol, level_data.guard_start_index)
	_guard.place_at(level_data.node_positions[_guard.current_node()])


# --- Vision -----------------------------------------------------------------

## Guard vision = its current node + all nodes directly connected to it by an edge.
func _guard_vision(guard_node: int) -> PackedInt32Array:
	var vision := PackedInt32Array([guard_node])
	for n in _adjacency[guard_node]:
		vision.append(n)
	return vision


## Highlight the guard's vision this tick: the vision nodes red, and the edges of
## the vision cross (those incident to the guard's node) hot.
func _apply_vision(guard_node: int) -> void:
	var vision := _guard_vision(guard_node)
	for id in _nodes:
		_nodes[id].set_highlight(id in vision)
	for entry in _edges:
		var incident: bool = entry.a == guard_node or entry.b == guard_node
		entry.edge.set_highlight(incident)


# --- Tick loop --------------------------------------------------------------

func _is_adjacent(from: int, to: int) -> bool:
	return to in _adjacency[from]


func _on_node_clicked(node_id: int) -> void:
	if _input_locked or GameState.game_over:
		return
	if not _is_adjacent(GameState.player_node, node_id):
		return
	_resolve_tick(node_id)


func _resolve_tick(target_id: int) -> void:
	_input_locked = true

	# 1 & 2: player moves to the clicked adjacent node, then tick increments.
	await _player.move_to(level_data.node_positions[target_id])
	GameState.player_node = target_id
	GameState.advance_tick()

	# 3 & 4: guard advances along its route and tweens there.
	var guard_target := _guard.advance()
	await _guard.move_to(level_data.node_positions[guard_target])

	# 5: compute + highlight this tick's vision (never during tweens).
	var vision := _guard_vision(_guard.current_node())
	_apply_vision(_guard.current_node())

	# 6: detection.
	if GameState.player_node in vision:
		GameState.spot_player()
		return

	# 7: win.
	if GameState.player_node == level_data.target_node:
		GameState.win_level()
		return

	# 8: unlock and wait for the next click.
	_input_locked = false
