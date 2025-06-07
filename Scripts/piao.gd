extends CharacterBody3D

@onready var gfx: Node3D = $GFX

@export var max_speed := 20.0
@export var spin_speed := -720.0

@export var friction := 0.03

@export var min_bounce_strength := 10
@export var min_bounce_factor := 1.0
@export var max_bounce_factor := 2.0

@export var player_number := "1"
@export var is_ai_controlled := false
@onready var label_3d: Label3D = $Label3D

# Dash mechanics
@export var dash_speed := 80.0
@export var dash_duration := 0.3
@export var dash_cooldown_time := 10.0
var dash_direction := Vector2.ZERO
var is_dashing := false
var dash_timer: Timer
var dash_cooldown_timer: Timer

# Shield mechanics
@export var shield_duration := 1.0
@export var shield_cooldown_time := 15.0
var is_shielding := false
var shield_timer: Timer
var shield_cooldown_timer: Timer

# Stamina mechanics
@export var max_stamina := 100.0
var current_stamina := 100.0
@export var stamina_regen_rate := 2.0  # Stamina points per second

var collision_stun_time := 0.0
var stun_duration := 0.3
var ai_controller: Node
var ai_input_direction := Vector2.ZERO
@export var ai_personality := 1

const EXPLOSION_SCENE = preload("res://Scenes/explosion.tscn")

func _ready() -> void:
	label_3d.text = "Player " + player_number
	
	# Setup timers
	dash_timer = Timer.new()
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_finished)
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.wait_time = dash_cooldown_time
	dash_cooldown_timer.one_shot = true
	add_child(dash_cooldown_timer)
	
	shield_timer = Timer.new()
	shield_timer.wait_time = shield_duration
	shield_timer.one_shot = true
	shield_timer.timeout.connect(_on_shield_finished)
	add_child(shield_timer)
	
	shield_cooldown_timer = Timer.new()
	shield_cooldown_timer.wait_time = shield_cooldown_time
	shield_cooldown_timer.one_shot = true
	add_child(shield_cooldown_timer)
	
	if is_ai_controlled:
		var ai_script = preload("res://Scripts/piao_ai.gd")
		ai_controller = Node.new()
		ai_controller.set_script(ai_script)
		add_child(ai_controller)
		ai_controller.initialize(self)
		ai_controller.set_personality(ai_personality)
		label_3d.text = "CPU"


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	gfx.rotate_y(deg_to_rad(spin_speed * delta))

	var battle_manager = get_tree().current_scene.get_node("BattleManager")
	var can_move = battle_manager and battle_manager.is_game_playing()

	if collision_stun_time > 0:
		collision_stun_time -= delta

	if collision_stun_time <= 0 and is_on_floor() and can_move:
		var input_dir := Vector2.ZERO
		
		if not is_ai_controlled:
			input_dir = Input.get_vector(
				"left_" + player_number,
				"right_" + player_number,
				"up_" + player_number,
				"down_" + player_number
			)

			if Input.is_action_just_pressed("shield_" + player_number) and shield_cooldown_timer.is_stopped():
				start_shield()
			
			if Input.is_action_just_pressed("dash_" + player_number) and dash_cooldown_timer.is_stopped() and not is_shielding:
				if input_dir.length() > 0.1:
					start_dash(input_dir)
			
		else:
			input_dir = ai_input_direction

		if is_shielding:
			velocity = lerp(velocity, Vector3.ZERO, friction * 5)
		elif is_dashing:
			var dash_direction_3d := (transform.basis * Vector3(dash_direction.x, 0, dash_direction.y)).normalized()
			velocity = lerp(velocity, dash_direction_3d * dash_speed, friction * 5)
		else:
			var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity = lerp(velocity, direction * max_speed, friction)

	move_and_slide()


func _process(_delta: float) -> void:
	if is_ai_controlled and ai_controller and ai_controller.has_method("get_debug_info"):
		label_3d.text = "CPU: " + ai_controller.get_debug_info()


func start_dash(direction: Vector2) -> void:
	if dash_cooldown_timer.is_stopped() and not is_shielding and not is_dashing:
		dash_direction = direction.normalized()
		dash_timer.start()
		dash_cooldown_timer.start()
		is_dashing = true
		print("Player " + player_number + " is dashing!")


func start_shield() -> void:
	if shield_cooldown_timer.is_stopped() and not is_shielding:
		is_dashing = false
		dash_timer.stop()

		shield_timer.start()
		shield_cooldown_timer.start()
		is_shielding = true
		print("Player " + player_number + " is shielding!")


func _on_dash_finished() -> void:
	is_dashing = false


func _on_shield_finished() -> void:
	is_shielding = false


func get_dash_status() -> String:
	if dash_cooldown_timer.time_left > 0:
		return "%.1fs" % dash_cooldown_timer.time_left
	elif is_dashing:
		return "DASHING"
	else:
		return "Ready"


func get_shield_status() -> String:
	if shield_cooldown_timer.time_left > 0:
		return "%.1fs" % shield_cooldown_timer.time_left
	elif is_shielding:
		return "SHIELDING"
	else:
		return "Ready"


func get_stamina_status() -> String:
	return "%.0f/%.0f" % [current_stamina, max_stamina]


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not _should_process_collision(body):
		return
	
	var collision_data = _calculate_collision_data(body)
	_log_collision_info(body, collision_data)
	_create_collision_explosion(body, collision_data.total_speed)
	
	if collision_data.total_speed > 0.1:
		_handle_high_speed_collision(body, collision_data)
	else:
		_handle_low_speed_collision(body, collision_data.collision_direction)
	
	_apply_collision_stun(body)


func _should_process_collision(body: Node3D) -> bool:
	return body is CharacterBody3D and body != self and collision_stun_time <= 0


func _calculate_collision_data(body: Node3D) -> Dictionary:
	var collision_direction = (global_transform.origin - body.global_transform.origin).normalized()
	var my_speed = velocity.length()
	var other_speed = body.velocity.length()
	var total_speed = my_speed + other_speed
	
	var my_stamina_ratio = current_stamina / max_stamina
	var other_stamina_ratio = body.current_stamina / body.max_stamina if "current_stamina" in body else 1.0
	
	var my_bounce_factor = lerp(max_bounce_factor, min_bounce_factor, my_stamina_ratio)
	var other_bounce_factor = lerp(max_bounce_factor, min_bounce_factor, other_stamina_ratio)
		
	return {
		"collision_direction": collision_direction,
		"my_speed": my_speed,
		"other_speed": other_speed,
		"total_speed": total_speed,
		"my_stamina_ratio": my_stamina_ratio,
		"other_stamina_ratio": other_stamina_ratio,
		"my_bounce_factor": my_bounce_factor,
		"other_bounce_factor": other_bounce_factor,
	}


func _log_collision_info(body: Node3D, collision_data: Dictionary) -> void:
	print("\n" + self.name + " collided with " + body.name)
	print("My stamina: " + str(int(current_stamina)) + " (bounce factor: " + str(collision_data.my_bounce_factor) + ")")
	print("Other stamina: " + str(int(collision_data.other_stamina_ratio * 100)) + " (bounce factor: " + str(collision_data.other_bounce_factor) + ")")


func _create_collision_explosion(body: Node3D, total_speed: float) -> void:
	var collision_point = (global_transform.origin + body.global_transform.origin) / 2
	collision_point.y += 3.0 
	var explosion = EXPLOSION_SCENE.instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_transform.origin = collision_point
	explosion.explode(total_speed)


func _handle_high_speed_collision(body: Node3D, collision_data: Dictionary) -> void:
	var my_shielding = is_shielding
	var other_shielding = body.is_shielding if "is_shielding" in body else false
	
	if my_shielding and other_shielding:
		_handle_both_shielding_collision(body, collision_data)
	elif my_shielding:
		_handle_my_shielding_collision(body, collision_data)
	elif other_shielding:
		_handle_other_shielding_collision(body, collision_data)
	else:
		_handle_normal_collision(body, collision_data)


func _handle_both_shielding_collision(body: Node3D, collision_data: Dictionary) -> void:
	velocity += collision_data.collision_direction * min_bounce_strength * 0.1
	body.velocity -= collision_data.collision_direction * min_bounce_strength * 0.1


func _handle_my_shielding_collision(body: Node3D, collision_data: Dictionary) -> void:
	var my_force = 0.0
	var other_force = collision_data.total_speed * collision_data.other_bounce_factor
	
	_apply_collision_forces(body, my_force, other_force, collision_data.collision_direction)
	_apply_stamina_loss_from_force(other_force, body)


func _handle_other_shielding_collision(body: Node3D, collision_data: Dictionary) -> void:
	var my_force = collision_data.total_speed * collision_data.my_bounce_factor
	var other_force = 0.0
	
	_apply_collision_forces(body, my_force, other_force, collision_data.collision_direction)
	_apply_stamina_loss_from_force(my_force, self)


func _handle_normal_collision(body: Node3D, collision_data: Dictionary) -> void:
	var my_knockback_multiplier = collision_data.other_speed / collision_data.total_speed
	var other_knockback_multiplier = collision_data.my_speed / collision_data.total_speed
	
	var my_push_force = collision_data.total_speed * my_knockback_multiplier * collision_data.my_bounce_factor
	var other_push_force = collision_data.total_speed * other_knockback_multiplier * collision_data.other_bounce_factor
	
	_apply_collision_forces(body, my_push_force, other_push_force, collision_data.collision_direction, false)	
	_apply_stamina_loss_from_force(my_push_force, self)
	_apply_stamina_loss_from_force(other_push_force, body)


func _apply_collision_forces(body: Node3D, my_force: float, other_force: float, direction: Vector3, is_additive: bool = true) -> void:
	if my_force == 0.0:
		velocity = Vector3.ZERO
	elif is_additive:
		velocity += direction * my_force
	else:
		velocity = direction * my_force
	
	if other_force == 0.0:
		body.velocity = Vector3.ZERO
	elif is_additive:
		body.velocity -= direction * other_force
	else:
		body.velocity = -direction * other_force


func _apply_stamina_loss_from_force(force: float, target_body: Node3D) -> void:
	var stamina_loss = force / 5
	if target_body == self:
		current_stamina = max(0.0, current_stamina - stamina_loss)
	elif "current_stamina" in target_body:
		target_body.current_stamina = max(0.0, target_body.current_stamina - stamina_loss)


func _handle_low_speed_collision(body: Node3D, collision_direction: Vector3) -> void:
	velocity += collision_direction * min_bounce_strength
	body.velocity -= collision_direction * min_bounce_strength


func _apply_collision_stun(body: Node3D) -> void:
	collision_stun_time = stun_duration
	body.collision_stun_time = stun_duration


func set_ai_input(direction: Vector2) -> void:
	ai_input_direction = direction


func set_ai_personality(personality_index: int) -> void:
	if ai_controller and ai_controller.has_method("set_personality"):
		ai_controller.set_personality(personality_index)
