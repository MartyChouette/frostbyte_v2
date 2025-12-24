extends Node2D

@export var items_to_spawn: Array[PackedScene] = []

func _ready() -> void:
	spawn_random_items()

func spawn_random_items() -> void:
	if items_to_spawn.is_empty():
		return
		
	var spawn_points = $ItemSpawnPoints.get_children()
	spawn_points.shuffle()
	
	# Spawn 1 item per clearing max (as per "no more than 2 a section" request interpretation? 
	# Or "no more than 2 clearings"? User said "no more than 2 a section" referring likely to clearings per section
	# or items per clearing. Let's assume 1-2 items per clearing for now.)
	
	var item_count = randi() % 2 + 1 # 1 or 2 items
	for i in range(min(item_count, spawn_points.size())):
		var item_scene = items_to_spawn.pick_random()
		var item = item_scene.instantiate()
		item.global_position = spawn_points[i].global_position
		add_child(item)
