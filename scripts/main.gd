extends Node

## Escena raíz — controla el estado general del juego.

@onready var main_menu: Control = $MainMenu
@onready var game_world: Node2D = $GameWorld
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var win_screen: CanvasLayer = $WinScreen

func _ready() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	main_menu.visible = true
	game_world.visible = false
	pause_menu.visible = false
	win_screen.visible = false
	get_tree().paused = false

func _start_game() -> void:
	main_menu.visible = false
	game_world.visible = true
	pause_menu.visible = false
	win_screen.visible = false
	game_world.reset_game()

func _pause_game() -> void:
	pause_menu.visible = true
	get_tree().paused = true

func _resume_game() -> void:
	pause_menu.visible = false
	get_tree().paused = false

func _show_win() -> void:
	win_screen.visible = true
	get_tree().paused = true

func _return_to_menu() -> void:
	_show_main_menu()
