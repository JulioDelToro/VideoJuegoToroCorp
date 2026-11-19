extends Control

# Menú principal de TOROCORP: Odisea Antigravedad
# El video animado se reproduce como fondo en loop.
# Los botones funcionales se colocan encima del video, tapando los botones dibujados en él.

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var btn_play: Button = $ButtonOverlay/VBoxButtons/BtnPlay
@onready var btn_garage: Button = $ButtonOverlay/VBoxButtons/BtnGarage

@onready var label_coins: Label = $TopStats/CoinsBox/CoinsLabel
@onready var label_record: Label = $TopStats/RecordLabel

func _ready() -> void:
	# Reproducir el video en loop como fondo animado
	video_player.play()
	# Silenciar el audio del video porque usamos nuestro propio SoundManager
	video_player.volume_db = -80.0
	
	SoundManager.play_music()
	SoundManager.stop_engine()
	SoundManager.set_thruster_active(false)
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_garage.pressed.connect(_on_garage_pressed)
	
	for b in [btn_play, btn_garage]:
		b.mouse_entered.connect(func(): SoundManager.play_sfx("click", 1.2))
		
	_update_stats()
	_animate_intro()

func _process(_delta: float) -> void:
	# Reiniciar el video si terminó (loop manual)
	if not video_player.is_playing():
		video_player.play()

func _update_stats() -> void:
	label_coins.text = str(GameManager.total_coins)
	label_record.text = "MEJOR RÉCORD: %d m" % int(GameManager.high_score_distance)

func _animate_intro() -> void:
	var tw = create_tween().set_loops()
	tw.tween_property(btn_play, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn_play, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)

func _on_play_pressed() -> void:
	SoundManager.play_sfx("click")
	GameManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_garage_pressed() -> void:
	SoundManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/garage.tscn")
