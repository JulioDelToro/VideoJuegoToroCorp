extends Control

# Menú de Pausa — ToroCorp Gaming Rutas

@onready var panel: PanelContainer = $Panel
@onready var subtitle_label: Label = $Panel/Margin/VBox/Subtitle
@onready var dist_label: Label = $Panel/Margin/VBox/StatsBox/StatsRow/DistLabel
@onready var coins_label: Label = $Panel/Margin/VBox/StatsBox/StatsRow/CoinsLabel
@onready var btn_music: Button = $Panel/Margin/VBox/AudioRow/BtnMusic
@onready var btn_sfx: Button = $Panel/Margin/VBox/AudioRow/BtnSfx
@onready var btn_resume: Button = $Panel/Margin/VBox/BtnResume
@onready var btn_restart: Button = $Panel/Margin/VBox/BtnRestart
@onready var btn_menu: Button = $Panel/Margin/VBox/BtnMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	btn_resume.pressed.connect(_on_resume)
	btn_restart.pressed.connect(_on_restart)
	btn_menu.pressed.connect(_on_menu)
	btn_music.pressed.connect(_on_toggle_music)
	btn_sfx.pressed.connect(_on_toggle_sfx)
	
	var vdata = GameManager.get_selected_vehicle_data()
	subtitle_label.text = "VEHÍCULO: %s" % vdata.get("name", "Toro 4x4").to_upper()
	dist_label.text = "📏 DISTANCIA: %d m" % int(GameManager.current_distance)
	coins_label.text = "🪙 ORO: +%d" % GameManager.current_coins
	_refresh_audio_buttons()
	
	# Animación dinámica de entrada (pop-in elástico)
	panel.scale = Vector2(0.65, 0.65)
	panel.modulate.a = 0.0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

func _refresh_audio_buttons() -> void:
	btn_music.text = "🎵 MÚSICA: " + ("ON" if SoundManager.music_enabled else "OFF")
	btn_sfx.text = "🔊 SONIDO: " + ("ON" if SoundManager.sfx_enabled else "OFF")

func _on_toggle_music() -> void:
	SoundManager.set_music_enabled(not SoundManager.music_enabled)
	SoundManager.play_sfx("click")
	_refresh_audio_buttons()

func _on_toggle_sfx() -> void:
	SoundManager.set_sfx_enabled(not SoundManager.sfx_enabled)
	SoundManager.play_sfx("click")
	_refresh_audio_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_resume()

func _on_resume() -> void:
	SoundManager.play_sfx("click")
	get_tree().paused = false
	queue_free()

func _on_restart() -> void:
	SoundManager.play_sfx("click")
	get_tree().paused = false
	GameManager.save_game()
	GameManager.start_new_run()
	get_tree().reload_current_scene()

func _on_menu() -> void:
	SoundManager.play_sfx("click")
	get_tree().paused = false
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/hub_menu.tscn")
