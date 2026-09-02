extends CanvasLayer

## Diálogo de acertijo — muestra pregunta, recibe respuesta, valida.

signal riddle_answered(correct: bool, door_pos: Vector2i)

var current_riddle: Dictionary = {}
var current_door: Vector2i = Vector2i.ZERO

@onready var panel: PanelContainer = $PanelContainer
@onready var lbl_title: Label = $PanelContainer/VBox/LblTitle
@onready var lbl_question: Label = $PanelContainer/VBox/LblQuestion
@onready var input_field: LineEdit = $PanelContainer/VBox/InputField
@onready var lbl_feedback: Label = $PanelContainer/VBox/LblFeedback
@onready var btn_answer: Button = $PanelContainer/VBox/HBoxButtons/BtnAnswer
@onready var btn_close: Button = $PanelContainer/VBox/HBoxButtons/BtnClose

func _ready() -> void:
	visible = false
	btn_answer.pressed.connect(_on_answer)
	btn_close.pressed.connect(_on_close)
	input_field.text_submitted.connect(_on_text_submitted)

func show_riddle(riddle: Dictionary, door_pos: Vector2i) -> void:
	current_riddle = riddle
	current_door = door_pos
	lbl_question.text = riddle["pregunta"]
	input_field.text = ""
	lbl_feedback.text = ""
	lbl_feedback.visible = false
	visible = true
	input_field.grab_focus()

func _normalize(s: String) -> String:
	# Quitar acentos para comparación flexible
	var result := s.to_lower().strip_edges()
	result = result.replace("á", "a").replace("é", "e").replace("í", "i")
	result = result.replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	return result

func _check_answer() -> void:
	var user_answer = _normalize(input_field.text)
	var correct_answer = _normalize(current_riddle["respuesta"])

	if user_answer == correct_answer:
		lbl_feedback.text = "¡Correcto! Puerta desbloqueada."
		lbl_feedback.add_theme_color_override("font_color", Color(0.25, 0.73, 0.31))
		lbl_feedback.visible = true
		riddle_answered.emit(true, current_door)
		# Cerrar después de un momento
		await get_tree().create_timer(1.0).timeout
		_on_close()
	else:
		lbl_feedback.text = "Incorrecto. Intenta de nuevo."
		lbl_feedback.add_theme_color_override("font_color", Color(0.97, 0.32, 0.29))
		lbl_feedback.visible = true

func _on_answer() -> void:
	_check_answer()

func _on_text_submitted(_text: String) -> void:
	_check_answer()

func _on_close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close()
		get_viewport().set_input_as_handled()
