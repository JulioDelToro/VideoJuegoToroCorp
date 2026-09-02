extends CanvasLayer

## Pantalla de victoria — felicitación y regreso al menú.

@onready var btn_menu: Button = $PanelContainer/VBox/BtnMenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_menu.pressed.connect(_on_menu)

func _on_menu() -> void:
	get_parent()._return_to_menu()
