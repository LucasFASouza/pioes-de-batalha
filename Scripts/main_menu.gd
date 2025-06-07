extends Control

# Game configuration to pass to battle scene
var game_config = {
	"player2_mode": "human",  # "human", "ai_basic", "ai_aggressive", "ai_deceiver"
	"points_to_win": 5
}

# Menu screens
@onready var main_screen = $MainScreen
@onready var play_screen = $PlayScreen
@onready var cpu_screen = $CPUScreen


func _ready() -> void:
	show_main_screen()

func show_main_screen() -> void:
	hide_all_screens()
	main_screen.visible = true

func show_play_screen() -> void:
	hide_all_screens()
	play_screen.visible = true

func show_cpu_screen() -> void:
	hide_all_screens()
	cpu_screen.visible = true

func hide_all_screens() -> void:
	main_screen.visible = false
	play_screen.visible = false
	cpu_screen.visible = false

# Main Screen Buttons
func _on_play_pressed() -> void:
	show_play_screen()

func _on_quit_pressed() -> void:
	get_tree().quit()

# Play Screen Buttons
func _on_vs_player2_pressed() -> void:
	game_config.player2_mode = "human"
	start_battle()

func _on_vs_cpu_pressed() -> void:
	show_cpu_screen()

func _on_play_back_pressed() -> void:
	show_main_screen()

# CPU Screen Buttons
func _on_basic_pressed() -> void:
	game_config.player2_mode = "ai_basic"
	start_battle()

func _on_aggressive_pressed() -> void:
	game_config.player2_mode = "ai_aggressive"
	start_battle()

func _on_deceiver_pressed() -> void:
	game_config.player2_mode = "ai_deceiver"
	start_battle()

func _on_cpu_back_pressed() -> void:
	show_play_screen()

func start_battle() -> void:
	# Store game config in GameGlobals
	GameGlobals.game_config = game_config
	get_tree().change_scene_to_file("res://Scenes/battle.tscn")
