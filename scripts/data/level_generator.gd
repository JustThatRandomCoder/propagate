class_name LevelGenerator
extends RefCounted
## Builds a random, escalating, guaranteed-solvable LevelData for a given
## difficulty. The board is a full grid (highly connected, so routing around
## guards is possible); randomness and difficulty come from the size, the number
## of guards, which rows/columns they sweep, their phases, and the start/target
## corners. Every candidate is checked with `LevelSolver` before it is returned,
## so a level is always beatable and non-trivial (the guards actually matter).

const CELL := 1.5


static func generate(difficulty: int, rng: RandomNumberGenerator) -> LevelData:
	var cols: int = clampi(4 + (difficulty + 1) / 2, 4, 7)
	var rows: int = clampi(4 + difficulty / 2, 4, 7)
	var guard_count: int = clampi(2 + difficulty / 2, 2, 4)
	var n := cols * rows
	var positions := _grid_positions(cols, rows)
	var edges := _grid_edges(cols, rows)
	var corners := [
		_idx(0, 0, cols), _idx(cols - 1, 0, cols),
		_idx(0, rows - 1, cols), _idx(cols - 1, rows - 1, cols),
	]

	var seg_len: int = clampi(3 + difficulty / 3, 3, 6)
	for _attempt in 160:
		var start: int = corners[rng.randi() % corners.size()]
		var target: int = _far_corner(start, corners, cols)
		var guards := _random_guards(cols, rows, guard_count, seg_len, rng)
		if guards.is_empty() or not _clean_start(n, edges, start, guards):
			continue
		if LevelSolver.is_solvable(n, edges, start, target, guards, 150000) \
				and LevelSolver.guards_matter(n, edges, start, target, guards):
			return _build(positions, edges, start, target, guards)

	# Fallback: a single guard almost always leaves the grid solvable.
	var s: int = corners[0]
	var t: int = corners[3]
	for _attempt in 60:
		var guards := _random_guards(cols, rows, 1, seg_len, rng)
		if not guards.is_empty() and _clean_start(n, edges, s, guards) \
				and LevelSolver.is_solvable(n, edges, s, t, guards, 60000):
			return _build(positions, edges, s, t, guards)

	# Last resort: a lone guard parked in the middle (always solvable).
	var mid := PackedInt32Array([_idx(cols / 2, rows / 2, cols)])
	return _build(positions, edges, s, t, [[mid, 0]])


# --- Board ------------------------------------------------------------------

static func _idx(c: int, r: int, cols: int) -> int:
	return r * cols + c


static func _grid_positions(cols: int, rows: int) -> PackedVector3Array:
	# Integer centering so every node lands on an integer GridMap cell.
	var cc := cols / 2
	var cr := rows / 2
	var pos := PackedVector3Array()
	for r in rows:
		for c in cols:
			pos.append(Vector3((c - cc) * CELL, 0.0, (r - cr) * CELL))
	return pos


static func _grid_edges(cols: int, rows: int) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			if c + 1 < cols:
				edges.append(Vector2i(_idx(c, r, cols), _idx(c + 1, r, cols)))
			if r + 1 < rows:
				edges.append(Vector2i(_idx(c, r, cols), _idx(c, r + 1, cols)))
	return edges


static func _far_corner(start: int, corners: Array, cols: int) -> int:
	var sc := start % cols
	var sr := start / cols
	var best: int = corners[0]
	var best_d := -1
	for corner in corners:
		var cc: int = corner
		if cc == start:
			continue
		var d: int = absi(cc % cols - sc) + absi(cc / cols - sr)
		if d > best_d:
			best_d = d
			best = cc
	return best


# --- Guards -----------------------------------------------------------------

static func _neighbors(node: int, cols: int, rows: int) -> PackedInt32Array:
	var c := node % cols
	var r := node / cols
	var out := PackedInt32Array()
	if c + 1 < cols:
		out.append(_idx(c + 1, r, cols))
	if c - 1 >= 0:
		out.append(_idx(c - 1, r, cols))
	if r + 1 < rows:
		out.append(_idx(c, r + 1, cols))
	if r - 1 >= 0:
		out.append(_idx(c, r - 1, cols))
	return out


static func _ping_pong(line: PackedInt32Array) -> PackedInt32Array:
	# a,b,c,d -> a,b,c,d,c,b (cycles back and forth along the segment)
	var out := PackedInt32Array(line)
	for i in range(line.size() - 2, 0, -1):
		out.append(line[i])
	return out


## A short random-walk patrol: a wandering segment of adjacent nodes, ping-ponged
## so it sweeps back and forth. Short = beatable and cheap to verify.
static func _walk_patrol(cols: int, rows: int, seg_len: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var start := rng.randi() % (cols * rows)
	var path := PackedInt32Array([start])
	var cur := start
	while path.size() < seg_len:
		var options := PackedInt32Array()
		for nb in _neighbors(cur, cols, rows):
			if nb not in path:
				options.append(nb)
		if options.is_empty():
			break
		cur = options[rng.randi() % options.size()]
		path.append(cur)
	if path.size() < 2:
		return path
	return _ping_pong(path)


static func _random_guards(cols: int, rows: int, count: int, seg_len: int, rng: RandomNumberGenerator) -> Array:
	var guards: Array = []
	var tries := 0
	while guards.size() < count and tries < 40:
		tries += 1
		var patrol := _walk_patrol(cols, rows, seg_len, rng)
		guards.append([patrol, rng.randi() % patrol.size()])
	return guards


static func _clean_start(n: int, edges: Array, start: int, guards: Array) -> bool:
	var adj := LevelSolver.build_adjacency(n, edges)
	for g in guards:
		var gnode: int = g[0][g[1]]
		if gnode == start or start in adj[gnode]:
			return false
	return true


# --- Assembly ---------------------------------------------------------------

static func _build(positions: PackedVector3Array, edges: Array[Vector2i], start: int, target: int, guards: Array) -> LevelData:
	var ld := LevelData.new()
	ld.node_positions = positions
	ld.edges = edges
	ld.player_start = start
	ld.target_node = target
	ld.guard_patrol = guards[0][0]
	ld.guard_start_index = guards[0][1]
	var extra_p: Array[PackedInt32Array] = []
	var extra_s := PackedInt32Array()
	for i in range(1, guards.size()):
		extra_p.append(guards[i][0])
		extra_s.append(guards[i][1])
	ld.extra_guard_patrols = extra_p
	ld.extra_guard_start_indices = extra_s
	return ld
