extends Node3D

@onready var winner_label: Label = $CanvasLayer/WinnerLabel
@onready var player1_dash_label: Label = $PlayersCanvas/Player1Canvas/DashLabel
@onready var player1_shield_label: Label = $PlayersCanvas/Player1Canvas/ShieldLabel
@onready var player1_stamina_label: Label = $PlayersCanvas/Player1Canvas/StaminaLabel
@onready var player2_dash_label: Label = $PlayersCanvas/Player2Canvas/DashLabel
@onready var player2_shield_label: Label = $PlayersCanvas/Player2Canvas/ShieldLabel
@onready var player2_stamina_label: Label = $PlayersCanvas/Player2Canvas/StaminaLabel

var is_game_over := false
var players := []
var registered_players := []

func _ready() -> void:
	var players_node = get_tree().current_scene.get_node("Players")
	players = players_node.get_children()

func register_player(player: CharacterBody3D) -> void:
	if player not in registered_players:
		registered_players.append(player)

func _process(_delta: float) -> void:
	if is_game_over:
		return
	
	for player in registered_players:
		if player.player_number == "1":
			player1_dash_label.text = "Dash: " + player.get_dash_status()
			player1_shield_label.text = "Shield: " + player.get_shield_status()
			player1_stamina_label.text = "Stamina: " + player.get_stamina_status()
		elif player.player_number == "2":
			player2_dash_label.text = "Dash: " + player.get_dash_status()
			player2_shield_label.text = "Shield: " + player.get_shield_status()
			player2_stamina_label.text = "Stamina: " + player.get_stamina_status()
	
	for player in players:
		if player.global_position.y < -10:
			is_game_over = true
			var fallen_player_number = player.player_number
			var winner_player = "1" if fallen_player_number == "2" else "2"
			
			winner_label.text = "Jogador " + winner_player + " Venceu! :)"
			winner_label.visible = true
			
			await get_tree().create_timer(1.5).timeout
			get_tree().reload_current_scene()
			break
