extends CharacterBody2D
class_name Enemy

enum State { IDLE, CHASE, SEARCH }

@export var speed: float = 120.0
@export var vision_range: float = 200.0
@export var lose_attention_time: float = 3.0

var current_state: State = State.IDLE
var target: CharacterBody2D = null
var last_known_pos: Vector2 = Vector2.ZERO

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var state_timer: Timer = $StateTimer
@onready var ray_cast: RayCast2D = $RayCast2D

func _ready() -> void:
	# Initialize Navigation
	nav_agent.path_desired_distance = 10.0
	nav_agent.target_desired_distance = 10.0
	
	# Find player
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			# Optional: Wander logic here
			
		State.CHASE:
			if target:
				nav_agent.target_position = target.global_position
				var next_pos = nav_agent.get_next_path_position()
				var dir = global_position.direction_to(next_pos)
				velocity = dir * speed
			
		State.SEARCH:
			nav_agent.target_position = last_known_pos
			if not nav_agent.is_navigation_finished():
				var next_pos = nav_agent.get_next_path_position()
				var dir = global_position.direction_to(next_pos)
				velocity = dir * speed
			else:
				velocity = Vector2.ZERO
				# Reached last known pos, wait a bit then IDLE
				if state_timer.is_stopped():
					state_timer.start(1.0) # Wait 1 sec before idling
	
	move_and_slide()
	check_vision()

func check_vision() -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return

	var dist = global_position.distance_to(target.global_position)
	
	if dist < vision_range:
		# Check Line of Sight
		ray_cast.target_position = to_local(target.global_position)
		ray_cast.force_raycast_update()
		
		if not ray_cast.is_colliding() or ray_cast.get_collider() == target:
			# Can see player
			last_known_pos = target.global_position
			if current_state != State.CHASE:
				set_state(State.CHASE)
			return

	# If we are chasing but can't see player
	if current_state == State.CHASE:
		# If we haven't seen player for a while (handled by timer?)
		# Actually, immediate switch to SEARCH if LoS lost is better
		# But usually we give it a "grace period" or just go to last known pos.
		set_state(State.SEARCH)

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
		
	current_state = new_state
	state_timer.stop()
	
	match new_state:
		State.IDLE:
			pass
		State.CHASE:
			pass
		State.SEARCH:
			# Start a timer to give up searching if we don't find them?
			# Or just travel to last_known_pos.
			pass

func _on_state_timer_timeout() -> void:
	if current_state == State.SEARCH:
		set_state(State.IDLE)
