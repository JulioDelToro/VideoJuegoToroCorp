extends Area2D

# Moneda coleccionable ToroCoin (1, 20, 50, 100)
# Mismo diseño con tamaño escalado según valor:
# 1   -> Tamaño chico (normal)
# 20  -> Tamaño mediano
# 50  -> Tamaño grande
# 100 -> Tamaño gigante

@export var coin_value: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var value_label: Label = $Sprite2D/ValueLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var start_y: float = 0.0
var time_passed: float = 0.0
var collected: bool = false
var base_scale: float = 0.70

func _ready() -> void:
	start_y = position.y
	time_passed = randf() * TAU
	body_entered.connect(_on_body_entered)
	apply_value_styling()

func set_value(val: int) -> void:
	coin_value = val
	apply_value_styling()

func apply_value_styling() -> void:
	match coin_value:
		1:
			base_scale = 0.70
			if value_label:
				value_label.text = ""
		20:
			base_scale = 1.20
			if value_label:
				value_label.text = "20"
				value_label.add_theme_font_size_override("font_size", 16)
		50:
			base_scale = 1.70
			if value_label:
				value_label.text = "50"
				value_label.add_theme_font_size_override("font_size", 19)
		100:
			base_scale = 2.35
			if value_label:
				value_label.text = "100"
				value_label.add_theme_font_size_override("font_size", 21)
		_:
			base_scale = 0.70
			if value_label:
				value_label.text = str(coin_value) if coin_value > 1 else ""

	scale = Vector2(base_scale, base_scale)

func _process(delta: float) -> void:
	if collected:
		return
	time_passed += delta * 4.0
	# Animación de flotación y brillo
	sprite.position.y = sin(time_passed) * 5.0
	sprite.scale.x = 0.85 + 0.15 * absf(cos(time_passed * 0.8))
	queue_redraw()

func _draw() -> void:
	if collected:
		return
	var pulse: float = 0.75 + 0.25 * sin(time_passed * 1.5)
	var glow_col: Color = Color(1.0, 0.88, 0.22, 0.18 * pulse)
	if coin_value >= 50:
		glow_col = Color(0.25, 1.0, 0.68, 0.26 * pulse)
	elif coin_value >= 20:
		glow_col = Color(0.25, 0.88, 1.0, 0.24 * pulse)
	draw_circle(Vector2(0.0, sprite.position.y), 26.0 * pulse, glow_col)

func _physics_process(_delta: float) -> void:
	if collected:
		return
	# Detección completa de chasis + llantas para que nunca deje monedas atrás
	var vehicle: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if vehicle != null and vehicle.has_method("is_point_in_pickup_range"):
		if bool(vehicle.call("is_point_in_pickup_range", global_position, 32.0)):
			_on_body_entered(vehicle)
	elif vehicle != null and global_position.distance_to(vehicle.global_position) < 110.0:
		_on_body_entered(vehicle)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	# Si colisiona el vehículo o las ruedas
	if body is Vehicle or body.name.ends_with("Wheel") or body.get_parent() is Vehicle:
		collected = true
		GameManager.add_coins(coin_value)
		_spawn_floating_text()
		
		# Animación de recogida
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(self, "scale", scale * 1.4, 0.22)
		tw.tween_property(self, "modulate:a", 0.0, 0.22)
		tw.chain().tween_callback(queue_free)

func _spawn_floating_text() -> void:
	var popup: Label = Label.new()
	popup.text = "+%d" % coin_value
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.z_index = 60
	popup.position = global_position + Vector2(-35.0, -30.0)
	
	# Colores distintivos según el valor
	var font_sz: int = 22
	var col: Color = Color(1.0, 0.9, 0.2, 1.0) # Dorado estándar para 1
	if coin_value >= 100:
		font_sz = 34
		col = Color(1.0, 0.65, 0.05, 1.0) # Naranja fuego dorado para 100
	elif coin_value >= 50:
		font_sz = 28
		col = Color(0.2, 1.0, 0.6, 1.0) # Verde esmeralda brillante para 50
	elif coin_value >= 20:
		font_sz = 24
		col = Color(0.25, 0.85, 1.0, 1.0) # Cyan eléctrico para 20
		
	popup.add_theme_font_size_override("font_size", font_sz)
	popup.add_theme_color_override("font_color", col)
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
