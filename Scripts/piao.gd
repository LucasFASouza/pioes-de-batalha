extends CharacterBody3D

@onready var gfx: Node3D = $GFX

@export var max_speed := 30.0
@export var spin_speed := -720.0

@export var friction := 0.03

@export var bounce_factor := 2
@export var min_bounce_strength := 20

@export var player_number := "1"
@onready var label_3d: Label3D = $Label3D

var collision_stun_time := 0.0
var stun_duration := 0.3

const EXPLOSION_SCENE = preload("res://Scenes/explosion.tscn")

func _ready() -> void:
	label_3d.text = "Player " + player_number


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	gfx.rotate_y(deg_to_rad(spin_speed * delta))

	if collision_stun_time > 0:
		collision_stun_time -= delta

	if collision_stun_time <= 0:
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
	if body is CharacterBody3D and body != self and collision_stun_time <= 0:		
		var collision_direction = (global_transform.origin - body.global_transform.origin).normalized()
		
		var my_speed = velocity.length()
		var other_speed = body.velocity.length()
		
		var total_speed = my_speed + other_speed
		var push_force = max(total_speed * bounce_factor, min_bounce_strength)

		print("\n" + self.name + " collided with " + body.name + " with a force of " + str(push_force))
		
		var collision_point = (global_transform.origin + body.global_transform.origin)
		
		var explosion = EXPLOSION_SCENE.instantiate()
		get_tree().current_scene.add_child(explosion)
		explosion.global_transform.origin = collision_point
		explosion.explode(push_force)
		
		if total_speed > 0.1:
			var my_knockback_multiplier = other_speed / total_speed
			var other_knockback_multiplier = my_speed / total_speed

			print(self.name + " speed: " + str(my_speed) + " | knockback multiplier: " + str(my_knockback_multiplier))
			print(body.name + " speed: " + str(other_speed) + " | knockback multiplier: " + str(other_knockback_multiplier))

			velocity += collision_direction * push_force * my_knockback_multiplier
			body.velocity -= collision_direction * push_force * other_knockback_multiplier
		else:
			velocity += collision_direction * min_bounce_strength
			body.velocity -= collision_direction * min_bounce_strength
		
		collision_stun_time = stun_duration
		body.collision_stun_time = stun_duration
