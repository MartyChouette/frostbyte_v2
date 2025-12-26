extends Node2D
class_name MazeGenerator

## Configuration
@export var width: int = 6
@export var height: int = 6
@export var cell_size: float = 300.0
@export var hedge_thickness: float = 32.0
@export var hedge_scene: PackedScene
@export var breakable_hedge_scene: PackedScene
@export var clearing_scene: PackedScene
@export var items_for_clearings: Array[PackedScene] = []
@export var loose_item_scenes: Array[PackedScene] = []
@export var loose_item_count: int = 4
@export var character_scenes: Array[PackedScene] = []
@export var character_count: int = 2
@export var clearing_count: int = 3
@export var break_area_count: int = 6
@export var seed: int = 0

const DIRS := {
        "N": Vector2i(0, -1),
        "E": Vector2i(1, 0),
        "S": Vector2i(0, 1),
        "W": Vector2i(-1, 0),
}
const OPPOSITE := {"N": "S", "E": "W", "S": "N", "W": "E"}
const BASE_HEDGE_LENGTH := 200.0
const BASE_HEDGE_THICKNESS := 32.0

var _cells: Array = []
var _occupied: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
        if seed != 0:
                _rng.seed = seed
        else:
                _rng.randomize()
        generate_maze()

func generate_maze() -> void:
        _build_grid()
        _carve_passages(Vector2i.ZERO)
        _place_clearings()
        _place_break_areas()
        _spawn_walls()
        _spawn_items()
        _spawn_characters()

func _build_grid() -> void:
        _cells.resize(height)
        for y in height:
                _cells[y] = []
                for x in width:
                        _cells[y].append({
                                "visited": false,
                                "walls": {"N": true, "E": true, "S": true, "W": true}
                        })

func _carve_passages(start: Vector2i) -> void:
        var stack: Array[Vector2i] = [start]
        _cells[start.y][start.x].visited = true

        while not stack.is_empty():
                var current: Vector2i = stack[-1]
                var neighbors = _unvisited_neighbors(current)
                if neighbors.is_empty():
                        stack.pop_back()
                        continue
                var next_data = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
                var direction: String = next_data["dir"]
                var next: Vector2i = next_data["cell"]
                _remove_wall(current, direction)
                _remove_wall(next, OPPOSITE[direction])
                _cells[next.y][next.x].visited = true
                stack.append(next)

func _unvisited_neighbors(cell: Vector2i) -> Array:
        var neighbors: Array = []
        for dir in DIRS.keys():
                var offset: Vector2i = DIRS[dir]
                var nx = cell.x + offset.x
                var ny = cell.y + offset.y
                if nx < 0 or nx >= width or ny < 0 or ny >= height:
                        continue
                if not _cells[ny][nx].visited:
                        neighbors.append({"dir": dir, "cell": Vector2i(nx, ny)})
        return neighbors

func _remove_wall(cell: Vector2i, direction: String) -> void:
        _cells[cell.y][cell.x].walls[direction] = false

func _place_break_areas() -> void:
        var candidates: Array = []
        for y in height:
                for x in width:
                        var cell := Vector2i(x, y)
                        for dir in DIRS.keys():
                                var offset: Vector2i = DIRS[dir]
                                var neighbor := Vector2i(x + offset.x, y + offset.y)
                                if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
                                        continue
                                if _cells[y][x].walls[dir]:
                                        candidates.append({"cell": cell, "dir": dir, "neighbor": neighbor})
        _shuffle_with_rng(candidates)
        var count := min(break_area_count, candidates.size())
        for i in count:
                var info = candidates[i]
                var cell: Vector2i = info["cell"]
                var dir: String = info["dir"]
                var neighbor: Vector2i = info["neighbor"]
                _remove_wall(cell, dir)
                _remove_wall(neighbor, OPPOSITE[dir])
                _spawn_breakable_blocker(cell, dir)

func _place_clearings() -> void:
        if clearing_scene == null:
                return
        var available_cells: Array[Vector2i] = _all_cells()
        _shuffle_with_rng(available_cells)
        var count := min(clearing_count, available_cells.size())
        for i in count:
                var cell: Vector2i = available_cells[i]
                if _is_occupied(cell):
                        continue
                _reserve(cell)
                _open_cell(cell)
                var clearing: Node2D = clearing_scene.instantiate()
                if clearing.has_variable("items_to_spawn"):
                        clearing.set("items_to_spawn", items_for_clearings.duplicate())
                clearing.position = _cell_to_world(cell)
                add_child(clearing)

func _open_cell(cell: Vector2i) -> void:
        for dir in DIRS.keys():
                var offset := DIRS[dir]
                var neighbor := cell + offset
                if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
                        continue
                _remove_wall(cell, dir)
                _remove_wall(neighbor, OPPOSITE[dir])

func _spawn_breakable_blocker(cell: Vector2i, dir: String) -> void:
        if breakable_hedge_scene == null:
                return
        var instance: Node2D = breakable_hedge_scene.instantiate()
        var info = _wall_transform(cell, dir)
        instance.position = info.position
        instance.rotation = info.rotation
        add_child(instance)

func _spawn_walls() -> void:
        for y in height:
                for x in width:
                        var cell := Vector2i(x, y)
                        var walls = _cells[y][x].walls
                        if x == 0 and walls["W"]:
                                _spawn_wall(cell, "W")
                        if y == 0 and walls["N"]:
                                _spawn_wall(cell, "N")
                        if x < width - 1 and walls["E"]:
                                _spawn_wall(cell, "E")
                        if y < height - 1 and walls["S"]:
                                _spawn_wall(cell, "S")
                        if x == width - 1 and walls["E"]:
                                _spawn_wall(cell, "E")
                        if y == height - 1 and walls["S"]:
                                _spawn_wall(cell, "S")

func _spawn_wall(cell: Vector2i, dir: String) -> void:
        var info = _wall_transform(cell, dir)
        var wall: Node2D = _instantiate_wall()
        wall.position = info.position
        wall.rotation = info.rotation
        wall.scale = Vector2(cell_size / BASE_HEDGE_LENGTH, hedge_thickness / BASE_HEDGE_THICKNESS)
        add_child(wall)

func _instantiate_wall() -> Node2D:
        if hedge_scene != null:
                        return hedge_scene.instantiate()
        var body := StaticBody2D.new()
        var collider := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.extents = Vector2(BASE_HEDGE_LENGTH * 0.5, BASE_HEDGE_THICKNESS * 0.5)
        collider.shape = shape
        body.add_child(collider)
        return body

func _wall_transform(cell: Vector2i, dir: String) -> Dictionary:
        var center := _cell_to_world(cell)
        var offset := Vector2.ZERO
        var rotation := 0.0
        match dir:
                "N":
                        offset = Vector2(0, -cell_size * 0.5)
                        rotation = 0.0
                "S":
                        offset = Vector2(0, cell_size * 0.5)
                        rotation = 0.0
                "E":
                        offset = Vector2(cell_size * 0.5, 0)
                        rotation = PI / 2.0
                "W":
                        offset = Vector2(-cell_size * 0.5, 0)
                        rotation = PI / 2.0
        return {"position": center + offset, "rotation": rotation}

func _spawn_items() -> void:
        if loose_item_scenes.is_empty():
                return
        var available := _available_cells()
        _shuffle_with_rng(available)
        var total := min(loose_item_count, available.size())
        for i in total:
                var cell: Vector2i = available[i]
                if _is_occupied(cell):
                        continue
                _reserve(cell)
                var item_scene: PackedScene = loose_item_scenes[_rng.randi_range(0, loose_item_scenes.size() - 1)]
                var item: Node2D = item_scene.instantiate()
                item.position = _cell_to_world(cell)
                add_child(item)

func _spawn_characters() -> void:
        if character_scenes.is_empty():
                return
        var available := _available_cells()
        _shuffle_with_rng(available)
        var total := min(character_count, available.size())
        for i in total:
                var cell: Vector2i = available[i]
                if _is_occupied(cell):
                        continue
                _reserve(cell)
                var character_scene: PackedScene = character_scenes[_rng.randi_range(0, character_scenes.size() - 1)]
                var character: Node2D = character_scene.instantiate()
                character.position = _cell_to_world(cell)
                add_child(character)

func _cell_to_world(cell: Vector2i) -> Vector2:
        return Vector2(cell.x * cell_size, cell.y * cell_size)

func _all_cells() -> Array[Vector2i]:
        var cells: Array[Vector2i] = []
        for y in height:
                for x in width:
                        cells.append(Vector2i(x, y))
        return cells

func _available_cells() -> Array[Vector2i]:
        var cells: Array[Vector2i] = []
        for y in height:
                for x in width:
                        var cell := Vector2i(x, y)
                        if not _is_occupied(cell):
                                cells.append(cell)
        return cells

func _reserve(cell: Vector2i) -> void:
        _occupied[_cell_key(cell)] = true

func _is_occupied(cell: Vector2i) -> bool:
        return _occupied.has(_cell_key(cell))

func _cell_key(cell: Vector2i) -> String:
        return "%d_%d" % [cell.x, cell.y]

func _shuffle_with_rng(values: Array) -> void:
        for i in range(values.size() - 1, 0, -1):
                var j = _rng.randi_range(0, i)
                var temp = values[i]
                values[i] = values[j]
                values[j] = temp
