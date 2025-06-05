extends Node3D

# Game state enum
enum GameState {
	VS_SELECTION,
	COUNTDOWN,
	PLAYING,
	GAME_OVER
}

@onready var winner_label: Label = $CanvasLayer/WinnerLabel
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@onready var vs_selection_canvas: CanvasLayer = $VSSelectionCanvas
@onready var players_canvas: CanvasLayer = $PlayersCanvas

@onready var player1_dash_label: Label = $PlayersCanvas/Player1HUD/DashLabel
@onready var player1_shield_label: Label = $PlayersCanvas/Player1HUD/ShieldLabel
@onready var player1_stamina_label: Label = $PlayersCanvas/Player1HUD/StaminaLabel
@onready var player2_dash_label: Label = $PlayersCanvas/Player2HUD/DashLabel
@onready var player2_shield_label: Label = $PlayersCanvas/Player2HUD/ShieldLabel
@onready var player2_stamina_label: Label = $PlayersCanvas/Player2HUD/StaminaLabel

@onready var vs_basic_button: Button = $VSSelectionCanvas/VBoxContainer/VSBasicButton
@onready var vs_aggressive_button: Button = $VSSelectionCanvas/VBoxContainer/VSAggressiveButton
@onready var vs_deceiver_button: Button = $VSSelectionCanvas/VBoxContainer/VSDeceiverButton

var current_state: GameState = GameState.VS_SELECTION
var is_game_over := false
var players := []
var registered_players := []

# Scoring system
var player1_score := 0
var player2_score := 0
var points_to_win := 5  # First to 5 points wins
@onready var points_label: Label = $CanvasLayer/PointsLabel

func _ready() -> void:
	var players_node = get_tree().current_scene.get_node("Players")
	players = players_node.get_children()
	
	setup_initial_ui_state()

func setup_initial_ui_state() -> void:
	players_canvas.visible = false
	winner_label.visible = false
	countdown_label.visible = false
	vs_selection_canvas.visible = true
	
	# Initialize score display
	update_score_display()
	points_label.visible = false
	
	# Hide play again button
	var play_again_button = $CanvasLayer/Button
	play_again_button.visible = false

func register_player(player: CharacterBody3D) -> void:
	if player not in registered_players:
		registered_players.append(player)

func is_game_playing() -> bool:
	return current_state == GameState.PLAYING

func _process(_delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	
	if is_game_over:
		return
	
	# Update HUD
	update_player_hud()
	
	# Check win conditions
	check_fall_condition()
	check_stamina_condition()

func update_player_hud() -> void:
	for player in registered_players:
		if player.player_number == "1":
			player1_dash_label.text = "Dash: " + player.get_dash_status()
			player1_shield_label.text = "Shield: " + player.get_shield_status()
			player1_stamina_label.text = "Stamina: " + player.get_stamina_status()
		elif player.player_number == "2":
			player2_dash_label.text = "Dash: " + player.get_dash_status()
			player2_shield_label.text = "Shield: " + player.get_shield_status()
			player2_stamina_label.text = "Stamina: " + player.get_stamina_status()

func check_fall_condition() -> void:
	for player in players:
		if player.global_position.y < -5:
			var fallen_player_number = player.player_number
			var winner_number = "1" if fallen_player_number == "2" else "2"
			award_points(winner_number, 2, "Jogador " + fallen_player_number + " caiu!")
			break

func check_stamina_condition() -> void:
	var player1 = get_player_by_number("1")
	var player2 = get_player_by_number("2")
	
	if player1 and player2:
		if player1.current_stamina <= 0 and player2.current_stamina > 0:
			freeze_players()
			award_points("2", 1, "Jogador 1 ficou sem stamina!")
		elif player2.current_stamina <= 0 and player1.current_stamina > 0:
			freeze_players()
			award_points("1", 1, "Jogador 2 ficou sem stamina!")
		elif player1.current_stamina <= 0 and player2.current_stamina <= 0:
			freeze_players()
			# Tie - no points awarded, just restart round
			start_new_round("Empate - ambos sem stamina!")

func award_points(winner_number: String, points: int, reason: String) -> void:
	if winner_number == "1":
		player1_score += points
	else:
		player2_score += points
	
	update_score_display()
	
	if player1_score >= points_to_win:
		end_game("1", reason)
	elif player2_score >= points_to_win:
		end_game("2", reason)
	else:
		start_new_round(reason)

func update_score_display() -> void:
	points_label.text = str(player1_score) + "-" + str(player2_score)

func freeze_players() -> void:
	for player in players:
		player.set_physics_process(false)

func unfreeze_players() -> void:
	for player in players:
		player.set_physics_process(true)

func reset_players_position() -> void:
	var player1 = get_player_by_number("1")
	var player2 = get_player_by_number("2")
	
	if player1:
		reset_single_player(player1, Vector3(-22, 2.6, -18))
	
	if player2:
		reset_single_player(player2, Vector3(22, 2.6, 18))

func reset_single_player(player: CharacterBody3D, spawn_position: Vector3) -> void:
	# Reset position and physics
	player.global_position = spawn_position
	player.velocity = Vector3.ZERO
	
	# Reset stamina
	player.current_stamina = player.max_stamina
	
	# Reset dash state and cooldown
	player.is_dashing = false
	player.dash_direction = Vector2.ZERO
	player.dash_timer.stop()
	player.dash_cooldown_timer.stop()
	
	# Reset shield state and cooldown
	player.is_shielding = false
	player.shield_timer.stop()
	player.shield_cooldown_timer.stop()
	
	# Reset collision stun
	player.collision_stun_time = 0.0
	
	# Reset AI input if AI controlled
	if player.is_ai_controlled:
		player.ai_input_direction = Vector2.ZERO

func start_new_round(reason: String) -> void:
	current_state = GameState.COUNTDOWN
	players_canvas.visible = false
	
	# Show reason for round end
	countdown_label.text = reason
	countdown_label.visible = true
	await get_tree().create_timer(2.0).timeout
	
	# Reset players
	reset_players_position()
	unfreeze_players()
	
	# Start countdown
	countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout
	
	# Resume game
	current_state = GameState.PLAYING
	countdown_label.visible = false
	players_canvas.visible = true

func end_game(winner_number: String, reason: String) -> void:
	is_game_over = true
	current_state = GameState.GAME_OVER
	freeze_players()
	
	winner_label.text = "Jogador " + winner_number + " Venceu!\n" + reason
	winner_label.visible = true
	
	# Show play again button
	var play_again_button = $CanvasLayer/Button
	play_again_button.visible = true

func pause_players(paused: bool) -> void:
	for player in players:
		player.set_physics_process(not paused)
		player.set_process(not paused)

func _on_vs_basic_pressed() -> void:
	setup_player2_ai(0)  # Runner
	start_countdown()

func _on_vs_aggressive_pressed() -> void:
	setup_player2_ai(1)  # Aggressive
	start_countdown()

func _on_vs_deceiver_pressed() -> void:
	setup_player2_ai(2)  # Deceiver
	start_countdown()

func _on_vs_p2_pressed() -> void:
	setup_player2_human()
	start_countdown()

func setup_player2_ai(personality: int) -> void:
	var player2 = get_player_by_number("2")
	if player2:
		player2.is_ai_controlled = true
		player2.ai_personality = personality
		# Set up AI if not already done
		if not player2.ai_controller:
			var ai_script = preload("res://Scripts/piao_ai.gd")
			player2.ai_controller = Node.new()
			player2.ai_controller.set_script(ai_script)
			player2.add_child(player2.ai_controller)
			player2.ai_controller.initialize(player2)
		player2.ai_controller.set_personality(personality)
		player2.label_3d.text = "CPU"

func setup_player2_human() -> void:
	var player2 = get_player_by_number("2")
	if player2:
		player2.is_ai_controlled = false
		# Remove AI controller if it exists
		if player2.ai_controller:
			player2.ai_controller.queue_free()
			player2.ai_controller = null
		player2.label_3d.text = "Player 2"

func get_player_by_number(number: String) -> CharacterBody3D:
	for player in players:
		if player.player_number == number:
			return player
	return null

func start_countdown() -> void:
	current_state = GameState.COUNTDOWN
	vs_selection_canvas.visible = false
	countdown_label.visible = true
	
	# Start countdown sequence
	countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout
	
	start_game()

func start_game() -> void:
	current_state = GameState.PLAYING
	countdown_label.visible = false
	players_canvas.visible = true
	points_label.visible = true


func _on_play_again_pressed() -> void:
	# Reset game state
	is_game_over = false
	player1_score = 0
	player2_score = 0
	current_state = GameState.VS_SELECTION
	
	# Reset UI
	winner_label.visible = false
	players_canvas.visible = false
	points_label.visible = false
	var play_again_button = $CanvasLayer/Button
	play_again_button.visible = false
	vs_selection_canvas.visible = true
	
	# Reset players
	reset_players_position()
	unfreeze_players()
	
	# Reset Player 2 to human (remove AI)
	var player2 = get_player_by_number("2")
	if player2:
		player2.is_ai_controlled = false
		if player2.ai_controller:
			player2.ai_controller.queue_free()
			player2.ai_controller = null
		player2.label_3d.text = "Player " + player2.player_number
