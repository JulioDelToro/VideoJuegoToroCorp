extends Node2D

# Escena principal de juego: orquesta cámara, terreno, vehículo, HUD y fondo parallax

@onready var vehicle: Vehicle = $Vehicle
@onready var camera: Camera2D = $Camera2D
@onready var terrain_generator: TerrainGenerator = $TerrainGenerator
@onready var hud: GameHUD = $HUD

var start_x: float = 0.0
var game_over_shown: bool = false

func _ready() -> void:
	SoundManager.play_music()
	SoundManager.start_engine()

	_apply_route_environment()

	start_x = vehicle.global_position.x
	terrain_generator.set_target(vehicle)
	hud.set_vehicle(vehicle)

	GameManager.game_over_triggered.connect(_on_game_over)

func _apply_route_environment() -> void:
	var route_data: Dictionary = GameManager.get_selected_route_data()
	var lvl_num: int = int(route_data.get("level_num", 1))
	var default_sky: Color = Color(0.09, 0.19, 0.34)
	var base_sky: Color = route_data.get("sky_color", default_sky) as Color
	var sky_top: Color = route_data.get("sky_top", base_sky) as Color
	var sky_bottom: Color = route_data.get("sky_bottom", sky_top.lightened(0.22)) as Color
	var surface_col: Color = route_data.get("surface_color", Color(0.18, 0.78, 0.42)) as Color
	var accent_col: Color = route_data.get("accent_color", surface_col.lightened(0.2)) as Color

	RenderingServer.set_default_clear_color(sky_top)

	var direct_sky: Node = get_node_or_null("SkyLayer/Sky")
	if direct_sky is ColorRect:
		(direct_sky as ColorRect).color = sky_top
	elif direct_sky is CanvasItem:
		(direct_sky as CanvasItem).modulate = sky_top.lerp(sky_bottom, 0.5)

	var parallax_sky_layer: Node = get_node_or_null("ParallaxBackground/SkyLayer")
	if parallax_sky_layer != null:
		var sky_rect: ColorRect = parallax_sky_layer.get_node_or_null("Sky") as ColorRect
		if sky_rect == null:
			sky_rect = ColorRect.new()
			sky_rect.name = "Sky"
			sky_rect.position = Vector2(0.0, -1200.0)
			sky_rect.size = Vector2(2560.0, 3600.0)
			sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parallax_sky_layer.add_child(sky_rect)
			parallax_sky_layer.move_child(sky_rect, 0)
		sky_rect.color = sky_top

		var sky_sprite: Sprite2D = parallax_sky_layer.get_node_or_null("Sprite2D") as Sprite2D
		if sky_sprite != null:
			if lvl_num == 1:
				sky_sprite.modulate = sky_bottom.lightened(0.48).lerp(Color.WHITE, 0.55)
			elif lvl_num in [3, 7, 10]:
				sky_sprite.modulate = sky_bottom.lightened(0.22).lerp(accent_col, 0.20)
			else:
				sky_sprite.modulate = sky_bottom.lightened(0.38).lerp(accent_col, 0.16)

	var mountains_layer: CanvasItem = get_node_or_null("ParallaxBackground/MountainsLayer") as CanvasItem
	var city_layer: CanvasItem = get_node_or_null("ParallaxBackground/CityLayer") as CanvasItem
	var trees_layer: CanvasItem = get_node_or_null("ParallaxBackground/TreesLayer") as CanvasItem

	var mountains_spr: Sprite2D = get_node_or_null("ParallaxBackground/MountainsLayer/Sprite2D") as Sprite2D
	var city_spr: Sprite2D = get_node_or_null("ParallaxBackground/CityLayer/Sprite2D") as Sprite2D
	var trees_spr: Sprite2D = get_node_or_null("ParallaxBackground/TreesLayer/Sprite2D") as Sprite2D

	match lvl_num:
		1:
			# Nivel 1: Pradera Cyber-Solar (Montañas visibles, Ciudad de fondo visible, Árboles visibles)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = true
			if trees_layer != null: trees_layer.visible = true
			if mountains_spr != null: mountains_spr.modulate = Color.WHITE.lerp(accent_col, 0.12)
			if city_spr != null: city_spr.modulate = Color(0.85, 0.92, 1.0, 0.45)
			if trees_spr != null: trees_spr.modulate = Color.WHITE
		2:
			# Nivel 2: Desierto Magma-Cristal (Sin árboles ni ciudad, montañas dunas rojo-naranja)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = false
			if mountains_spr != null: mountains_spr.modulate = Color(0.96, 0.46, 0.18)
		3:
			# Nivel 3: Jungla Bioluminiscente (Sin ciudad, árboles turquesa/violeta, montañas selváticas)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = true
			if mountains_spr != null: mountains_spr.modulate = Color(0.24, 0.16, 0.42)
			if trees_spr != null: trees_spr.modulate = Color(0.22, 0.88, 0.78).lerp(Color(0.82, 0.32, 1.0), 0.45)
		4:
			# Nivel 4: Glaciar Volcánico (Sin ciudad, árboles azul pálido escarchado, montañas nevadas blancas)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = true
			if mountains_spr != null: mountains_spr.modulate = Color(0.94, 0.97, 1.0)
			if trees_spr != null: trees_spr.modulate = Color(0.68, 0.86, 1.0)
		5:
			# Nivel 5: Cañón Steampunk (Sin árboles, ciudad industrial de cobre/bronce, montañas oxidadas)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = true
			if trees_layer != null: trees_layer.visible = false
			if mountains_spr != null: mountains_spr.modulate = Color(0.65, 0.42, 0.26)
			if city_spr != null: city_spr.modulate = Color(0.86, 0.58, 0.32)
		6:
			# Nivel 6: Pantano Tóxico (Sin ciudad, sin montañas por densa niebla, árboles verde tóxico)
			if mountains_layer != null: mountains_layer.visible = false
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = true
			if trees_spr != null: trees_spr.modulate = Color(0.35, 0.88, 0.22)
		7:
			# Nivel 7: Synthwave (Sin árboles, ciudad nocturna neón magenta/cian, montañas cuadrícula retro)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = true
			if trees_layer != null: trees_layer.visible = false
			if mountains_spr != null: mountains_spr.modulate = Color(0.38, 0.12, 0.58)
			if city_spr != null: city_spr.modulate = Color(1.0, 0.22, 0.76)
		8:
			# Nivel 8: Cumbre Caramelo (Sin ciudad, árboles de algodón rosa dulce, montañas pastel)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = true
			if mountains_spr != null: mountains_spr.modulate = Color(0.96, 0.72, 0.88)
			if trees_spr != null: trees_spr.modulate = Color(1.0, 0.62, 0.82)
		9:
			# Nivel 9: Ruinas Alien-Doradas (Sin ciudad ni árboles, monolitos y montañas doradas)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = false
			if mountains_spr != null: mountains_spr.modulate = Color(0.98, 0.82, 0.26)
		10:
			# Nivel 10: Nebulosa Lunar-Cósmica (Sin ciudad ni árboles, picos lunares cósmicos)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = false
			if trees_layer != null: trees_layer.visible = false
			if mountains_spr != null: mountains_spr.modulate = Color(0.58, 0.64, 0.78)
		_:
			var default_tint: Color = surface_col.lerp(sky_bottom.lightened(0.42), 0.5).lerp(accent_col, 0.18).lerp(Color.WHITE, 0.35)
			if mountains_layer != null: mountains_layer.visible = true
			if city_layer != null: city_layer.visible = true
			if trees_layer != null: trees_layer.visible = true
			if mountains_spr != null: mountains_spr.modulate = default_tint
			if city_spr != null: city_spr.modulate = default_tint.lerp(accent_col.lightened(0.30), 0.15)
			if trees_spr != null: trees_spr.modulate = default_tint



func _process(_delta: float) -> void:
	if not is_instance_valid(vehicle):
		return

	# La cámara sigue al vehículo con suavizado y ajuste de altura
	camera.global_position = vehicle.global_position

	# Actualizar avance en metros
	GameManager.update_distance(vehicle.global_position.x, start_x)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		GameManager.save_game()
		GameManager.start_new_run()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		_toggle_pause()

func _toggle_pause() -> void:
	if get_tree().paused:
		return
	SoundManager.play_sfx("click")
	get_tree().paused = true
	var pause_dialog: Node = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	add_child(pause_dialog)

func _on_game_over(reason: String) -> void:
	if game_over_shown:
		return
	game_over_shown = true

	# Pequeña pausa dramática para que el jugador vea el impacto o la detención
	await get_tree().create_timer(1.2).timeout

	var over_dialog: Node = preload("res://scenes/ui/game_over_dialog.tscn").instantiate()
	add_child(over_dialog)
	over_dialog.call("setup", reason)

