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
var _guards: Array[Guard] = []
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
	_build_floor()
	_build_nodes()
	_build_edges()
	_spawn_player()
	_spawn_guards()
	# Cosmetic gravity drop-in; input stays locked until everything settles.
	await _drop_in_all()
	# Show the guards' starting vision so the first move can be planned.
	_apply_vision()
	_input_locked = false


# --- Floor (Godot GridMap of tiles) -----------------------------------------

const CELL := 1.5
const TILE_LIGHT := Color(0.9, 0.93, 0.97)
const TILE_DARK := Color(0.76, 0.8, 0.86)

## Lay a checkerboard floor with a GridMap (Godot's 3D tile node). Node positions
## sit on a CELL-unit grid, so tiles align under them; we cover the board's cell
## bounds plus a one-cell margin. Purely visual.
func _build_floor() -> void:
	var gm := GridMap.new()
	gm.cell_size = Vector3(CELL, 0.5, CELL)
	gm.cell_center_x = false
	gm.cell_center_y = false
	gm.cell_center_z = false
	gm.mesh_library = _make_tile_library()
	add_child(gm)
	gm.position.y = -0.04

	var min_c := 1 << 30
	var max_c := -(1 << 30)
	var min_r := 1 << 30
	var max_r := -(1 << 30)
	for pos in level_data.node_positions:
		var c := roundi(pos.x / CELL)
		var r := roundi(pos.z / CELL)
		min_c = mini(min_c, c)
		max_c = maxi(max_c, c)
		min_r = mini(min_r, r)
		max_r = maxi(max_r, r)
	for r in range(min_r - 1, max_r + 2):
		for c in range(min_c - 1, max_c + 2):
			gm.set_cell_item(Vector3i(c, 0, r), (c + r) & 1)


func _make_tile_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	lib.create_item(0)
	lib.set_item_mesh(0, _tile_mesh(TILE_LIGHT))
	lib.create_item(1)
	lib.set_item_mesh(1, _tile_mesh(TILE_DARK))
	return lib


func _tile_mesh(color: Color) -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(CELL - 0.08, 0.08, CELL - 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.9
	m.material = mat
	return m


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


func _spawn_guards() -> void:
	for pair in level_data.all_guards():
		var guard: Guard = guard_scene.instantiate()
		add_child(guard)
		guard.setup(pair[0], pair[1])
		guard.place_at(level_data.node_positions[guard.current_node()])
		_guards.append(guard)


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
	var gi := 1
	for guard in _guards:
		guard.drop_in(count * DROP_STAGGER + gi * DROP_STAGGER)
		gi += 1
	var total := count * DROP_STAGGER + NodePiece.DROP_TIME + 0.15
	await get_tree().create_timer(total).timeout


# --- Vision -----------------------------------------------------------------

## Combined vision = the union over every guard of (its node + adjacent nodes).
func _combined_vision() -> Dictionary:
	var vision: Dictionary = {}
	for guard in _guards:
		var gn: int = guard.current_node()
		vision[gn] = true
		for n in _adjacency[gn]:
			vision[n] = true
	return vision


func _guard_on(node_id: int) -> bool:
	for guard in _guards:
		if guard.current_node() == node_id:
			return true
	return false


## Highlight this tick's combined vision: vision nodes red, and edges incident to
## any guard's node hot.
func _apply_vision() -> void:
	var vision := _combined_vision()
	for id in _nodes:
		_nodes[id].set_highlight(vision.has(id))
	for entry in _edges:
		entry.edge.set_highlight(_guard_on(entry.a) or _guard_on(entry.b))


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

	# 3 & 4: every guard advances along its route and tweens there in parallel.
	for guard in _guards:
		var guard_target := guard.advance()
		guard.move_to(level_data.node_positions[guard_target])  # fire in parallel
	await get_tree().create_timer(Guard.MOVE_TIME + 0.02).timeout

	# 5: compute + highlight this tick's combined vision (never during tweens).
	var vision := _combined_vision()
	_apply_vision()

	# 6: detection.
	if vision.has(GameState.player_node):
		GameState.spot_player()
		return

	# 7: win.
	if GameState.player_node == level_data.target_node:
		GameState.win_level()
		return

	# 8: unlock and wait for the next click.
	_input_locked = false
