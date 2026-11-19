extends Area2D

# Bidón de combustible coleccionable

@onready var sprite: Sprite2D = $Sprite2D
var start_y: float = 0.0
var time_passed: float = 0.0
var collected: bool = false

func _ready() -> void:
	start_y = position.y
	time_passed = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if collected:
		return
	time_passed += delta * 3.5
	# Animación de flotación suave y balanceo
	sprite.position.y = sin(time_passed) * 5.0
	sprite.rotation = sin(time_passed * 0.8) * 0.1
	queue_redraw()

func _draw() -> void:
	if collected:
		return
	var pulse: float = 0.75 + 0.25 * sin(time_passed * 2.0)
	var glow_col: Color = Color(0.98, 0.45, 0.15, 0.24 * pulse)
	draw_circle(Vector2(0.0, sprite.position.y), 32.0 * pulse, glow_col)

func _physics_process(_delta: float) -> void:
	if collected:
		return
	# Detección completa de chasis + llantas para no dejar combustible atrás
	var vehicle: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if vehicle != null and vehicle.has_method("is_point_in_pickup_range"):
		if bool(vehicle.call("is_point_in_pickup_range", global_position, 34.0)):
			_on_body_entered(vehicle)
	elif vehicle != null and global_position.distance_to(vehicle.global_position) < 115.0:
		_on_body_entered(vehicle)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body is Vehicle or body.name.ends_with("Wheel") or body.get_parent() is Vehicle:
		collected = true
		GameManager.add_fuel(85.0)
		_spawn_floating_text()
		
		# Animación de recogida
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25)
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(queue_free)

func _spawn_floating_text() -> void:
	var popup: Label = Label.new()
	popup.text = "+GASOLINA ⛽"
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.z_index = 60
	popup.position = global_position + Vector2(-60.0, -35.0)
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", Color(1.0, 0.35, 0.15, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	popup.add_theme_constant_override("shadow_offset_x", 2)
	popup.add_theme_constant_override("shadow_offset_y", 2)
	
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(popup)
	else:
		get_tree().current_scene.add_child(popup)
		
	var tw: Tween = popup.create_tween().set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 70.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.65).set_delay(0.25)
	tw.chain().tween_callback(popup.queue_free)
