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
	# Prefer the current level from the progression manager; the exported
	# resource stays as a fallback for opening the scene directly in the editor.
	var managed := LevelManager.current_level()
	if managed != null:
		level_data = managed
	assert(level_data != null, "Level requires a LevelData resource.")
	GameState.reset(level_data.player_start)
	# Physics flourish when caught (game-over only, so non-determinism is safe).
	GameState.player_spotted.connect(_on_player_spotted)
	_build_adjacency()
	_build_nodes()
	_build_edges()
	_spawn_player()
	_spawn_guard()
	# Cosmetic gravity drop-in; input stays locked until everything settles.
	await _drop_in_all()
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


# --- Intro ------------------------------------------------------------------

const DROP_STAGGER := 0.03

## Drop every tile in with a staggered gravity bounce, then the actors, and wait
## for the last one to settle. Cosmetic only — nothing here touches run state.
func _drop_in_all() -> void:
	var count := _nodes.size()
	var i := 0
	for id in _nodes:
		_nodes[id].drop_in(i * DROP_STAGGER)
		i += 1
	_player.drop_in(count * DROP_STAGGER)
	_guard.drop_in(count * DROP_STAGGER + DROP_STAGGER)
	var total := count * DROP_STAGGER + NodePiece.DROP_TIME + 0.15
	await get_tree().create_timer(total).timeout


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


# --- Detection flourish (physics) -------------------------------------------

const PLAYER_COLOR := Color(0.44, 0.38, 0.86)

## When caught, replace the player token and its node's block with RigidBody debris
## and kick them so they topple. Runs on game-over only (the scene reloads shortly
## after), so this real physics never touches the deterministic tick state.
func _on_player_spotted() -> void:
	var node_id: int = GameState.player_node
	if _nodes.has(node_id):
		var node: NetworkNode = _nodes[node_id]
		var box := BoxMesh.new()
		box.size = Vector3(0.58, 0.46, 0.58)
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		_spawn_debris(box, box_shape, node.global_position + Vector3(0, 0.36, 0), node.get_color())
		node.pop_off()

	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	var ball_shape := SphereShape3D.new()
	ball_shape.radius = 0.2
	_spawn_debris(ball, ball_shape, _player.global_position + Vector3(0, 0.85, 0), PLAYER_COLOR)
	_player.hide()


func _spawn_debris(mesh: Mesh, shape: Shape3D, at: Vector3, color: Color) -> void:
	var body := RigidBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.5
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.global_position = at
	body.apply_central_impulse(Vector3(randf_range(-1.6, 1.6), randf_range(3.2, 5.0), randf_range(-1.6, 1.6)))
	body.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0), randf_range(-9.0, 9.0))


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
