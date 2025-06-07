extends Node3D

# Game state enum (only for battle)
enum BattleState {
	COUNTDOWN,
	PLAYING,
	PAUSED,
	ROUND_END,
	GAME_OVER
}

# UI References
@onready var winner_label: Label = $UI/WinnerLabel
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var points_label: Label = $UI/PointsLabel
@onready var back_button: Button = $UI/BackButton
@onready var play_again_button: Button = $UI/PlayAgainButton
@onready var pause_button: Button = $UI/PauseButton
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_button: Button = $UI/PauseMenu/PauseCenterContainer/PauseVBoxContainer/PauseButtonsContainer/ResumeButton
@onready var pause_main_menu_button: Button = $UI/PauseMenu/PauseCenterContainer/PauseVBoxContainer/PauseButtonsContainer/MainMenuButton

@onready var players_hud: CanvasLayer = $PlayersHUD
@onready var player1_dash_label: Label = $PlayersHUD/Player1HUD/DashLabel
@onready var player1_shield_label: Label = $PlayersHUD/Player1HUD/ShieldLabel
@onready var player1_stamina_label: Label = $PlayersHUD/Player1HUD/StaminaLabel
@onready var player2_dash_label: Label = $PlayersHUD/Player2HUD/DashLabel
@onready var player2_shield_label: Label = $PlayersHUD/Player2HUD/ShieldLabel
@onready var player2_stamina_label: Label = $PlayersHUD/Player2HUD/StaminaLabel

# Game state
var current_state: BattleState = BattleState.COUNTDOWN
var previous_state: BattleState = BattleState.COUNTDOWN
var is_game_over := false
var players := []

# Score tracking
var player1_score := 0
var player2_score := 0
var points_to_win := 5

# Game configuration fallback
var default_config = {
	"player2_mode": "human",
	"points_to_win": 5
}


func _ready() -> void:
	# Get players from scene
	var players_node = get_tree().current_scene.get_node("Players")
	players = players_node.get_children()
	
	# Load game configuration
	var config = default_config
	if has_node("/root/GameGlobals"):
		var globals = get_node("/root/GameGlobals")
		if globals and globals.game_config:
			config = globals.game_config
		points_to_win = config.points_to_win
		setup_player2_mode_from_config(config)
	else:
		print("GameGlobals not available, using default config")
		points_to_win = default_config.points_to_win
		setup_player2_human(get_player_by_number("2"))
	
	# Ensure Player 1 is always human
	ensure_player1_is_human()
	
	# Ensure Player 1 is human controlled
	ensure_player1_is_human()
	
	# Setup initial UI
	setup_initial_ui_state()
	
	# Ensure pause menu can process when paused
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Ensure battle manager can process when paused (to handle ESC key)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Start the battle
	start_countdown()

func setup_player2_mode() -> void:
	var player2 = get_player_by_number("2")
	if not player2:
		push_error("Player 2 not found!")
		return
	
	if not GameGlobals:
		push_error("GameGlobals not available!")
		setup_player2_human(player2)
		return
	
	var mode = GameGlobals.game_config.player2_mode
	
	if mode == "human":
		setup_player2_human(player2)
	else:
		var personality = GameGlobals.get_ai_personality_from_mode(mode)
		setup_player2_ai(player2, personality)

func setup_player2_human(player2: CharacterBody3D) -> void:
	player2.is_ai_controlled = false
	if player2.ai_controller:
		player2.ai_controller.queue_free()
		player2.ai_controller = null
	# Defer label update to next frame to ensure @onready variables are ready
	call_deferred("update_player_label", player2, "Player 2")

func setup_player2_ai(player2: CharacterBody3D, personality: int) -> void:
	player2.is_ai_controlled = true
	player2.ai_personality = personality
	
	if not player2.ai_controller:
		var ai_script = preload("res://Scripts/piao_ai.gd")
		player2.ai_controller = Node.new()
		player2.ai_controller.set_script(ai_script)
		player2.add_child(player2.ai_controller)
		player2.ai_controller.initialize(player2)
	
	player2.ai_controller.set_personality(personality)
	# Defer label update to next frame to ensure @onready variables are ready
	call_deferred("update_player_label", player2, "CPU")

func setup_initial_ui_state() -> void:
	players_hud.visible = false
	winner_label.visible = false
	countdown_label.visible = false
	points_label.visible = false
	back_button.visible = false
	play_again_button.visible = false
	pause_button.visible = false
	pause_menu.visible = false
	
	update_score_display()

func get_player_by_number(number: String) -> CharacterBody3D:
	for player in players:
		if player.player_number == number:
			return player
	return null

func is_game_playing() -> bool:
	return current_state == BattleState.PLAYING

func _process(_delta: float) -> void:
	# Handle ESC key for pause
	if Input.is_action_just_pressed("ui_cancel"):
		if current_state == BattleState.PLAYING:
			pause_game()
		elif current_state == BattleState.PAUSED:
			resume_game()
	
	if current_state != BattleState.PLAYING:
		return
	
	if is_game_over:
		return
	
	# Update HUD
	update_player_hud()
	
	# Check win conditions
	check_fall_condition()
	check_stamina_condition()

func update_player_hud() -> void:
	for player in players:
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

func start_countdown() -> void:
	current_state = BattleState.COUNTDOWN
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
	current_state = BattleState.PLAYING
	countdown_label.visible = false
	players_hud.visible = true
	points_label.visible = true
	pause_button.visible = true

func start_new_round(reason: String) -> void:
	current_state = BattleState.ROUND_END
	players_hud.visible = false
	pause_button.visible = false
	
	# Show reason for round end
	countdown_label.text = reason
	countdown_label.visible = true
	await get_tree().create_timer(2.0).timeout
	
	# Reset players
	reset_players_position()
	unfreeze_players()
	
	# Start countdown
	start_countdown()

func end_game(winner_number: String, reason: String) -> void:
	is_game_over = true
	current_state = BattleState.GAME_OVER
	freeze_players()
	
	# Hide gameplay UI
	players_hud.visible = false
	pause_button.visible = false
	
	winner_label.text = "Jogador " + winner_number + " Venceu!\n" + reason
	winner_label.visible = true
	
	# Show end game buttons
	play_again_button.visible = true
	back_button.visible = true

func _on_play_again_pressed() -> void:
	# Reset game state
	is_game_over = false
	player1_score = 0
	player2_score = 0
	update_score_display()
	
	# Reset UI
	winner_label.visible = false
	players_hud.visible = false
	points_label.visible = false
	play_again_button.visible = false
	back_button.visible = false
	
	# Reset players
	reset_players_position()
	unfreeze_players()
	
	# Restart battle
	start_countdown()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func setup_player2_mode_from_config(config: Dictionary) -> void:
	var player2 = get_player_by_number("2")
	if not player2:
		push_error("Player 2 not found!")
		return
	
	var mode = config.player2_mode
	
	if mode == "human":
		setup_player2_human(player2)
	else:
		var personality = get_ai_personality_from_mode(mode)
		setup_player2_ai(player2, personality)

func get_ai_personality_from_mode(mode: String) -> int:
	match mode:
		"ai_basic":
			return 0  # Runner
		"ai_aggressive":
			return 1  # Aggressive
		"ai_deceiver":
			return 2  # Deceiver
		_:
			return 0  # Default to runner

func update_player_label(player: CharacterBody3D, label_text: String) -> void:
	if player and player.has_node("Label3D"):
		player.get_node("Label3D").text = label_text
	elif player and "label_3d" in player:
		var label = player.get("label_3d")
		if label:
			label.text = label_text

func ensure_player1_is_human() -> void:
	var player1 = get_player_by_number("1")
	if player1:
		player1.is_ai_controlled = false
		if player1.ai_controller:
			player1.ai_controller.queue_free()
			player1.ai_controller = null
		call_deferred("update_player_label", player1, "Player 1")

func pause_game() -> void:
	if current_state == BattleState.PLAYING:
		print("Pausing game...")
		previous_state = current_state
		current_state = BattleState.PAUSED
		get_tree().paused = true
		
		# Esconder UI do jogo
		players_hud.visible = false
		pause_button.visible = false
		points_label.visible = false
		
		# Mostrar menu de pausa
		pause_menu.visible = true
		print("Game paused successfully")

func resume_game() -> void:
	if current_state == BattleState.PAUSED:
		print("Resuming game...")
		current_state = previous_state
		get_tree().paused = false
		
		# Esconder menu de pausa
		pause_menu.visible = false
		
		# Restaurar UI do jogo
		players_hud.visible = true
		pause_button.visible = true
		points_label.visible = true
		
		print("Game resumed successfully")

# Pause menu signal handlers
func _on_pause_pressed() -> void:
	pause_game()

func _on_resume_pressed() -> void:
	print("Resuming game")
	resume_game()

func _on_pause_main_menu_pressed() -> void:
	print("Returning to main menu")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
