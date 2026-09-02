extends Control

@onready var btn_play: Button = $BtnPlay
@onready var btn_options: Button = $BtnOptions
@onready var btn_exit: Button = $BtnExit

@onready var bg_video: VideoStreamPlayer = $BackgroundVideo

func _ready() -> void:
	btn_play.pressed.connect(_on_play)
	btn_options.pressed.connect(_on_options)
	btn_exit.pressed.connect(_on_exit)
	
	# Asegurar bucle del video
	bg_video.finished.connect(_on_video_finished)
	if not bg_video.is_playing():
		bg_video.play()

func _on_video_finished() -> void:
	bg_video.play()

func _on_play() -> void:
	var main = get_parent()
	main._start_game()

func _on_options() -> void:
	print("Menú de opciones (en desarrollo...)")

func _on_exit() -> void:
	get_tree().quit()
