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
