extends Area2D

@export var ruby_value: int = 1

var start_y: float = 0.0
var time_passed: float = 0.0
var collected: bool = false
var base_scale: float = 0.90

func _ready() -> void:
	start_y = position.y
	time_passed = randf() * TAU
	body_entered.connect(_on_body_entered)
	scale = Vector2(base_scale, base_scale)

func _process(delta: float) -> void:
	if collected:
		return
	time_passed += delta * 4.0
	position.y = start_y + sin(time_passed) * 6.0
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if collected:
		return
	# Detección completa de chasis + llantas para alta velocidad
	var vehicle: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if vehicle != null and vehicle.has_method("is_point_in_pickup_range"):
		if bool(vehicle.call("is_point_in_pickup_range", global_position, 34.0)):
			_on_body_entered(vehicle)
	elif vehicle != null and global_position.distance_to(vehicle.global_position) < 110.0:
		_on_body_entered(vehicle)

func _draw() -> void:
	if collected:
		return
	
	var pulse: float = 0.82 + 0.18 * sin(time_passed * 2.2)
	var shimmer: float = cos(time_passed * 0.9)
	var w_scale: float = 0.85 + 0.15 * absf(shimmer)
	
	# 1. Doble halo de resplandor carmesí pulsante
	draw_circle(Vector2.ZERO, 30.0 * pulse, Color(1.0, 0.05, 0.22, 0.18 * pulse))
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(1.0, 0.18, 0.32, 0.34 * pulse))
	
	# 2. Silueta hexagonal / octogonal tallada de Rubí Real
	var outer_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0 * w_scale, -17.0),
		Vector2(9.0 * w_scale, -17.0),
		Vector2(17.0 * w_scale, -5.0),
		Vector2(0.0, 20.0),
		Vector2(-17.0 * w_scale, -5.0)
	])
	draw_colored_polygon(outer_pts, Color(0.78, 0.02, 0.14, 1.0))
	
	# Faceta izquierda iluminada
	var left_facet: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0 * w_scale, -17.0),
		Vector2(0.0, -5.0),
		Vector2(0.0, 20.0),
		Vector2(-17.0 * w_scale, -5.0)
	])
	draw_colored_polygon(left_facet, Color(0.98, 0.12, 0.28, 1.0))
	
	# Faceta derecha sombreada profunda
	var right_facet: PackedVector2Array = PackedVector2Array([
		Vector2(9.0 * w_scale, -17.0),
		Vector2(17.0 * w_scale, -5.0),
		Vector2(0.0, 20.0),
		Vector2(0.0, -5.0)
	])
	draw_colored_polygon(right_facet, Color(0.56, 0.01, 0.10, 1.0))
	
	# Corona superior brillante
	var crown_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-9.0 * w_scale, -17.0),
		Vector2(9.0 * w_scale, -17.0),
		Vector2(11.0 * w_scale, -6.0),
		Vector2(-11.0 * w_scale, -6.0)
	])
	draw_colored_polygon(crown_pts, Color(1.0, 0.34, 0.48, 1.0))
	
	# Mesa central (table facet) incandescente
	var table_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-5.5 * w_scale, -13.0),
		Vector2(5.5 * w_scale, -13.0),
		Vector2(7.5 * w_scale, -5.0),
		Vector2(0.0, 9.0),
		Vector2(-7.5 * w_scale, -5.0)
	])
	draw_colored_polygon(table_pts, Color(1.0, 0.22, 0.38, 0.95))
	
	# Líneas de aristas cristalinas y destello especular blanco
	draw_polyline(PackedVector2Array([
		Vector2(-9.0 * w_scale, -17.0),
		Vector2(9.0 * w_scale, -17.0),
		Vector2(17.0 * w_scale, -5.0),
		Vector2(0.0, 20.0),
		Vector2(-17.0 * w_scale, -5.0),
		Vector2(-9.0 * w_scale, -17.0)
	]), Color(1.0, 0.75, 0.82, 0.9), 1.6, true)
	
	# Destello estelar animado en la esquina superior
	var glint_alpha: float = clampf(sin(time_passed * 3.0) * 0.5 + 0.5, 0.2, 1.0)
	var glint_pos: Vector2 = Vector2(-5.0 * w_scale, -11.0)
	draw_line(glint_pos + Vector2(-5.0, 0.0), glint_pos + Vector2(5.0, 0.0), Color(1.0, 1.0, 1.0, glint_alpha), 2.0)
	draw_line(glint_pos + Vector2(0.0, -5.0), glint_pos + Vector2(0.0, 5.0), Color(1.0, 1.0, 1.0, glint_alpha), 2.0)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if body is Vehicle or body.name.ends_with("Wheel") or body.get_parent() is Vehicle:
		collected = true
		if GameManager.has_method("add_rubies"):
			GameManager.add_rubies(ruby_value)
		
		_spawn_floating_text()
		_spawn_particles()
		
		# Animación de recogida
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(self, "scale", scale * 1.6, 0.22)
		tw.tween_property(self, "modulate:a", 0.0, 0.22)
		tw.chain().tween_callback(queue_free)

func _spawn_floating_text() -> void:
	var popup: Label = Label.new()
	popup.text = "+%d 💎" % ruby_value
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.z_index = 60
	popup.position = global_position + Vector2(-40.0, -30.0)
	
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", Color(1.0, 0.1, 0.2, 1.0))
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

func _spawn_particles() -> void:
	var part: CPUParticles2D = CPUParticles2D.new()
	part.emitting = true
	part.one_shot = true
	part.explosiveness = 0.9
	part.amount = 15
	part.lifetime = 0.6
	part.spread = 180.0
	part.gravity = Vector2(0.0, 50.0)
	part.initial_velocity_min = 40.0
	part.initial_velocity_max = 80.0
	part.scale_amount_min = 2.0
	part.scale_amount_max = 5.0
	part.color = Color(1.0, 0.2, 0.4, 1.0)
	part.global_position = global_position
	
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.add_child(part)
	else:
		get_tree().current_scene.add_child(part)
		
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(part.queue_free)
	part.add_child(timer)
