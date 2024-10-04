extends CharacterBody3D

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

@export var max_speed = 20.0
@export var spin_speed = -720.0

@export var friction = 0.01

@export var bounce_factor = 1
@export var min_bounce_strength = 3.5

@export var player_number = "1"
@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	label_3d.text = "Player " + player_number

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	mesh_instance_3d.rotate_y(deg_to_rad(spin_speed * delta))

	var input_dir := Input.get_vector(
		"left_" + player_number,
		"right_" + player_number,
		"up_" + player_number,
		"down_" + player_number
		)

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	velocity = lerp(velocity, direction * max_speed, friction)

	move_and_slide()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print(self.name + " collided with " + body.name)

		var collision_direction = (global_transform.origin - body.global_transform.origin).normalized()
		var relative_velocity = velocity - body.velocity

		var impact_speed = relative_velocity.length()

		# Ensure a minimum bounce strength to always apply some repelling force
		var bounce_strength = max(impact_speed * bounce_factor, min_bounce_strength)

		body.velocity -= collision_direction * bounce_strength
		velocity += collision_direction * min_bounce_strength
