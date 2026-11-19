extends Control

# Hub Menu - Menú principal estilo taller/garaje de ToroCorp Gaming Rutas
# Muestra el carrusel completo de los 11 vehículos en la plataforma flotante (con compra directa
# desde el mostrador), selector interactivo de los 10 niveles progresivos con temáticas fusionadas,
# icono de tuerca arriba a la derecha, y acceso a Jugar, Mejoras, Vehículos y Tienda.

@onready var bg_rect: ColorRect = $BgRect
@onready var bg_wall_upper: ColorRect = $BgWallUpper
@onready var bg_wall_stripe: ColorRect = $BgWallStripe
@onready var spotlight_beam: Polygon2D = $SpotlightBeam
@onready var floor_line: ColorRect = $FloorLine
@onready var floor_accent: ColorRect = $FloorAccent
@onready var garage_platform: TextureRect = $GaragePlatform

@onready var coins_panel: PanelContainer = $TopBar/CoinsPanel
@onready var label_coins: Label = $TopBar/CoinsPanel/CoinsBox/CoinsLabel
@onready var label_record: Label = $TopBar/RecordPanel/RecordLabel
@onready var btn_settings: TextureButton = $TopBar/BtnSettings

@onready var vehicle_preview: Control = $VehiclePreview
@onready var car_body: TextureRect = $VehiclePreview/CarBody
@onready var wheel_back: TextureRect = $VehiclePreview/WheelBack
@onready var wheel_front: TextureRect = $VehiclePreview/WheelFront
@onready var lock_badge: PanelContainer = $VehiclePreview/LockBadge
@onready var lock_badge_label: Label = $VehiclePreview/LockBadge/LockBadgeLabel

@onready var btn_prev_vehicle: TextureButton = $BtnPrevVehicle
@onready var btn_next_vehicle: TextureButton = $BtnNextVehicle

@onready var vehicle_info_card: PanelContainer = $VehicleInfoCard
@onready var vehicle_name_label: Label = $VehicleInfoCard/VBox/HeaderRow/VehicleName
@onready var vehicle_counter_label: Label = $VehicleInfoCard/VBox/HeaderRow/VehicleCounter
@onready var vehicle_stats_label: Label = $VehicleInfoCard/VBox/VehicleStats
@onready var vehicle_desc_label: Label = $VehicleInfoCard/VBox/VehicleDesc

@onready var route_selector_bar: PanelContainer = $RouteSelectorBar
@onready var btn_prev_route: Button = $RouteSelectorBar/HBox/BtnPrevRoute
@onready var btn_next_route: Button = $RouteSelectorBar/HBox/BtnNextRoute
@onready var route_name_label: Label = $RouteSelectorBar/HBox/RouteInfoBox/RouteNameLabel
@onready var route_stats_label: Label = $RouteSelectorBar/HBox/RouteInfoBox/RouteStatsLabel
@onready var btn_route_action: Button = $RouteSelectorBar/HBox/BtnRouteAction

@onready var btn_play: Button = $ButtonBar/BtnPlay
@onready var btn_upgrades: Button = $ButtonBar/BtnUpgrades
@onready var btn_vehicles: Button = $ButtonBar/BtnVehicles
@onready var btn_shop: Button = $ButtonBar/BtnShop
@onready var panel_layer: CanvasLayer = $PanelLayer

var _active_panel: Control = null
var _preview_vehicle_id: String = "toro_rojo"
var _preview_route_id: String = "nivel_1"
var _float_time: float = 0.0

var _style_green_n: StyleBoxTexture
var _style_green_h: StyleBoxTexture
var _style_green_p: StyleBoxTexture
var _style_amber_n: StyleBoxTexture
var _style_amber_h: StyleBoxTexture
var _style_amber_p: StyleBoxTexture
var _style_red_n: StyleBoxTexture
var _style_red_h: StyleBoxTexture
var _style_red_p: StyleBoxTexture

func _ready() -> void:
	SoundManager.play_music()
	SoundManager.stop_engine()
	SoundManager.set_thruster_active(false)
	
	_init_button_styles()
	
	_preview_vehicle_id = GameManager.selected_vehicle
	if _preview_vehicle_id.is_empty() or not (_preview_vehicle_id in GameManager.VEHICLE_ORDER):
		_preview_vehicle_id = GameManager.VEHICLE_ORDER[0]
	
	_preview_route_id = GameManager.selected_route
	if _preview_route_id.is_empty() or not (_preview_route_id in GameManager.ROUTE_ORDER):
		_preview_route_id = GameManager.ROUTE_ORDER[0]
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_upgrades.pressed.connect(_on_upgrades_pressed)
	btn_vehicles.pressed.connect(_on_vehicles_pressed)
	btn_shop.pressed.connect(_on_shop_pressed)
	
	btn_prev_vehicle.pressed.connect(_on_prev_vehicle)
	btn_next_vehicle.pressed.connect(_on_next_vehicle)
	btn_settings.pressed.connect(_on_settings_pressed)
	
	btn_prev_route.pressed.connect(_on_prev_route)
	btn_next_route.pressed.connect(_on_next_route)
	btn_route_action.pressed.connect(_on_route_action_pressed)
	
	for b in [btn_play, btn_upgrades, btn_vehicles, btn_shop, btn_prev_route, btn_next_route, btn_route_action]:
		b.mouse_entered.connect(func(): SoundManager.play_sfx("click", 1.2))
	
	for tb in [btn_prev_vehicle, btn_next_vehicle, btn_settings]:
		tb.mouse_entered.connect(func():
			SoundManager.play_sfx("click", 1.25)
			var tw: Tween = create_tween()
			tw.tween_property(tb, "scale", Vector2(1.1, 1.1), 0.12)
		)
		tb.mouse_exited.connect(func():
			var tw: Tween = create_tween()
			tw.tween_property(tb, "scale", Vector2.ONE, 0.12)
		)
	
	GameManager.coins_changed.connect(func(_c: int):
		_update_stats()
		_update_vehicle_preview()
		_update_route_selector()
	)
	if GameManager.has_signal("rubies_changed"):
		GameManager.rubies_changed.connect(func(_r: int):
			_update_stats()
		)
	GameManager.vehicle_changed.connect(func(vid: String):
		_preview_vehicle_id = vid
		_update_vehicle_preview()
	)
	GameManager.route_changed.connect(func(rid: String):
		_preview_route_id = rid
		_update_route_selector()
		_update_play_button_label()
	)
	
	_update_stats()
	_update_vehicle_preview()
	_update_route_selector()
	_animate_intro()

func _process(delta: float) -> void:
	# Oscilación suave de la carrocería en posición baja (-14.0 centro promedio) sobre las ruedas
	_float_time += delta
	var bounce_y: float = sin(_float_time * 2.6) * 2.5
	car_body.offset_top = -104.0 + bounce_y
	car_body.offset_bottom = 76.0 + bounce_y
	
	# Rotación suave de las llantas en el mostrador flotante
	var spin_speed: float = 2.4 if GameManager.is_vehicle_owned(_preview_vehicle_id) else 0.45
	wheel_back.rotation = fmod(wheel_back.rotation + delta * spin_speed, TAU)
	wheel_front.rotation = fmod(wheel_front.rotation + delta * spin_speed, TAU)

func _init_button_styles() -> void:
	_style_green_n = _make_tex_style("res://assets/sprites/btn_green_normal.png", 14.0, 22.0)
	_style_green_h = _make_tex_style("res://assets/sprites/btn_green_hover.png", 14.0, 22.0)
	_style_green_p = _make_tex_style("res://assets/sprites/btn_green_pressed.png", 20.0, 16.0)
	
	_style_amber_n = _make_tex_style("res://assets/sprites/btn_amber_normal.png", 14.0, 22.0)
	_style_amber_h = _make_tex_style("res://assets/sprites/btn_amber_hover.png", 14.0, 22.0)
	_style_amber_p = _make_tex_style("res://assets/sprites/btn_amber_pressed.png", 20.0, 16.0)
	
	_style_red_n = _make_tex_style("res://assets/sprites/btn_red_normal.png", 14.0, 22.0)
	_style_red_h = _make_tex_style("res://assets/sprites/btn_red_hover.png", 14.0, 22.0)
	_style_red_p = _make_tex_style("res://assets/sprites/btn_red_pressed.png", 20.0, 16.0)

func _make_tex_style(tex_path: String, top_margin: float, bottom_margin: float) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex:
		sb.texture = tex
	sb.texture_margin_left = 34.0
	sb.texture_margin_right = 34.0
	sb.texture_margin_top = top_margin
	sb.texture_margin_bottom = bottom_margin
	return sb

func _set_btn_theme(btn: Button, n_style: StyleBoxTexture, h_style: StyleBoxTexture, p_style: StyleBoxTexture, shadow_col: Color) -> void:
	btn.add_theme_stylebox_override("normal", n_style)
	btn.add_theme_stylebox_override("hover", h_style)
	btn.add_theme_stylebox_override("pressed", p_style)
	btn.add_theme_stylebox_override("disabled", n_style)
	btn.add_theme_color_override("font_shadow_color", shadow_col)

func _unhandled_input(event: InputEvent) -> void:
	if _active_panel != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_LEFT or key_event.keycode == KEY_A:
			_on_prev_vehicle()
		elif key_event.keycode == KEY_RIGHT or key_event.keycode == KEY_D:
			_on_next_vehicle()
		elif key_event.keycode == KEY_UP or key_event.keycode == KEY_W:
			_on_prev_route()
		elif key_event.keycode == KEY_DOWN or key_event.keycode == KEY_S:
			_on_next_route()

# ── Carrusel de los 11 Vehículos ───────────────────────────────────
func _on_prev_vehicle() -> void:
	_cycle_vehicle(-1)

func _on_next_vehicle() -> void:
	_cycle_vehicle(1)

func _cycle_vehicle(step: int) -> void:
	SoundManager.play_sfx("click", 1.1 if step > 0 else 0.95)
	var order: Array[String] = GameManager.VEHICLE_ORDER
	if order.is_empty():
		return
	var current_idx: int = order.find(_preview_vehicle_id)
	if current_idx == -1:
		current_idx = 0
	var next_idx: int = (current_idx + step + order.size()) % order.size()
	_preview_vehicle_id = order[next_idx]
	
	if GameManager.is_vehicle_owned(_preview_vehicle_id):
		GameManager.select_vehicle(_preview_vehicle_id)
	
	_update_vehicle_preview()
	_animate_vehicle_switch(step)

func _animate_vehicle_switch(step: int) -> void:
	var btn: TextureButton = btn_next_vehicle if step > 0 else btn_prev_vehicle
	var tw_btn: Tween = create_tween()
	tw_btn.tween_property(btn, "scale", Vector2(0.88, 0.88), 0.06)
	tw_btn.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
	
	vehicle_preview.scale = Vector2(0.9, 0.9)
	var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(vehicle_preview, "scale", Vector2.ONE, 0.25)

func _update_stats() -> void:
	label_coins.text = "%d   •   💎 %d" % [GameManager.total_coins, GameManager.total_rubies]
	label_record.text = "🏆 RÉCORD: %d m  •  NIVEL %d/%d" % [int(GameManager.high_score_distance), GameManager.unlocked_level, GameManager.ROUTE_ORDER.size()]

func _get_playable_level_num() -> int:
	if GameManager.is_route_owned(_preview_route_id):
		return GameManager.get_route_level_num(_preview_route_id)
	return GameManager.get_route_level_num(GameManager.selected_route)

func _update_play_button_label() -> void:
	if GameManager.is_vehicle_owned(_preview_vehicle_id):
		var play_lvl: int = _get_playable_level_num()
		btn_play.text = "▶  JUGAR NIVEL %d" % play_lvl
		_set_btn_theme(btn_play, _style_green_n, _style_green_h, _style_green_p, Color(0.04, 0.35, 0.12, 1.0))

func _update_vehicle_preview() -> void:
	var data: Dictionary = GameManager.get_vehicle_data(_preview_vehicle_id)
	if data.is_empty():
		return
	
	var body_tex_path: String = str(data.get("body_texture", ""))
	var body_tex: Texture2D = load(body_tex_path) as Texture2D
	if body_tex:
		car_body.texture = body_tex
	
	var wheel_tex_path: String = str(data.get("wheel_texture", ""))
	var wheel_tex: Texture2D = load(wheel_tex_path) as Texture2D
	if wheel_tex:
		wheel_back.texture = wheel_tex
		wheel_front.texture = wheel_tex
	
	var r_scale: float = float(data.get("rear_wheel_scale", 0.90))
	var f_scale: float = float(data.get("front_wheel_scale", 0.90))
	var r_size: float = 104.0 * r_scale
	var f_size: float = 104.0 * f_scale
	var r_cx: float = float(data.get("rear_wheel_x", -70.0)) * 1.54
	var f_cx: float = float(data.get("front_wheel_x", 70.0)) * 1.54
	
	wheel_back.offset_left = r_cx - r_size * 0.5
	wheel_back.offset_right = r_cx + r_size * 0.5
	wheel_back.offset_bottom = 112.0
	wheel_back.offset_top = 112.0 - r_size
	wheel_back.pivot_offset = Vector2(r_size * 0.5, r_size * 0.5)
	
	wheel_front.offset_left = f_cx - f_size * 0.5
	wheel_front.offset_right = f_cx + f_size * 0.5
	wheel_front.offset_bottom = 112.0
	wheel_front.offset_top = 112.0 - f_size
	wheel_front.pivot_offset = Vector2(f_size * 0.5, f_size * 0.5)
	
	var veh_name: String = str(data.get("name", "???"))
	var veh_desc: String = str(data.get("description", ""))
	var motor_pct: int = int(round(float(data.get("motor_mult", 1.0)) * 100.0))
	var susp_pct: int = int(round(float(data.get("susp_mult", 1.0)) * 100.0))
	var traction_pct: int = int(round(((r_scale + f_scale) * 0.5) * 105.0))
	
	vehicle_name_label.text = veh_name
	vehicle_stats_label.text = "⚡ Motor: %d%%   •   🔩 Suspensión: %d%%   •   🛞 Tracción: %d%%" % [motor_pct, susp_pct, traction_pct]
	vehicle_desc_label.text = veh_desc
	
	var total_vehicles: int = GameManager.VEHICLE_ORDER.size()
	var idx: int = GameManager.VEHICLE_ORDER.find(_preview_vehicle_id)
	if idx == -1:
		idx = 0
	
	var is_owned: bool = GameManager.is_vehicle_owned(_preview_vehicle_id)
	if is_owned:
		car_body.modulate = Color.WHITE
		wheel_back.modulate = Color.WHITE
		wheel_front.modulate = Color.WHITE
		lock_badge.visible = false
		
		vehicle_counter_label.text = "✓ EN TU GARAJE (%d/%d)" % [idx + 1, total_vehicles]
		vehicle_counter_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55, 1.0))
		
		_update_play_button_label()
	else:
		var price: int = int(data.get("price", 0))
		var can_afford: bool = GameManager.total_coins >= price
		
		car_body.modulate = Color(0.34, 0.38, 0.48, 0.84)
		wheel_back.modulate = Color(0.34, 0.38, 0.48, 0.84)
		wheel_front.modulate = Color(0.34, 0.38, 0.48, 0.84)
		lock_badge.visible = true
		lock_badge_label.text = "🔒 BLOQUEADO  •  🪙 %d" % price
		
		vehicle_counter_label.text = "🔒 BLOQUEADO — Precio: 🪙 %d  (%d/%d)" % [price, idx + 1, total_vehicles]
		if can_afford:
			vehicle_counter_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28, 1.0))
			_set_btn_theme(btn_play, _style_amber_n, _style_amber_h, _style_amber_p, Color(0.38, 0.24, 0.04, 1.0))
		else:
			vehicle_counter_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42, 1.0))
			_set_btn_theme(btn_play, _style_red_n, _style_red_h, _style_red_p, Color(0.35, 0.08, 0.08, 1.0))
		
		btn_play.text = "🔓 COMPRAR (🪙 %d)" % price

# ── Selector Interactivo de los 10 Niveles Fusión ──────────────────
func _on_prev_route() -> void:
	_cycle_route(-1)

func _on_next_route() -> void:
	_cycle_route(1)

func _cycle_route(step: int) -> void:
	SoundManager.play_sfx("click", 1.15 if step > 0 else 0.92)
	var routes: Array[String] = GameManager.ROUTE_ORDER
	if routes.is_empty():
		return
	var current_idx: int = routes.find(_preview_route_id)
	if current_idx == -1:
		current_idx = 0
	var next_idx: int = (current_idx + step + routes.size()) % routes.size()
	_preview_route_id = routes[next_idx]
	
	if GameManager.is_route_owned(_preview_route_id):
		GameManager.select_route(_preview_route_id)
	
	_update_route_selector()
	_update_play_button_label()
	
	route_selector_bar.scale = Vector2(0.96, 0.96)
	var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(route_selector_bar, "scale", Vector2.ONE, 0.2)

func _update_route_selector() -> void:
	var r_data: Dictionary = GameManager.get_route_data(_preview_route_id)
	if r_data.is_empty():
		return
	
	var total_routes: int = GameManager.ROUTE_ORDER.size()
	var lvl_num: int = int(r_data.get("level_num", 1))
	var icon: String = str(r_data.get("icon", "🏁"))
	var short_name: String = str(r_data.get("short_name", r_data.get("name", "Nivel"))).to_upper()
	var theme_fusion: String = str(r_data.get("theme_fusion", ""))
	var goal_dist: int = int(round(float(r_data.get("goal_distance", 350.0))))
	var reward_coins: int = int(r_data.get("reward_coins", 250))
	var is_owned: bool = GameManager.is_route_owned(_preview_route_id)
	
	if is_owned:
		route_name_label.text = "%s  NIVEL %d/%d: %s" % [icon, lvl_num, total_routes, short_name]
		route_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
		route_stats_label.text = "%s  •  🏁 Meta: %d m  •  Premio: +%d 🪙" % [theme_fusion, goal_dist, reward_coins]
		route_stats_label.add_theme_color_override("font_color", Color(0.55, 0.96, 0.68, 0.96))
		
		btn_route_action.text = "✓ NIVEL ACTIVO"
		btn_route_action.disabled = true
		_set_btn_theme(btn_route_action, _style_green_n, _style_green_h, _style_green_p, Color(0.04, 0.35, 0.12, 1.0))
	else:
		var prev_lvl: int = max(1, lvl_num - 1)
		var prev_route_id: String = GameManager.ROUTE_ORDER[clampi(prev_lvl - 1, 0, total_routes - 1)]
		var prev_goal: int = int(round(GameManager.get_level_goal_distance(prev_route_id)))
		
		route_name_label.text = "🔒  NIVEL %d/%d: %s" % [lvl_num, total_routes, short_name]
		route_name_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94, 0.92))
		route_stats_label.text = "🔒 Supera el Nivel %d (Meta: %d m) para desbloquear este mapa" % [prev_lvl, prev_goal]
		route_stats_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36, 0.96))
		
		btn_route_action.text = "🔒 SUPERA NIVEL %d" % prev_lvl
		btn_route_action.disabled = false
		_set_btn_theme(btn_route_action, _style_amber_n, _style_amber_h, _style_amber_p, Color(0.38, 0.24, 0.04, 1.0))
	
	_tint_stage_for_route(r_data)

func _tint_stage_for_route(r_data: Dictionary) -> void:
	var sky_col: Color = r_data.get("sky_color", Color(0.11, 0.17, 0.29)) as Color
	var surf_col: Color = r_data.get("surface_color", Color(0.22, 0.68, 0.24)) as Color
	
	var target_bg: Color = sky_col.darkened(0.42)
	target_bg.a = 1.0
	var target_wall: Color = sky_col.lightened(0.08)
	target_wall.a = 0.78
	var target_stripe: Color = Color(surf_col.r, surf_col.g, surf_col.b, 0.52)
	var target_beam: Color = Color(surf_col.r, surf_col.g, surf_col.b, 0.09)
	var target_floor: Color = sky_col.darkened(0.22)
	target_floor.a = 1.0
	var target_accent: Color = Color(surf_col.r, surf_col.g, surf_col.b, 0.82)
	var target_plat: Color = Color.WHITE.lerp(surf_col.lightened(0.35), 0.22)
	
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(bg_rect, "color", target_bg, 0.32)
	tw.tween_property(bg_wall_upper, "color", target_wall, 0.32)
	tw.tween_property(bg_wall_stripe, "color", target_stripe, 0.32)
	tw.tween_property(spotlight_beam, "color", target_beam, 0.32)
	tw.tween_property(floor_line, "color", target_floor, 0.32)
	tw.tween_property(floor_accent, "color", target_accent, 0.32)
	tw.tween_property(garage_platform, "modulate", target_plat, 0.32)
	
	var bar_style: StyleBox = route_selector_bar.get_theme_stylebox("panel")
	if bar_style is StyleBoxFlat:
		var flat_copy: StyleBoxFlat = (bar_style as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat_copy.border_color = Color(surf_col.r, surf_col.g, surf_col.b, 0.85)
		route_selector_bar.add_theme_stylebox_override("panel", flat_copy)

func _on_route_action_pressed() -> void:
	# Si el jugador pulsa el badge en un nivel bloqueado, salta directamente a su nivel más alto desbloqueado
	SoundManager.play_sfx("click", 1.05)
	var highest_idx: int = clampi(GameManager.unlocked_level - 1, 0, GameManager.ROUTE_ORDER.size() - 1)
	var highest_route_id: String = GameManager.ROUTE_ORDER[highest_idx]
	_preview_route_id = highest_route_id
	GameManager.select_route(highest_route_id)
	_update_route_selector()
	_update_play_button_label()

# ── Animaciones y Acciones Principales ─────────────────────────────
func _animate_intro() -> void:
	# Pulsación suave del botón Jugar / Comprar
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(btn_play, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn_play, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)

func _animate_unlock_celebration(target: Control) -> void:
	target.scale = Vector2(1.12, 1.12)
	var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(target, "scale", Vector2.ONE, 0.45)

func _shake_control(target: Control) -> void:
	var orig_rot: float = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(target, "rotation_degrees", -4.5, 0.05)
	tw.tween_property(target, "rotation_degrees", 4.5, 0.05)
	tw.tween_property(target, "rotation_degrees", -3.0, 0.05)
	tw.tween_property(target, "rotation_degrees", 3.0, 0.05)
	tw.tween_property(target, "rotation_degrees", orig_rot, 0.05)

func _on_play_pressed() -> void:
	if GameManager.is_vehicle_owned(_preview_vehicle_id):
		SoundManager.play_sfx("click")
		GameManager.select_vehicle(_preview_vehicle_id)
		if GameManager.is_route_owned(_preview_route_id):
			GameManager.select_route(_preview_route_id)
		else:
			var highest_idx: int = clampi(GameManager.unlocked_level - 1, 0, GameManager.ROUTE_ORDER.size() - 1)
			var highest_route_id: String = GameManager.ROUTE_ORDER[highest_idx]
			GameManager.select_route(highest_route_id)
		GameManager.start_new_run()
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	else:
		if GameManager.can_buy_vehicle(_preview_vehicle_id):
			if GameManager.buy_vehicle(_preview_vehicle_id):
				GameManager.select_vehicle(_preview_vehicle_id)
				_update_stats()
				_update_vehicle_preview()
				_update_route_selector()
				_animate_unlock_celebration(vehicle_preview)
		else:
			SoundManager.play_sfx("click", 0.75)
			_shake_control(btn_play)
			_shake_control(vehicle_info_card)
			_shake_control(coins_panel)
			_show_panel("res://scenes/ui/shop_panel.tscn")

func _on_upgrades_pressed() -> void:
	SoundManager.play_sfx("click")
	_show_panel("res://scenes/ui/upgrades_panel.tscn")

func _on_vehicles_pressed() -> void:
	SoundManager.play_sfx("click")
	_show_panel("res://scenes/ui/vehicles_panel.tscn")

func _on_shop_pressed() -> void:
	SoundManager.play_sfx("click")
	_show_panel("res://scenes/ui/shop_panel.tscn")

func _on_settings_pressed() -> void:
	SoundManager.play_sfx("click")
	var tw: Tween = create_tween()
	tw.tween_property(btn_settings, "rotation_degrees", btn_settings.rotation_degrees + 90.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_settings_modal()

func _show_settings_modal() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)
	
	var card: PanelContainer = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -280
	card.offset_top = -190
	card.offset_right = 280
	card.offset_bottom = 190
	card.pivot_offset = Vector2(280, 190)
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.17, 0.98)
	style.border_color = Color(0.3, 0.75, 0.98, 0.85)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 16
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "⚙ CONFIGURACIÓN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vbox.add_child(title)
	
	var btn_music: Button = Button.new()
	btn_music.custom_minimum_size = Vector2(0, 54)
	btn_music.add_theme_font_size_override("font_size", 22)
	btn_music.text = "🎵 MÚSICA: " + ("ACTIVADA" if SoundManager.music_enabled else "SILENCIADA")
	btn_music.pressed.connect(func():
		SoundManager.set_music_enabled(not SoundManager.music_enabled)
		SoundManager.play_sfx("click")
		btn_music.text = "🎵 MÚSICA: " + ("ACTIVADA" if SoundManager.music_enabled else "SILENCIADA")
	)
	vbox.add_child(btn_music)
	
	var btn_sfx: Button = Button.new()
	btn_sfx.custom_minimum_size = Vector2(0, 54)
	btn_sfx.add_theme_font_size_override("font_size", 22)
	btn_sfx.text = "🔊 SONIDOS: " + ("ACTIVADOS" if SoundManager.sfx_enabled else "SILENCIADOS")
	btn_sfx.pressed.connect(func():
		SoundManager.set_sfx_enabled(not SoundManager.sfx_enabled)
		SoundManager.play_sfx("click")
		btn_sfx.text = "🔊 SONIDOS: " + ("ACTIVADOS" if SoundManager.sfx_enabled else "SILENCIADOS")
	)
	vbox.add_child(btn_sfx)
	
	var info: Label = Label.new()
	info.text = "Controles: [D / Flecha Der] Acelerar  •  [A / Flecha Izq] Freno y Reversa"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(info)
	
	var btn_close: Button = Button.new()
	btn_close.custom_minimum_size = Vector2(0, 54)
	btn_close.text = "✕ CERRAR"
	btn_close.add_theme_font_size_override("font_size", 22)
	btn_close.pressed.connect(func():
		SoundManager.play_sfx("click")
		_on_panel_closed()
	)
	vbox.add_child(btn_close)
	
	_active_panel = root
	panel_layer.add_child(root)
	
	card.scale = Vector2(0.85, 0.85)
	card.modulate.a = 0.0
	var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "scale", Vector2.ONE, 0.28)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.18)

func _show_panel(scene_path: String) -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
	
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene:
		_active_panel = scene.instantiate() as Control
		if _active_panel.has_signal("closed"):
			_active_panel.connect("closed", _on_panel_closed)
		if _active_panel.has_signal("vehicle_selected"):
			_active_panel.connect("vehicle_selected", func(vid: String):
				_preview_vehicle_id = vid
				_update_vehicle_preview()
			)
		panel_layer.add_child(_active_panel)

func _on_panel_closed() -> void:
	if _active_panel:
		var tw: Tween = create_tween()
		tw.tween_property(_active_panel, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			if _active_panel:
				_active_panel.queue_free()
				_active_panel = null
		)
	_update_stats()
	_update_vehicle_preview()
	_update_route_selector()
