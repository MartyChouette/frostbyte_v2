extends CharacterBody2D
class_name Player

@export var speed: float = 150.0
@export var acceleration: float = 800.0
@export var friction: float = 800.0

var has_axe: bool = false

func _physics_process(delta: float) -> void:
	move(delta)
	check_collisions()

func move(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()

func check_collisions() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.has_method("destroy") and has_axe:
			collider.destroy()

func collect_axe() -> void:
	has_axe = true
	print("Axe collected! You can now destroy dead bushes.")
