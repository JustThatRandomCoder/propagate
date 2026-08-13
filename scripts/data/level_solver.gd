class_name LevelSolver
extends RefCounted
## Verifies a level under the exact tick rules, so the generator never ships an
## unbeatable board. State is (player node, tuple of guard patrol indices); each
## tick the player steps to a neighbour, every guard advances one step, and the
## player is caught if it lands in the union of all guards' vision (their node +
## adjacent nodes). Detection is checked before the win, matching `Level`.
##
## `guards` is an Array of [patrol: PackedInt32Array, start_index: int].


static func build_adjacency(node_count: int, edges: Array) -> Dictionary:
	var adj: Dictionary = {}
	for i in node_count:
		adj[i] = PackedInt32Array()
	for e in edges:
		var a: int = e.x
		var b: int = e.y
		if b not in adj[a]:
			adj[a].append(b)
		if a not in adj[b]:
			adj[b].append(a)
	return adj


static func _vision_after_advance(adj: Dictionary, guards: Array, idx: PackedInt32Array) -> Dictionary:
	var vision: Dictionary = {}
	for gi in guards.size():
		var patrol: PackedInt32Array = guards[gi][0]
		var node: int = patrol[idx[gi]]
		vision[node] = true
		for nb in adj[node]:
			vision[nb] = true
	return vision


## Per-guard vision bitmask for each patrol index (node + adjacent nodes).
## Requires node ids < 64 (grids here stay well under that).
static func _vision_masks(adj: Dictionary, guards: Array) -> Array:
	var masks: Array = []
	for g in guards:
		var patrol: PackedInt32Array = g[0]
		var per_index: PackedInt64Array = PackedInt64Array()
		for i in patrol.size():
			var node: int = patrol[i]
			var m: int = 1 << node
			for nb in adj[node]:
				m |= 1 << nb
			per_index.append(m)
		masks.append(per_index)
	return masks


## True if a safe route from start to target exists under the tick rules.
## Uses bitmask vision + integer state keys for speed.
static func is_solvable(node_count: int, edges: Array, start: int, target: int, guards: Array, max_states: int = 400000) -> bool:
	if start == target:
		return true
	var adj := build_adjacency(node_count, edges)
	var masks := _vision_masks(adj, guards)
	var gc := guards.size()
	var glen := PackedInt32Array()
	var base := 1
	for g in guards:
		var L: int = (g[0] as PackedInt32Array).size()
		glen.append(L)
		base = maxi(base, L)

	var g0 := PackedInt32Array()
	for g in guards:
		g0.append(g[1])
	var seen: Dictionary = {}
	var q_player := PackedInt32Array([start])
	var q_idx: Array = [g0]
	seen[_ikey(start, g0, base)] = true
	var head := 0
	while head < q_player.size():
		if head > max_states:
			return false
		var p: int = q_player[head]
		var idx: PackedInt32Array = q_idx[head]
		head += 1
		if p == target:
			return true
		# Advance every guard once for this tick and union their vision.
		var nidx := PackedInt32Array()
		var vis: int = 0
		for gi in gc:
			var ni: int = (idx[gi] + 1) % glen[gi]
			nidx.append(ni)
			vis |= masks[gi][ni]
		for nx in adj[p]:
			if (vis >> nx) & 1:
				continue
			var k := _ikey(nx, nidx, base)
			if seen.has(k):
				continue
			seen[k] = true
			q_player.append(nx)
			q_idx.append(nidx)
	return false


static func _ikey(player: int, idx: PackedInt32Array, base: int) -> int:
	var k := player
	for i in idx:
		k = k * base + i
	return k


## True if the naive guard-free shortest path would get the player caught — i.e.
## the guards actually matter (the level isn't trivially walkable).
static func guards_matter(node_count: int, edges: Array, start: int, target: int, guards: Array) -> bool:
	var adj := build_adjacency(node_count, edges)
	var path := _shortest_path(adj, start, target)
	if path.is_empty():
		return false
	var idx := PackedInt32Array()
	for g in guards:
		idx.append(g[1])
	for i in range(1, path.size()):
		for gi in guards.size():
			var patrol: PackedInt32Array = guards[gi][0]
			idx[gi] = (idx[gi] + 1) % patrol.size()
		var vision := _vision_after_advance(adj, guards, idx)
		if vision.has(path[i]):
			return true
	return false


static func _shortest_path(adj: Dictionary, start: int, target: int) -> PackedInt32Array:
	var prev: Dictionary = {start: -1}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var p: int = queue[head]
		head += 1
		if p == target:
			var path := PackedInt32Array()
			var cur := target
			while cur != -1:
				path.append(cur)
				cur = prev[cur]
			path.reverse()
			return path
		for nx in adj[p]:
			if not prev.has(nx):
				prev[nx] = p
				queue.append(nx)
	return PackedInt32Array()


static func _key(player: int, idx: PackedInt32Array) -> String:
	return str(player) + ":" + str(idx)
