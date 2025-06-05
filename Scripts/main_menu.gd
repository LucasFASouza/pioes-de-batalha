extends Control

@onready var initial_container: VBoxContainer = %InitialContainer
@onready var selection_container: HBoxContainer = %SelectionContainer
@onready var p_1_container: VBoxContainer = %P1Container

func _ready() -> void:
	initial_container.visible = true
	selection_container.visible = false

func _on_vs_cpu_button_pressed() -> void:
	initial_container.visible = false
	selection_container.visible = true
	
func _on_back_initial_button_pressed() -> void:
	initial_container.visible = true
	selection_container.visible = false
