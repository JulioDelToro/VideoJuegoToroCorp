extends CanvasLayer

# Pantalla de fin de partida (Game Over)

@onready var panel: PanelContainer = $Control/Panel
@onready var title_label: Label = $Control/Panel/Margin/VBox/Title
@onready var reason_label: Label = $Control/Panel/Margin/VBox/ReasonBadge/Reason
@onready var distance_label: Label = $Control/Panel/Margin/VBox/StatsCards/CardDistance/VBox/DistanceVal
@onready var record_label: Label = $Control/Panel/Margin/VBox/StatsCards/CardRecord/VBox/RecordVal
@onready var coins_label: Label = $Control/Panel/Margin/VBox/StatsCards/CardCoins/VBox/CoinsVal
@onready var new_record_badge: PanelContainer = $Control/Panel/Margin/VBox/NewRecordBadge

@onready var btn_retry: Button = $Control/Panel/Margin/VBox/HBoxButtons/BtnRetry
@onready var btn_garage: Button = $Control/Panel/Margin/VBox/HBoxButtons/BtnGarage
@onready var btn_menu: Button = $Control/Panel/Margin/VBox/HBoxButtons/BtnMenu

func setup(reason: String) -> void:
	var goal_dist: int = int(GameManager.get_level_goal_distance())
	var cur_dist: int = int(GameManager.current_distance)
	var route_data: Dictionary = GameManager.get_selected_route_data()
	var lvl_num: int = int(route_data.get("level_num", 1))

	reason_label.text = reason
	distance_label.text = "%d m / %d m" % [cur_dist, goal_dist]
	record_label.text = "%d m" % int(GameManager.high_score_distance)
	coins_label.text = "+%d" % GameManager.current_coins

	if GameManager.level_completed_in_run:
		title_label.text = "🏆 ¡NIVEL SUPERADO!"
		title_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.48, 1.0))
		if lvl_num < GameManager.ROUTE_ORDER.size() and GameManager.unlocked_level <= 10:
			btn_retry.text = "▶  SIGUIENTE NIVEL"
		else:
			btn_retry.text = "🔄 REINTENTAR"
	else:
		title_label.text = "¡FIN DEL CAMINO!"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2, 1.0))
		btn_retry.text = "🔄 REINTENTAR"

	new_record_badge.visible = GameManager.current_distance >= GameManager.high_score_distance and GameManager.current_distance > 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_retry.pressed.connect(_on_retry)
	btn_garage.pressed.connect(_on_garage)
	btn_menu.pressed.connect(_on_menu)

	# Animación dinámica de entrada (pop-in con rebote elástico)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)

func _on_retry() -> void:
	SoundManager.play_sfx("click")
	if GameManager.level_completed_in_run:
		GameManager.advance_to_next_level()
	GameManager.save_game()
	GameManager.start_new_run()
	get_tree().reload_current_scene()

func _on_garage() -> void:
	SoundManager.play_sfx("click")
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/hub_menu.tscn")

func _on_menu() -> void:
	SoundManager.play_sfx("click")
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/hub_menu.tscn")

