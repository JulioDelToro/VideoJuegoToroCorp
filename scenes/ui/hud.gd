extends CanvasLayer
class_name GameHUD

# HUD de partida: Marcador de distancia, monedas, línea del tiempo de progreso del nivel,
# combustible, tacómetro de carreras procedural (RPM + aguja + inclinómetro) y pedales dinámicos.

@onready var distance_label: Label = $TopBar/LeftBox/DistanceLabel
@onready var record_label: Label = $TopBar/LeftBox/RecordLabel
@onready var coins_label: Label = $TopBar/LeftBox/CoinsContainer/CoinsLabel

@onready var timeline_panel: PanelContainer = $TopBar/TimelinePanel
@onready var route_label: Label = $TopBar/TimelinePanel/TimelineVBox/RouteLabel
@onready var timeline_track: Control = $TopBar/TimelinePanel/TimelineVBox/TimelineTrack

@onready var fuel_bar: ProgressBar = $TopBar/RightBox/GaugesVBox/FuelContainer/FuelBar
@onready var fuel_warning: Label = $TopBar/RightBox/GaugesVBox/FuelContainer/FuelWarning

@onready var stunt_label: Label = $CenterContainer/StuntLabel
@onready var tacho_gauge: Control = $BottomBar/SpeedPanel/TachoGauge
@onready var speed_label: Label = $BottomBar/SpeedContainer/SpeedLabel
@onready var pitch_label: Label = $BottomBar/SpeedContainer/PitchLabel
@onready var status_badge: Label = $BottomBar/SpeedContainer/StatusBadge

@onready var btn_gas: TextureButton = $BottomBar/RightControls/BtnGas
@onready var btn_brake: TextureButton = $BottomBar/LeftControls/BtnBrake
@onready var btn_pause: TextureButton = $TopBar/RightBox/BtnPause

var vehicle_ref: Vehicle = null
var _vehicle: Vehicle = null
var warning_time: float = 0.0
var _tex_gas_normal: Texture2D
var _tex_gas_pressed: Texture2D
var _tex_brake_normal: Texture2D
var _tex_brake_pressed: Texture2D

# Estado de telemetría del tacómetro e inclinómetro
var _displayed_rpm: float = 0.12
var _target_rpm: float = 0.12
var _pitch_deg: float = 0.0
var _speed_kmh: int = 0
var _is_burning_rubber: bool = false
var _is_wheelie: bool = false
var _gauge_time: float = 0.0
var _needle_jitter: float = 0.0

# Estado de la línea del tiempo del nivel (0.0 a 1.0)
var _level_progress: float = 0.0
var _displayed_level_progress: float = 0.0
var _level_surface_color: Color = Color(0.18, 0.78, 0.42, 1.0)
var _level_highlight_color: Color = Color(0.25, 0.98, 0.78, 1.0)
var _level_accent_color: Color = Color(0.18, 0.95, 0.82, 1.0)
var _completion_banner_shown: bool = false

func _ready() -> void:
	stunt_label.modulate.a = 0.0
	fuel_warning.visible = false
	if status_badge:
		status_badge.text = ""
	
	_tex_gas_normal = btn_gas.texture_normal
	_tex_gas_pressed = btn_gas.texture_pressed
	_tex_brake_normal = btn_brake.texture_normal
	_tex_brake_pressed = btn_brake.texture_pressed
	btn_gas.pivot_offset = Vector2(75, 75)
	btn_brake.pivot_offset = Vector2(75, 75)
	
	GameManager.coins_changed.connect(_on_coins_changed)
	if GameManager.has_signal("rubies_changed"):
		GameManager.rubies_changed.connect(_on_rubies_changed)
	GameManager.distance_updated.connect(_on_distance_updated)
	if GameManager.has_signal("route_changed"):
		GameManager.route_changed.connect(_on_route_changed)
	if GameManager.has_signal("level_completed"):
		GameManager.level_completed.connect(_on_level_completed_signal)
	
	_update_coins_display()
	_update_record_display()
	_update_route_badge()
	
	if tacho_gauge:
		tacho_gauge.draw.connect(_on_tacho_gauge_draw)
		tacho_gauge.queue_redraw()
	if timeline_track:
		timeline_track.draw.connect(_on_timeline_track_draw)
		timeline_track.queue_redraw()
	
	btn_pause.pressed.connect(_on_pause_pressed)
	
	# Pedales táctiles: Gas (acelerar / inclinar atrás) y Freno (freno / reversa / inclinar adelante)
	btn_gas.button_down.connect(func() -> void: Input.action_press("accelerate"))
	btn_gas.button_up.connect(func() -> void: Input.action_release("accelerate"))
	
	btn_brake.button_down.connect(func() -> void: Input.action_press("brake"))
	btn_brake.button_up.connect(func() -> void: Input.action_release("brake"))

func set_vehicle(veh: Vehicle) -> void:
	vehicle_ref = veh
	_vehicle = veh
	if vehicle_ref:
		vehicle_ref.stunt_performed.connect(show_stunt)

func _process(delta: float) -> void:
	_gauge_time += delta
	
	# Barra de combustible
	fuel_bar.max_value = 100.0 * GameManager.get_fuel_capacity_factor()
	fuel_bar.value = GameManager.current_fuel
	
	# Advertencia parpadeante de combustible bajo
	if GameManager.current_fuel < 25.0 and GameManager.current_fuel > 0.0:
		warning_time += delta * 6.0
		fuel_warning.visible = int(warning_time) % 2 == 0
	else:
		fuel_warning.visible = false
		
	# Animación visual dinámica de los pedales (teclado + táctil)
	var gas_active: bool = Input.is_action_pressed("accelerate") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var brake_active: bool = Input.is_action_pressed("brake") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	
	btn_gas.texture_normal = _tex_gas_pressed if gas_active else _tex_gas_normal
	btn_gas.scale = btn_gas.scale.lerp(Vector2(0.92, 0.86) if gas_active else Vector2.ONE, 18.0 * delta)
	
	btn_brake.texture_normal = _tex_brake_pressed if brake_active else _tex_brake_normal
	btn_brake.scale = btn_brake.scale.lerp(Vector2(0.92, 0.86) if brake_active else Vector2.ONE, 18.0 * delta)
		
	# Progreso en la línea del tiempo del nivel actual
	if GameManager.has_method("get_level_progress_ratio"):
		_level_progress = clampf(float(GameManager.get_level_progress_ratio()), 0.0, 1.0)
	else:
		var goal_fallback: float = maxf(1.0, float(GameManager.get_selected_route_data().get("goal_distance", 350.0)))
		_level_progress = clampf(GameManager.current_distance / goal_fallback, 0.0, 1.0)
	_displayed_level_progress = lerpf(_displayed_level_progress, _level_progress, clampf(12.0 * delta, 0.0, 1.0))
	
	if GameManager.current_distance < 2.0 and not GameManager.level_completed_in_run:
		_completion_banner_shown = false
	elif GameManager.level_completed_in_run and not _completion_banner_shown:
		_completion_banner_shown = true
		_on_stunt("🏆 ¡NIVEL COMPLETADO!", GameManager.last_level_reward)
	
	# Velocímetro, Tacómetro RPM e Inclinómetro (Pitch / Wheelie)
	if is_instance_valid(vehicle_ref):
		var vel_len: float = vehicle_ref.linear_velocity.length()
		_speed_kmh = int(vel_len * 0.12)
		speed_label.text = "%d km/h" % _speed_kmh
		
		# Inclinación del chasis en grados (-180° a +180°)
		var wrapped_rot: float = wrapf(vehicle_ref.rotation, -PI, PI)
		_pitch_deg = rad_to_deg(wrapped_rot)
		
		# Lectura de RPM desde _vehicle.get_rpm_ratio() con fallback a velocidad/acelerador/spin
		_target_rpm = _compute_vehicle_rpm(vehicle_ref, gas_active, brake_active)
		_displayed_rpm = lerpf(_displayed_rpm, _target_rpm, clampf(14.0 * delta, 0.0, 1.0))
		
		# Detección de quemado de llanta (burnout) y caballito (wheelie)
		var burnout_val: float = vehicle_ref._burnout_intensity
		var low_speed_burn: bool = (burnout_val > 0.22 and _speed_kmh < 38) or (gas_active and brake_active and _speed_kmh < 22) or (_displayed_rpm > 0.85 and _speed_kmh < 32 and gas_active)
		_is_burning_rubber = low_speed_burn or (_displayed_rpm > 0.85 and burnout_val > 0.15)
		_is_wheelie = absf(_pitch_deg) > 25.0
		
		# Vibración de la aguja en zona roja (> 85% RPM) o quemando llanta
		if _displayed_rpm > 0.85 or _is_burning_rubber:
			_needle_jitter = sin(_gauge_time * 65.0) * 0.022 + randf_range(-0.015, 0.015)
		else:
			_needle_jitter = lerpf(_needle_jitter, 0.0, 15.0 * delta)
		
		var rpm_int: int = int(roundf(_displayed_rpm * 8000.0))
		if pitch_label:
			pitch_label.text = "%d RPM  •  %+d°" % [rpm_int, int(roundf(-_pitch_deg))]
		
		_update_telemetry_status_badge()
	else:
		_displayed_rpm = lerpf(_displayed_rpm, 0.0, 8.0 * delta)
		_needle_jitter = 0.0
		
	if tacho_gauge:
		tacho_gauge.queue_redraw()
	if timeline_track:
		timeline_track.queue_redraw()

func _compute_vehicle_rpm(veh: Vehicle, gas_active: bool, brake_active: bool) -> float:
	if veh.is_crashed or GameManager.current_fuel <= 0.0:
		return 0.0
	var rpm: float = 0.12
	if veh.has_method("get_rpm_ratio"):
		var raw_rpm: Variant = veh.call("get_rpm_ratio")
		rpm = clampf(float(raw_rpm), 0.0, 1.0)
	else:
		var speed_norm: float = clampf(veh.linear_velocity.length() / 680.0, 0.0, 0.88)
		var spin_norm: float = clampf(absf(veh._rear_spin_speed) / 920.0, 0.0, 1.0)
		var burnout_boost: float = clampf(veh._burnout_intensity * 0.94, 0.0, 0.96)
		var throttle_add: float = 0.24 if gas_active else (0.10 if brake_active else 0.0)
		rpm = maxf(0.12, maxf(spin_norm, speed_norm + throttle_add))
		rpm = maxf(rpm, burnout_boost)
	if gas_active and brake_active and veh.linear_velocity.length() < 120.0:
		rpm = maxf(rpm, 0.92)
	elif veh._burnout_intensity > 0.25 and gas_active:
		rpm = maxf(rpm, 0.88)
	return clampf(rpm, 0.0, 1.0)

func _update_telemetry_status_badge() -> void:
	if not status_badge:
		return
	if _is_burning_rubber and _speed_kmh < 40:
		status_badge.text = "🔥 BURNOUT!"
		var pulse_b: float = 0.85 + 0.15 * sin(_gauge_time * 18.0)
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.35 * pulse_b, 0.12, 1.0))
	elif _is_wheelie:
		status_badge.text = "⚡ CABALLITO!"
		var pulse_w: float = 0.85 + 0.15 * sin(_gauge_time * 14.0)
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.88 * pulse_w, 0.18, 1.0))
	else:
		status_badge.text = ""

func _on_timeline_track_draw() -> void:
	if not timeline_track:
		return
	var t_size: Vector2 = timeline_track.size
	var font: Font = ThemeDB.fallback_font
	var track_left: float = 48.0
	var track_right: float = maxf(track_left + 100.0, t_size.x - 58.0)
	var track_width: float = track_right - track_left
	var track_y: float = t_size.y * 0.56
	
	# Etiquetas de extremo: INICIO (0%) y 🏁 META (100%)
	if font:
		timeline_track.draw_string(font, Vector2(2.0, track_y + 4.0), "INICIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.68, 0.82, 0.94, 0.88))
		timeline_track.draw_string(font, Vector2(track_right + 8.0, track_y + 4.0), "🏁 META", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.88, 0.32, 0.96))
	
	# Carril base oscuro con borde sutil
	timeline_track.draw_line(Vector2(track_left, track_y), Vector2(track_right, track_y), Color(0.24, 0.32, 0.44, 0.72), 9.0, true)
	timeline_track.draw_line(Vector2(track_left, track_y), Vector2(track_right, track_y), Color(0.04, 0.06, 0.10, 0.94), 6.5, true)
	
	# Barra de progreso iluminada desde 0% hasta la posición actual del jugador
	var prog: float = clampf(_displayed_level_progress, 0.0, 1.0)
	var fill_x: float = track_left + track_width * prog
	if prog > 0.005:
		var glow_col: Color = Color(_level_accent_color.r, _level_accent_color.g, _level_accent_color.b, 0.32)
		var bar_col: Color = _level_surface_color.lerp(_level_accent_color, 0.4)
		timeline_track.draw_line(Vector2(track_left, track_y), Vector2(fill_x, track_y), glow_col, 12.0, true)
		timeline_track.draw_line(Vector2(track_left, track_y), Vector2(fill_x, track_y), bar_col, 6.0, true)
		timeline_track.draw_line(Vector2(track_left, track_y - 1.3), Vector2(fill_x, track_y - 1.3), _level_highlight_color, 2.0, true)
	
	# 5 nodos de control (checkpoints) en 0%, 25%, 50%, 75% y 100%
	for m_idx in range(5):
		var m_ratio: float = float(m_idx) * 0.25
		var mx: float = track_left + track_width * m_ratio
		var m_pos: Vector2 = Vector2(mx, track_y)
		var reached: bool = prog >= (m_ratio - 0.003)
		var outer_r: float = 6.2 if m_idx == 4 else 4.8
		var inner_r: float = 3.8 if m_idx == 4 else 2.8
		if reached:
			var lit_col: Color = Color(1.0, 0.88, 0.24, 1.0) if m_idx == 4 else _level_highlight_color
			timeline_track.draw_circle(m_pos, outer_r + 2.0, Color(lit_col.r, lit_col.g, lit_col.b, 0.28))
			timeline_track.draw_circle(m_pos, outer_r, Color(0.08, 0.12, 0.18, 0.95))
			timeline_track.draw_circle(m_pos, inner_r, lit_col)
		else:
			timeline_track.draw_circle(m_pos, outer_r, Color(0.22, 0.28, 0.38, 0.92))
			timeline_track.draw_circle(m_pos, inner_r, Color(0.09, 0.12, 0.18, 0.95))
	
	# Pin / marcador animado del vehículo en la posición actual del nivel
	var pin_pos: Vector2 = Vector2(fill_x, track_y)
	var pulse: float = 0.5 + 0.5 * sin(_gauge_time * 10.0)
	timeline_track.draw_circle(pin_pos, 8.5 + 2.0 * pulse, Color(_level_accent_color.r, _level_accent_color.g, _level_accent_color.b, 0.36))
	var chevron_pts: PackedVector2Array = PackedVector2Array([
		pin_pos + Vector2(6.5, 0.0),
		pin_pos + Vector2(-4.0, -5.2),
		pin_pos + Vector2(-2.0, 0.0),
		pin_pos + Vector2(-4.0, 5.2)
	])
	timeline_track.draw_colored_polygon(chevron_pts, Color(1.0, 0.95, 0.35, 1.0))
	timeline_track.draw_circle(pin_pos, 3.0, Color(1.0, 1.0, 1.0, 1.0))
	if font:
		timeline_track.draw_string(font, Vector2(fill_x - 7.0, track_y - 6.5), "🚙", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 1.0, 1.0, 0.98))

func _on_tacho_gauge_draw() -> void:
	if not tacho_gauge:
		return
	var g_size: Vector2 = tacho_gauge.size
	var center: Vector2 = Vector2(g_size.x * 0.5, g_size.y - 78.0)
	var radius: float = 96.0
	var start_angle: float = deg_to_rad(162.0)
	var end_angle: float = deg_to_rad(378.0)
	var sweep: float = end_angle - start_angle
	
	var is_redline: bool = _displayed_rpm > 0.85 or _is_burning_rubber
	var redline_pulse: float = 0.5 + 0.5 * sin(_gauge_time * 22.0) if is_redline else 0.0
	
	# 1. Fondo semicircular oscuro estilo fibra de carbono y bisel exterior
	tacho_gauge.draw_arc(center, radius * 0.62, start_angle - 0.12, end_angle + 0.12, 48, Color(0.05, 0.07, 0.11, 0.86), radius * 0.82, true)
	var bezel_col: Color = Color(0.28, 0.36, 0.48, 0.92).lerp(Color(1.0, 0.22, 0.18, 0.98), redline_pulse * 0.75)
	tacho_gauge.draw_arc(center, radius + 6.0, start_angle - 0.05, end_angle + 0.05, 48, bezel_col, 2.5, true)
	
	if is_redline:
		tacho_gauge.draw_arc(center, radius + 10.0, start_angle + sweep * 0.75, end_angle + 0.05, 24, Color(1.0, 0.18, 0.15, 0.28 + 0.25 * redline_pulse), 6.0, true)
	
	# 2. Zonas de color del dial (Cyan/Verde 0-55% -> Ámbar 55-80% -> Redline 80-100%)
	var z1_end: float = start_angle + sweep * 0.55
	var z2_end: float = start_angle + sweep * 0.80
	tacho_gauge.draw_arc(center, radius - 4.0, start_angle, z1_end, 28, Color(0.12, 0.88, 0.76, 0.24), 8.0, true)
	tacho_gauge.draw_arc(center, radius - 4.0, z1_end, z2_end, 16, Color(0.98, 0.72, 0.15, 0.28), 8.0, true)
	tacho_gauge.draw_arc(center, radius - 4.0, z2_end, end_angle, 16, Color(1.0, 0.18, 0.22, 0.42 + 0.30 * redline_pulse), 9.0, true)
	
	# 3. Arco dinámico iluminado según las RPM actuales
	var clamped_rpm: float = clampf(_displayed_rpm + _needle_jitter, 0.0, 1.0)
	var active_angle: float = start_angle + sweep * clamped_rpm
	if clamped_rpm > 0.01:
		var seg1_end: float = minf(active_angle, z1_end)
		tacho_gauge.draw_arc(center, radius - 4.0, start_angle, seg1_end, 24, Color(0.15, 0.96, 0.84, 0.92), 8.0, true)
		if active_angle > z1_end:
			var seg2_end: float = minf(active_angle, z2_end)
			tacho_gauge.draw_arc(center, radius - 4.0, z1_end, seg2_end, 16, Color(1.0, 0.78, 0.18, 0.95), 8.0, true)
		if active_angle > z2_end:
			tacho_gauge.draw_arc(center, radius - 4.0, z2_end, active_angle, 16, Color(1.0, 0.20, 0.22, 1.0), 10.0, true)
	
	# 4. Marcas de graduación (ticks mayores 0..8 y menores) + números
	var font: Font = ThemeDB.fallback_font
	var total_ticks: int = 32
	for i in range(total_ticks + 1):
		var ratio: float = float(i) / float(total_ticks)
		var ang: float = start_angle + sweep * ratio
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var is_major: bool = (i % 4 == 0)
		var tick_outer: float = radius - 1.0
		var tick_inner: float = radius - (14.0 if is_major else 7.5)
		var tick_col: Color = Color(0.82, 0.94, 1.0, 0.9)
		if ratio >= 0.80:
			tick_col = Color(1.0, 0.25, 0.25, 1.0)
		elif ratio >= 0.55:
			tick_col = Color(1.0, 0.80, 0.25, 0.95)
		elif not is_major:
			tick_col = Color(0.55, 0.72, 0.84, 0.65)
		tacho_gauge.draw_line(center + dir * tick_inner, center + dir * tick_outer, tick_col, 2.4 if is_major else 1.2, true)
		
		if is_major and font:
			var rpm_num: int = i / 4
			var num_pos: Vector2 = center + dir * (radius - 25.0) + Vector2(-4.0, 4.0)
			tacho_gauge.draw_string(font, num_pos, str(rpm_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tick_col)
	
	# 5. Arco interior de telemetría de inclinación (Pitch / Wheelie indicator)
	var pitch_arc_r: float = radius - 38.0
	var pitch_center_ang: float = deg_to_rad(270.0)
	var pitch_span: float = deg_to_rad(55.0)
	tacho_gauge.draw_arc(center, pitch_arc_r, pitch_center_ang - pitch_span, pitch_center_ang + pitch_span, 24, Color(0.25, 0.35, 0.48, 0.45), 3.0, true)
	# Marcas de umbral de caballito (±25°)
	for sign_val in [-1.0, 1.0]:
		var thresh_ang: float = pitch_center_ang + sign_val * deg_to_rad(25.0)
		var td: Vector2 = Vector2(cos(thresh_ang), sin(thresh_ang))
		tacho_gauge.draw_line(center + td * (pitch_arc_r - 4.0), center + td * (pitch_arc_r + 4.0), Color(1.0, 0.78, 0.2, 0.8), 1.8, true)
	var clamped_pitch: float = clampf(-_pitch_deg, -55.0, 55.0)
	var marker_ang: float = pitch_center_ang + deg_to_rad(clamped_pitch)
	var marker_pos: Vector2 = center + Vector2(cos(marker_ang), sin(marker_ang)) * pitch_arc_r
	var pitch_marker_col: Color = Color(1.0, 0.85, 0.2, 1.0) if _is_wheelie else Color(0.25, 0.92, 1.0, 0.95)
	tacho_gauge.draw_circle(marker_pos, 4.2 if _is_wheelie else 3.2, pitch_marker_col)
	
	# 6. Aguja animada de RPM con brillo rojo al quemar llanta / zona roja
	var needle_dir: Vector2 = Vector2(cos(active_angle), sin(active_angle))
	var needle_perp: Vector2 = Vector2(-needle_dir.y, needle_dir.x)
	var needle_tip: Vector2 = center + needle_dir * (radius - 10.0)
	var needle_tail: Vector2 = center - needle_dir * 14.0
	
	if is_redline:
		tacho_gauge.draw_line(needle_tail, needle_tip, Color(1.0, 0.15, 0.15, 0.45 + 0.35 * redline_pulse), 7.0, true)
	
	var needle_pts: PackedVector2Array = PackedVector2Array([
		needle_tip,
		center + needle_perp * 3.8,
		needle_tail,
		center - needle_perp * 3.8
	])
	var needle_col: Color = Color(1.0, 0.22, 0.18, 1.0) if is_redline else Color(1.0, 0.38, 0.18, 0.98)
	tacho_gauge.draw_colored_polygon(needle_pts, needle_col)
	
	# 7. Eje central metálico de la aguja
	tacho_gauge.draw_circle(center, 11.0, Color(0.16, 0.20, 0.28, 1.0))
	tacho_gauge.draw_circle(center, 7.5, Color(0.08, 0.10, 0.15, 1.0))
	tacho_gauge.draw_circle(center, 3.8, Color(1.0, 0.25, 0.20, 1.0) if is_redline else Color(0.20, 0.88, 0.95, 1.0))

func _on_route_changed(_route_id: String) -> void:
	_update_route_badge()

func _on_level_completed_signal(_level_num: int, _unlocked_route_id: String, reward_coins: int) -> void:
	if not _completion_banner_shown:
		_completion_banner_shown = true
		_on_stunt("🏆 ¡NIVEL COMPLETADO!", reward_coins)
	_update_route_badge()

func _update_route_badge() -> void:
	if not route_label:
		return
	var route_data: Dictionary = GameManager.get_selected_route_data()
	var total_levels: int = GameManager.ROUTE_ORDER.size() if "ROUTE_ORDER" in GameManager else 10
	var level_num: int = int(route_data.get("level_num", 1))
	var short_name: String = str(route_data.get("short_name", route_data.get("name", "Pradera Cyber-Solar")))
	var route_icon: String = str(route_data.get("icon", "🌿⚡"))
	var goal_m: int = int(roundf(float(route_data.get("goal_distance", 350.0))))
	var cur_m: int = int(roundf(GameManager.current_distance))
	var pct: int = clampi(int(roundf((float(cur_m) / float(maxi(1, goal_m))) * 100.0)), 0, 100)
	
	route_label.text = "%s NIVEL %d/%d: %s   •   %dm / %dm (%d%%)" % [
		route_icon,
		level_num,
		total_levels,
		short_name.to_upper(),
		cur_m,
		goal_m,
		pct
	]
	
	var surf_var: Variant = route_data.get("surface_color", Color(0.18, 0.78, 0.42))
	_level_surface_color = surf_var if surf_var is Color else Color(0.18, 0.78, 0.42)
	
	var high_var: Variant = route_data.get("surface_highlight", _level_surface_color.lightened(0.35))
	_level_highlight_color = high_var if high_var is Color else _level_surface_color.lightened(0.35)
	
	var acc_var: Variant = route_data.get("accent_color", _level_highlight_color)
	_level_accent_color = acc_var if acc_var is Color else _level_highlight_color
	
	route_label.add_theme_color_override("font_color", _level_surface_color.lightened(0.38))
	if timeline_panel:
		var panel_style: StyleBox = timeline_panel.get_theme_stylebox("panel")
		if panel_style is StyleBoxFlat:
			var flat_style: StyleBoxFlat = panel_style as StyleBoxFlat
			flat_style.border_color = Color(_level_accent_color.r, _level_accent_color.g, _level_accent_color.b, 0.85)
	if timeline_track:
		timeline_track.queue_redraw()

func _on_coins_changed(_new_coins: int) -> void:
	_update_coins_display()

func _on_rubies_changed(_new_rubies: int) -> void:
	_update_coins_display()

func _update_coins_display() -> void:
	if "total_rubies" in GameManager and GameManager.total_rubies > 0:
		coins_label.text = "%d   •   💎 %d" % [GameManager.current_coins, GameManager.total_rubies]
	else:
		coins_label.text = "%d   •   💎 0" % GameManager.current_coins

func _on_distance_updated(dist_m: float) -> void:
	distance_label.text = "%d m" % int(dist_m)
	_update_record_display()
	_update_route_badge()

func _update_record_display() -> void:
	record_label.text = "RÉCORD: %d m" % int(GameManager.high_score_distance)

func _on_stunt(stunt_name: String, reward_coins: int) -> void:
	show_stunt(stunt_name, reward_coins)

func show_stunt(stunt_name: String, reward_coins: int) -> void:
	stunt_label.text = "%s\n+%d MONEDAS" % [stunt_name, reward_coins]
	stunt_label.scale = Vector2(0.5, 0.5)
	stunt_label.modulate.a = 1.0
	
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(stunt_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(stunt_label, "scale", Vector2(1.0, 1.0), 0.2)
	tw.chain().tween_interval(0.8)
	tw.chain().tween_property(stunt_label, "modulate:a", 0.0, 0.4)

func _on_pause_pressed() -> void:
	if get_tree().paused:
		return
	SoundManager.play_sfx("click")
	get_tree().paused = true
	var pause_menu: Node = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	get_tree().current_scene.add_child(pause_menu)
