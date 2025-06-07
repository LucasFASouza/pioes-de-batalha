extends Node

# AI Personalities
enum Personality {
	AGGRESSIVE,
	DECEIVER,
	RUNNER
}

# AI State
enum State {
	MOVING,
	PREPARING_DASH,
	DASHING,
	SHIELDING,
	WAITING
}

var piao: CharacterBody3D
var opponent: CharacterBody3D
var ai_personality: Personality
var current_state: State = State.MOVING

# Decision timers
var decision_timer := 0.0
var decision_interval := 0.2

# Personality-specific variables
var runner_momentum_threshold := 10.0
var deceiver_bait_distance := 15.0
var aggressive_charge_distance := 25.0

func initialize(player: CharacterBody3D) -> void:
	piao = player
	find_opponent()

func find_opponent() -> void:
	var players_node = get_tree().current_scene.get_node("Players")
	for player in players_node.get_children():
		if player != piao:
			opponent = player
			break

func _process(delta: float) -> void:
	if not piao or not opponent:
		return
	
	decision_timer -= delta
	if decision_timer <= 0:
		decision_timer = decision_interval
		make_decision()
	
	execute_behavior(delta)

func make_decision() -> void:
	if not piao or not opponent:
		return
	
	var distance_to_opponent = piao.global_position.distance_to(opponent.global_position)
	var my_speed = piao.velocity.length()
	var opponent_speed = opponent.velocity.length()
	
	# Check ability availability
	var can_dash = piao.dash_cooldown_timer.is_stopped() and not piao.is_shielding
	var can_shield = piao.shield_cooldown_timer.is_stopped() and not piao.is_dashing
	
	match ai_personality:
		Personality.AGGRESSIVE:
			decide_aggressive(distance_to_opponent, my_speed, opponent_speed, can_dash, can_shield)
		Personality.DECEIVER:
			decide_deceiver(distance_to_opponent, my_speed, opponent_speed, can_dash, can_shield)
		Personality.RUNNER:
			decide_runner(distance_to_opponent, my_speed, opponent_speed, can_dash, can_shield)

func decide_aggressive(distance: float, _my_speed: float, opponent_speed: float, can_dash: bool, can_shield: bool) -> void:
	# AGGRESSIVE: mostly charging the player, dashing if opponent has no shield, keeping pressure
	
	if opponent.is_dashing and can_shield:
		# Shield against incoming dash
		current_state = State.SHIELDING
	elif distance < aggressive_charge_distance and can_dash and not opponent.is_shielding:
		# Dash at close range if opponent can't shield
		current_state = State.PREPARING_DASH
	elif opponent_speed < 5.0 and can_dash and distance < 20.0:
		# Dash at slow/stationary opponents
		current_state = State.PREPARING_DASH
	else:
		# Default: charge toward opponent
		current_state = State.MOVING

func decide_deceiver(distance: float, _my_speed: float, opponent_speed: float, can_dash: bool, can_shield: bool) -> void:
	# DECEIVER: last-second movements, bait abilities, always save shield for when player is dashing
	
	if opponent.is_dashing and can_shield:
		# Always shield against dashes - top priority
		current_state = State.SHIELDING
	elif distance < deceiver_bait_distance and opponent_speed > 15.0 and can_dash:
		# Bait with sudden dash when opponent is moving fast nearby
		if randf() < 0.3:  # 30% chance to dash (unpredictable)
			current_state = State.PREPARING_DASH
		else:
			current_state = State.MOVING
	elif distance > 25.0:
		# Stay at medium distance for baiting
		current_state = State.MOVING
	else:
		# Circle around opponent, be evasive
		current_state = State.MOVING

func decide_runner(distance: float, my_speed: float, _opponent_speed: float, can_dash: bool, can_shield: bool) -> void:
	# RUNNER: conserve momentum running across field for big swing, tactical movement
	
	if opponent.is_dashing and can_shield and distance < 15.0:
		# Shield only if dash is very close
		current_state = State.SHIELDING
	elif my_speed > runner_momentum_threshold and can_dash and distance < 18.0:
		# Use momentum for powerful dash
		current_state = State.PREPARING_DASH
	elif my_speed < 10.0 and distance > 20.0:
		# Build up speed when far away
		current_state = State.MOVING
	else:
		# Maintain momentum, tactical positioning
		current_state = State.MOVING

func execute_behavior(_delta: float) -> void:
	match current_state:
		State.MOVING:
			execute_movement()
		State.PREPARING_DASH:
			execute_dash()
		State.SHIELDING:
			execute_shield()
		State.DASHING, State.WAITING:
			# Let the abilities handle themselves
			pass

func execute_movement() -> void:
	if not opponent:
		return
	
	var direction_to_opponent = (opponent.global_position - piao.global_position).normalized()
	var movement_direction = Vector2.ZERO
	
	match ai_personality:
		Personality.AGGRESSIVE:
			# Direct charge with slight randomization
			movement_direction = Vector2(direction_to_opponent.x, direction_to_opponent.z)
			if randf() < 0.1:  # 10% random adjustment
				movement_direction = movement_direction.rotated(randf_range(-0.3, 0.3))
		
		Personality.DECEIVER:
			# Unpredictable movement, sometimes toward, sometimes around
			if randf() < 0.6:  # 60% of time move toward opponent
				movement_direction = Vector2(direction_to_opponent.x, direction_to_opponent.z)
			else:  # 40% of time circle/evade
				var perpendicular = Vector2(-direction_to_opponent.z, direction_to_opponent.x)
				movement_direction = perpendicular * (1 if randf() < 0.5 else -1)
		
		Personality.RUNNER:
			# Build momentum, prefer long runs
			var distance = piao.global_position.distance_to(opponent.global_position)
			if distance > 20.0:
				# Run in wide arcs to build speed
				var side_direction = Vector2(-direction_to_opponent.z, direction_to_opponent.x)
				movement_direction = (Vector2(direction_to_opponent.x, direction_to_opponent.z) + side_direction * 0.7).normalized()
			else:
				# Close distance with good angle
				movement_direction = Vector2(direction_to_opponent.x, direction_to_opponent.z)
	
	piao.set_ai_input(movement_direction)

func execute_dash() -> void:
	if not opponent:
		return
	
	var dash_direction = Vector2.ZERO
	
	match ai_personality:
		Personality.AGGRESSIVE:
			# Direct dash toward opponent
			var direction_to_opponent = (opponent.global_position - piao.global_position).normalized()
			dash_direction = Vector2(direction_to_opponent.x, direction_to_opponent.z)
		
		Personality.DECEIVER:
			# Dash to where opponent will be (leading the target)
			var predicted_pos = opponent.global_position + opponent.velocity * 0.3
			var direction_to_predicted = (predicted_pos - piao.global_position).normalized()
			dash_direction = Vector2(direction_to_predicted.x, direction_to_predicted.z)
		
		Personality.RUNNER:
			# Use current momentum direction for maximum impact
			if piao.velocity.length() > 5.0:
				var momentum_dir = piao.velocity.normalized()
				dash_direction = Vector2(momentum_dir.x, momentum_dir.z)
			else:
				# Fallback to opponent direction
				var direction_to_opponent = (opponent.global_position - piao.global_position).normalized()
				dash_direction = Vector2(direction_to_opponent.x, direction_to_opponent.z)
	
	# Execute the dash
	piao.start_dash(dash_direction)
	current_state = State.DASHING

func execute_shield() -> void:
	piao.start_shield()
	current_state = State.SHIELDING

func set_personality(personality: Personality) -> void:
	ai_personality = personality
	current_state = State.MOVING  # Reset state when personality changes

func get_debug_info() -> String:
	var personality_names = ["RUNNER", "AGGRESSIVE", "DECEIVER"]
	var state_names = ["MOVING", "PREP_DASH", "DASHING", "SHIELDING", "WAITING"]
	
	return personality_names[ai_personality] + " | " + state_names[current_state]
