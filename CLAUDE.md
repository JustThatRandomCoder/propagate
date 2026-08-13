# Propagate — Architecture & Conventions

A minimalist **isometric, tick-based stealth game** built in Godot 4.7 (GDScript only).
The player is a rogue process slipping node-to-node through a network graph, dodging a
patrolling security process to reach a target node undetected.

It is **not** real-time and **not** free 3D movement. Movement is discrete: the player
steps to an adjacent node, then the guard steps, then detection resolves. One full pass
of that sequence is a **tick**.

---

## Hard rules

- Godot 4.x, **GDScript only**. No external assets — all visuals are primitive meshes
  (`BoxMesh`, `SphereMesh`, `CylinderMesh`, CSG). Placeholder-only, no polish.
- The camera is `Camera3D` in **orthogonal** projection at a fixed isometric angle
  (rotation `x:-30°, y:45°`). **No camera rotation** in this slice.
- Levels are **fully data-driven** via the `LevelData` resource. A new level is a new
  `.tres` file with **zero code changes**. This is the core architectural requirement —
  never hardcode graph geometry, guard routes, start, or target in a script.
- **Physics is cosmetic only.** Gameplay stays strictly discrete/tick-based. Real
  `RigidBody3D` physics is allowed for flourish — the gravity **drop-in** on level load
  and the **topple** on detection — but it must never feed back into run state, detection,
  or the node positions the tick loop uses. Inter-node movement is a deterministic,
  awaitable arc-hop tween that always lands exactly on the target node.

---

## Node structure

```
GameState            (autoload singleton — global run state + signals)

Level (Node3D)       (main scene — level.gd — owns the tick loop)
├── Camera3D         (orthogonal, iso angle, fixed)
├── DirectionalLight3D
├── Nodes (Node3D)   (spawned NetworkNode instances live here)
├── Edges (Node3D)   (spawned Edge instances live here)
├── Player           (spawned at runtime under Level)
├── Guard            (spawned at runtime under Level)
└── UI (CanvasLayer) (ui.gd — Detected / Level Complete labels)
```

### Responsibilities

- **`GameState`** (`scripts/autoload/game_state.gd`, autoload): the single source of truth for
  run state — `player_node` (current node id), `tick` (counter), `game_over`, `won`.
  Emits `player_spotted`, `level_won`, `tick_advanced(tick)`. Holds no scene references
  and no graph data; it only tracks state and fires signals.

- **`Level`** (`scripts/level.gd`): loads a `LevelData`, builds the graph (nodes + edges),
  lays a checkerboard floor with a `GridMap` (Godot's 3D tile node, built from a runtime
  `MeshLibrary` and aligned to the node grid), spawns Player and Guard, and **orchestrates
  the entire tick loop from the top**. It is the only place the tick resolution order lives.
  Owns the adjacency map derived from the level's edges and the highlight logic.

- **`NetworkNode`** (`scripts/graph/network_node.gd`, `scenes/graph/network_node.tscn`): one graph
  node — an `Area3D` for click detection + its data (`id`, world position, neighbor ids)
  wrapping a `NodePiece` (`scripts/graph/node_piece.gd`), the visual: a square board **tile**
  with a state-coloured block. Emits `clicked(id)` when its Area3D is clicked. Exposes
  `set_highlight(on)` (red vision tint), `drop_in(delay)` (cosmetic gravity settle), and
  `pop_off()` (hide the block so Level can spawn physics debris on detection).

- **`Edge`** (`scripts/graph/edge.gd`, `scenes/graph/edge.tscn`): a thin box stretched/oriented
  between two node positions. **Purely visual**, no logic.

- **`Player`** (`scripts/actors/player.gd`, `scenes/actors/player.tscn`): a marker mesh on the current
  node. `move_to(pos)` tweens it and can be `await`ed (returns after the tween finishes).

- **`Guard`** (`scripts/actors/guard.gd`, `scenes/actors/guard.tscn`): a marker mesh with a
  `patrol_route` (array of node ids) + current index. `advance()` steps the index
  (wrapping) and returns the new node id. `move_to(pos)` tweens and is awaitable.
  Vision is computed by `Level`, not the guard, because it needs the graph adjacency.

- **`UI`** (`scripts/ui/ui.gd`, embedded in `level.tscn` as a `CanvasLayer` — no separate scene): a `CanvasLayer` with
  a "Detected — restarting" label and a "Level Complete" label. Restart reloads the
  current scene.

---

## The tick loop — resolution order (do NOT reorder)

Implemented in `Level`. This order is the most fragile part of the game; keep it exact.

1. Player clicks a node **adjacent** to their current node → player tweens to it.
   Non-adjacent clicks are ignored. Input is locked for the rest of the tick.
2. `await` the player tween to finish, then **increment the tick**.
3. Guard advances to the **next node in its patrol route** and tweens there.
4. `await` the guard tween to finish. **Detection never runs while tweens animate.**
5. Compute guard **VISION** = its current node id **+ all node ids directly connected to
   it by an edge**. Highlight all vision nodes red this tick.
6. **Detection:** if the player's node id ∈ vision → emit `player_spotted` → show
   "Detected" → restart the level. Stop.
7. **Win:** if the player's node id == target node id → emit `level_won` → show
   "Level Complete". Stop.
8. Otherwise unlock input and wait for the next player click.

---

## `LevelData` resource

`scripts/data/level_data.gd` (`class_name LevelData extends Resource`). Fields:

| Field                | Type                | Meaning                                        |
|----------------------|---------------------|------------------------------------------------|
| `node_positions`     | `PackedVector3Array`| World position of each node; **array index = node id** |
| `edges`              | `Array[Vector2i]`   | Undirected edges as `(a, b)` node-id pairs     |
| `player_start`       | `int`               | Node id the player starts on                   |
| `target_node`        | `int`               | Node id that wins the level                    |
| `guard_patrol`       | `PackedInt32Array`  | First guard's patrol route as an ordered node-id list (cycles) |
| `guard_start_index`  | `int`               | Starting index into `guard_patrol`             |
| `extra_guard_patrols`| `Array[PackedInt32Array]` | Additional guards, one patrol each. Empty = single guard |
| `extra_guard_start_indices` | `PackedInt32Array` | Starting index into each entry of `extra_guard_patrols` |

Adjacency (neighbor ids per node) is **derived at runtime** from `edges` by `Level` —
it is not stored. **Multiple guards:** each tick every guard advances and tweens in
parallel; the tick's vision is the **union** over all guards of (node + adjacent nodes),
and detection tests that union. `LevelData.all_guards()` returns every guard as
`[patrol, start_index]` pairs.

### Levels & progression

- **Authored intro** — the `levels/level_*.tres` files, played first (single guard).
- **Endless generated levels** — after the intro, `LevelManager` hands out procedurally
  generated boards of rising difficulty (bigger grids, up to 4 guards) via
  `scripts/data/level_generator.gd`. A per-run seed randomises each playthrough; a given
  level index is deterministic within the run (a retry reloads the same board).
- **`scripts/data/level_solver.gd`** verifies any level under the exact tick rules (BFS
  over player + guard indices, union vision, detection before win). The generator only
  ships boards it proves solvable **and** non-trivial (`guards_matter`). If you author or
  generate a level, it must pass `LevelSolver.is_solvable`.

### Authoring a new level

1. Create a new `.tres` in `levels/` with `[gd_resource type="Resource" script_class="LevelData"]`
   referencing `res://scripts/data/level_data.gd`.
2. Fill `node_positions` (one `Vector3` per node, index-ordered), `edges`, `player_start`,
   `target_node`, `guard_patrol`, `guard_start_index`.
3. Point `Level`'s `@export var level_data` at the new resource (in the inspector on
   `level.tscn`, or make a new main scene). No script changes required.

The shipped level `levels/level_01.tres` is a 3×3 grid:

```
6 - 7 - 8
|   |   |
3 - 4 - 5
|   |   |
0 - 1 - 2
```

Player starts at `0`, target is `8`, one guard patrols `[4, 5, 4, 3]` from index `0`.
Intended solution is the perimeter `0→1→2→5→8`, which dodges the guard's vision cross
each tick; a path through the center gets caught.

---

## Git workflow

- **Commit every small, self-contained change separately** — don't batch unrelated work.
  Build in small steps and commit after each one while working.
- **Push occasionally** (after a few commits or at natural checkpoints), not every commit.
- Conventional Commits (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, …); messages
  describe what changed and why.
- **Never** put session ids, `Co-Authored-By: Claude`, "Generated with Claude Code", or any
  AI/Claude attribution in commits, PR titles, or PR bodies. They read as if the author
  wrote them.
- Don't commit to `main` directly; work on a descriptive branch (`feat/…`, `fix/…`, …).

## Conventions

- One script per node type in `scripts/`, one scene per reusable piece in `scenes/`,
  levels in `levels/`. Both trees are grouped into matching domain subfolders:
  `autoload/`, `actors/` (player, guard), `graph/` (network_node, node_piece, edge),
  `ui/`, and `data/` (level_data); the main `level.gd`/`level.tscn` stay at the root
  of their tree.
- `Level` is the only orchestrator. `GameState` holds state + signals only. Visual nodes
  (`NetworkNode`, `Edge`, `Player`, `Guard`) know nothing about the tick loop; they expose
  small imperative methods (`move_to`, `set_highlight`, `advance`) and signals.
- Tweens are created per-move and awaited via their `finished` signal. Never run detection
  or accept input mid-tween — guard against it with an `input_locked` flag on `Level`.
- Respect the data-driven rule above everything: if a change would require editing a script
  to make a different level, it belongs in `LevelData` instead.
