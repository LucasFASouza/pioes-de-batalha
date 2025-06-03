extends Node3D

@onready var winner_label: Label3D = $WinnerLabel
var is_game_over := false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if is_game_over:
		return

	is_game_over = true
	
	var fallen_player = body.player_number
	var winner_player = "1" if fallen_player == "2" else "2"
	
	winner_label.text = "Jogador " + winner_player + " Venceu! :)"
	winner_label.visible = true
	
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()
