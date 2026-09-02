extends CanvasLayer

## Menú de pausa — CONTINUAR y MENÚ PRINCIPAL.

@onready var btn_resume: Button = $PanelContainer/VBox/BtnResume
@onready var btn_menu: Button = $PanelContainer/VBox/BtnMenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(_on_resume)
	btn_menu.pressed.connect(_on_menu)

func _on_resume() -> void:
	get_parent()._resume_game()

func _on_menu() -> void:
	get_parent()._return_to_menu()
