extends Node3D

@onready var winner_label: Label3D = $WinnerLabel
var is_game_over := false
var players := []

func _ready() -> void:
	var players_node = get_tree().current_scene.get_node("Players")
	players = players_node.get_children()

func _process(_delta: float) -> void:
	if is_game_over:
		return
	
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
