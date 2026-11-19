extends Control

# Intro Splash - Reproduce el video de intro una vez y pasa al Hub Menu

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fade_rect: ColorRect = $FadeRect

var _transitioning := false

func _ready() -> void:
	# Fondo negro durante carga
	fade_rect.color = Color(0, 0, 0, 1)
	
	# Intentar cargar y reproducir el video
	var stream = load("res://assets/video/intro_splash.ogv")
	if stream:
		video_player.stream = stream
		video_player.play()
		video_player.finished.connect(_on_video_finished)
		# Fade-in
		var tw = create_tween()
		tw.tween_property(fade_rect, "color:a", 0.0, 0.5)
	else:
		# Si no hay video, ir directo al hub
		_go_to_hub()

func _input(event: InputEvent) -> void:
	# Cualquier tap/clic/tecla salta el video
	if _transitioning:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			_go_to_hub()

func _process(_delta: float) -> void:
	if not _transitioning and video_player.stream and not video_player.is_playing():
		_go_to_hub()

func _on_video_finished() -> void:
	_go_to_hub()

func _go_to_hub() -> void:
	if _transitioning:
		return
	_transitioning = true
	video_player.stop()
	# Fade-out a negro
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		var err = get_tree().change_scene_to_file("res://scenes/ui/hub_menu.tscn")
		if err != OK:
			push_error("Error changing to hub_menu.tscn: %d" % err)
			# Fallback para no dejar la pantalla en negro
			fade_rect.color.a = 0.0
	)

