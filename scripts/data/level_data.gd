class_name LevelData
extends Resource
## Data-driven definition of a single level.
##
## A new level is a new `.tres` file referencing this script — no code changes.
## Adjacency (per-node neighbours) is derived at runtime by `Level` from `edges`;
## it is intentionally not stored here.

## World position of each node. Array index == node id.
@export var node_positions: PackedVector3Array = PackedVector3Array()

## Undirected edges as (a, b) node-id pairs.
@export var edges: Array[Vector2i] = []

## Node id the player starts on.
@export var player_start: int = 0

## Node id that wins the level when the player ends a tick on it.
@export var target_node: int = 0

## Guard patrol route as an ordered list of node ids. Cycles.
@export var guard_patrol: PackedInt32Array = PackedInt32Array()

## Starting index into `guard_patrol`.
@export var guard_start_index: int = 0

## Extra guards beyond the first: one patrol route each. Empty = single guard.
@export var extra_guard_patrols: Array[PackedInt32Array] = []

## Starting index into each corresponding entry of `extra_guard_patrols`.
@export var extra_guard_start_indices: PackedInt32Array = PackedInt32Array()


## Every guard as [patrol, start_index] pairs — the first guard plus any extras.
func all_guards() -> Array:
	var guards: Array = [[guard_patrol, guard_start_index]]
	for i in extra_guard_patrols.size():
		var start := 0
		if i < extra_guard_start_indices.size():
			start = extra_guard_start_indices[i]
		guards.append([extra_guard_patrols[i], start])
	return guards
