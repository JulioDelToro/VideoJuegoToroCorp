extends RigidBody2D
class_name Vehicle

# Vehículo con amortiguadores invisibles elásticos, rebote realista en saltos,
# quemado de llanta (burnout) desde parado y tracción trasera (RWD) con caballito:
# - La carrocería flota sobre las dos llantas con suspensión invisible de largo recorrido.
# - Al caer de un salto, los amortiguadores invisibles se comprimen y rebotan de forma realista,
#   con deformación elástica (squash & stretch) en los neumáticos.
# - Al acelerar estando quieto (o manteniendo Freno + Gas), la llanta trasera patina a altas RPM,
#   quema llanta lanzando humo blanco y tierra, vibra el chasis y engancha tracción con transferencia de peso.
# - Si aceleras de más haces caballito; debes controlarlo en el punto medio con los pedales.
# - Si te volteas, pierdes inmediatamente.

signal crashed
signal out_of_fuel
signal stunt_performed(name: String, reward_coins: int)

const WHEEL_RADIUS: float = 22.0
const RAY_LENGTH: float = 92.0

@export var spring_stiffness: float = 48000.0
@export var spring_damping: float = 950.0
@export var rest_length: float = 68.0
@export var motor_power: float = 34000.0
@export var brake_power: float = 38000.0
@export var fuel_consumption_rate: float = 8.2

@onready var body_sprite: Sprite2D = $BodySprite
@onready var rear_ray: RayCast2D = $RearSuspension/RayCast2D
@onready var front_ray: RayCast2D = $FrontSuspension/RayCast2D
@onready var rear_wheel_sprite: Sprite2D = $RearSuspension/WheelSprite
@onready var front_wheel_sprite: Sprite2D = $FrontSuspension/WheelSprite
@onready var rear_burnout_smoke: CPUParticles2D = $RearSuspension/BurnoutSmoke
@onready var rear_dust: CPUParticles2D = $RearSuspension/DustParticles
@onready var front_dust: CPUParticles2D = $FrontSuspension/DustParticles
@onready var head_detector: Area2D = $DriverHead/HeadArea

var _rear_shapecast: ShapeCast2D = null
var _front_shapecast: ShapeCast2D = null

var is_crashed: bool = false
var is_out_of_fuel: bool = false
var input_gas: float = 0.0
var input_brake: float = 0.0
var gas_hold_time: float = 0.0

# Dinámica elástica de las ruedas (amortiguadores invisibles + rebote + burnout)
var _base_body_pos: Vector2 = Vector2(0, -14)
var _base_rear_scale: Vector2 = Vector2(0.9, 0.9)
var _base_front_scale: Vector2 = Vector2(0.9, 0.9)
var _rear_wheel_vel_y: float = 0.0
var _front_wheel_vel_y: float = 0.0
var _rear_was_grounded: bool = false
var _front_was_grounded: bool = false
var _rear_squash: float = 0.0
var _front_squash: float = 0.0
var _rear_spin_speed: float = 0.0
var _burnout_intensity: float = 0.0
var _chassis_bob_offset: float = 0.0
var _chassis_bob_vel: float = 0.0
var _rpm_ratio: float = 0.10

# Estado en obstáculo de agua (hidroplaneo a alta velocidad vs atasco a baja velocidad)
var _in_water_count: int = 0
var _water_stuck_timer: float = 0.0

# Detección de acrobacias aéreas
var air_time: float = 0.0
var total_rotation: float = 0.0
var previous_rotation: float = 0.0
var flip_count: int = 0

# Temporizador para detectar si queda volcado de cabeza
var upside_down_timer: float = 0.0

# Multiplicadores de agarre de neumáticos y de la ruta activa
var tire_grip_multiplier: float = 1.0
var _route_grip_mult: float = 1.0
var prev_gas: float = 0.0

# Mecánicas de dificultad por nivel
var is_on_ice: bool = false
var current_level_num: int = 1

func _ready() -> void:
	add_to_group("player")
	add_to_group("vehicle")
	_base_body_pos = body_sprite.position
	_apply_upgrades()
	_apply_route_modifiers()
	_setup_wheel_shapecasts()
	head_detector.body_entered.connect(_on_head_touched_ground)
	previous_rotation = rotation
	SoundManager.start_engine()

func set_in_water(active: bool) -> void:
	if active:
		_in_water_count += 1
		if _in_water_count == 1:
			SoundManager.play_landing(0.85) # Sonido de chapoteo al entrar al agua
	else:
		_in_water_count = maxi(0, _in_water_count - 1)
		if _in_water_count == 0:
			_water_stuck_timer = 0.0

func is_in_water() -> bool:
	return _in_water_count > 0

func set_on_ice(active: bool) -> void:
	is_on_ice = active

func apply_turbo_boost(force_x: float) -> void:
	if is_crashed:
		return
	linear_velocity.x += force_x
	linear_velocity.y = min(linear_velocity.y, -110.0)
	_burnout_intensity = 1.0
	if rear_burnout_smoke:
		rear_burnout_smoke.restart()
		rear_burnout_smoke.emitting = true
	SoundManager.play_sfx("boost_burst", 1.3)

func is_point_in_pickup_range(world_pos: Vector2, extra_margin: float = 35.0) -> bool:
	var local_p: Vector2 = to_local(world_pos)
	return local_p.x >= -115.0 - extra_margin and local_p.x <= 130.0 + extra_margin and local_p.y >= -70.0 - extra_margin and local_p.y <= 68.0 + extra_margin


func _apply_route_modifiers() -> void:
	var route_data: Dictionary = GameManager.get_selected_route_data()
	current_level_num = int(route_data.get("level_num", 1))
	var g_scale: float = float(route_data.get("gravity_scale", 1.0))
	gravity_scale = g_scale
	_route_grip_mult = float(route_data.get("grip_mult", 1.0))
	var dust_col: Color = route_data.get("dust_color", Color(0.76, 0.65, 0.48, 0.75))
	if rear_dust:
		rear_dust.color = dust_col
	if front_dust:
		front_dust.color = Color(dust_col.r, dust_col.g, dust_col.b, dust_col.a * 0.9)

func _setup_wheel_shapecasts() -> void:
	_rear_shapecast = _configure_wheel_shapecast($RearSuspension, _base_rear_scale.x)
	_front_shapecast = _configure_wheel_shapecast($FrontSuspension, _base_front_scale.x)

func _configure_wheel_shapecast(mount: Node2D, w_scale: float) -> ShapeCast2D:
	var sc: ShapeCast2D = mount.get_node_or_null("ShapeCast2D") as ShapeCast2D
	if sc == null:
		sc = ShapeCast2D.new()
		sc.name = "ShapeCast2D"
		mount.add_child(sc)
	var circle: CircleShape2D = CircleShape2D.new()
	var radius: float = WHEEL_RADIUS * w_scale * 0.85
	circle.radius = radius
	sc.shape = circle
	sc.position = Vector2.ZERO
	sc.target_position = Vector2(0.0, RAY_LENGTH - radius)
	sc.collision_mask = 1
	sc.max_results = 4
	sc.exclude_parent = true
	sc.enabled = true
	return sc

func _apply_upgrades() -> void:
	var vdata: Dictionary = GameManager.get_selected_vehicle_data()
	if not vdata.is_empty():
		var body_tex_path: String = str(vdata.get("body_texture", "res://assets/sprites/veh_4x4.png"))
		var body_tex: Texture2D = load(body_tex_path) as Texture2D
		if body_tex:
			body_sprite.texture = body_tex
		var wheel_tex_path: String = str(vdata.get("wheel_texture", "res://assets/sprites/wheel.png"))
		var wheel_tex: Texture2D = load(wheel_tex_path) as Texture2D
		if wheel_tex:
			rear_wheel_sprite.texture = wheel_tex
			front_wheel_sprite.texture = wheel_tex
		
		$RearSuspension.position.x = float(vdata.get("rear_wheel_x", -70.0))
		$FrontSuspension.position.x = float(vdata.get("front_wheel_x", 70.0))
		
		var r_scale: float = float(vdata.get("rear_wheel_scale", 0.90))
		var f_scale: float = float(vdata.get("front_wheel_scale", 0.90))
		_base_rear_scale = Vector2(r_scale, r_scale)
		_base_front_scale = Vector2(f_scale, f_scale)
		rear_wheel_sprite.scale = _base_rear_scale
		front_wheel_sprite.scale = _base_front_scale
		
		if vdata.has("driver_pos"):
			var d_pos: Vector2 = vdata["driver_pos"]
			$DriverHead.position = d_pos + Vector2(0, -14)
			
		motor_power *= float(vdata.get("motor_mult", 1.0))
		spring_stiffness *= float(vdata.get("susp_mult", 1.0))
	
	var eng_factor: float = GameManager.get_engine_torque_factor()
	motor_power *= eng_factor
	brake_power *= eng_factor
	
	var stiff_factor: float = GameManager.get_suspension_stiffness_factor()
	var damp_factor: float = GameManager.get_suspension_damping_factor()
	spring_stiffness *= stiff_factor
	spring_damping *= damp_factor
	
	tire_grip_multiplier = GameManager.get_tire_grip_factor()

func _process(delta: float) -> void:
	if is_crashed:
		_rpm_ratio = lerp(_rpm_ratio, 0.0, 10.0 * delta)
		return
	_read_inputs()
	_update_fuel(delta)
	_update_rpm(delta)
	_update_audio()

func _physics_process(delta: float) -> void:
	if is_crashed:
		return
	
	# Resistencia hidrodinámica y atasco en agua: requiere entrar a alta velocidad para cruzar
	if is_in_water():
		if linear_velocity.x > 220.0:
			apply_central_force(-linear_velocity * 18.0)
		elif linear_velocity.x < 170.0:
			apply_central_force(-linear_velocity * 52.0)
		else:
			apply_central_force(-linear_velocity * 32.0)
		
		if linear_velocity.length() < 110.0:
			_water_stuck_timer += delta
			if _water_stuck_timer >= 2.2:
				is_crashed = true
				rear_burnout_smoke.emitting = false
				rear_dust.emitting = false
				front_dust.emitting = false
				SoundManager.play_sfx("crash")
				SoundManager.stop_engine()
				crashed.emit()
				GameManager.trigger_game_over("¡TE QUEDASTE ATASCADO EN EL AGUA! NECESITAS MÁS VELOCIDAD")
				return
		elif linear_velocity.length() >= 130.0:
			_water_stuck_timer = maxf(0.0, _water_stuck_timer - delta * 1.5)
	
	# Procesar amortiguadores invisibles con detección circular híbrida (ShapeCast2D + RayCast2D):
	# Rueda trasera = tracción (is_rear = true), Rueda delantera = libre con amortiguador (false)
	var rear_ground: bool = _apply_wheel_suspension(delta, $RearSuspension, rear_ray, _rear_shapecast, rear_wheel_sprite, rear_dust, true)
	var front_ground: bool = _apply_wheel_suspension(delta, $FrontSuspension, front_ray, _front_shapecast, front_wheel_sprite, front_dust, false)
	var on_ground: bool = rear_ground or front_ground
	
	# Rebote secundario elástico de la carrocería flotante + vibración al quemar llanta
	var bob_spring_f: float = -_chassis_bob_offset * 180.0 - _chassis_bob_vel * 11.0
	_chassis_bob_vel += bob_spring_f * delta
	_chassis_bob_offset = clamp(_chassis_bob_offset + _chassis_bob_vel * delta, -7.0, 8.0)
	
	var shake_vec: Vector2 = Vector2.ZERO
	if _burnout_intensity > 0.05 and rear_ground:
		shake_vec = Vector2(
			randf_range(-1.8, 1.8) * _burnout_intensity,
			randf_range(-2.2, 2.2) * _burnout_intensity
		)
	body_sprite.position = _base_body_pos + Vector2(0, _chassis_bob_offset) + shake_vec
	
	_check_air_and_stunts(delta, on_ground)
	
	# Control de combustible
	if GameManager.current_fuel <= 0.0:
		rear_burnout_smoke.emitting = false
		if not is_out_of_fuel and linear_velocity.length() < 20.0:
			is_out_of_fuel = true
			out_of_fuel.emit()
			GameManager.trigger_game_over("¡SIN COMBUSTIBLE!")
		return
	
	# CONTROL DE CABALLITO (WHEELIE), TRANSFERENCIA DE PESO Y BALANCE CON PEDALES:
	var standing_burnout: bool = input_gas > 0.0 and input_brake > 0.0 and linear_velocity.length() < 110.0
	if input_gas > 0.0 and not standing_burnout:
		gas_hold_time = min(gas_hold_time + delta, 2.5)
	else:
		gas_hold_time = max(0.0, gas_hold_time - delta * 3.5)
		
	if on_ground:
		if standing_burnout and rear_ground:
			# Al quemar llanta parado (Gas + Freno), el coche se agacha de atrás y vibra sin volcarse
			apply_torque(-450000.0)
		elif input_gas > 0.0 and rear_ground:
			# Transferencia de peso realista hacia atrás + caballito progresivo si aceleras de más
			var wheelie_factor: float = clamp((gas_hold_time - 0.12) / 0.85, 0.22, 1.15)
			apply_torque(-1450000.0 * input_gas * wheelie_factor)
			
		if input_brake > 0.0 and not standing_burnout:
			# El pedal izquierdo frena, transfiere peso hacia adelante (hunde la trompa) y baja el caballito
			apply_torque(2150000.0 * input_brake)
		elif input_gas <= 0.0:
			# Si sueltas el acelerador durante un caballito, el peso delantero baja la trompa hacia el amortiguador
			if rear_ground and not front_ground and rotation < -0.05:
				apply_torque(1050000.0)
			angular_velocity = lerp(angular_velocity, 0.0, 3.2 * delta)
	else:
		# En el aire: control dinámico con los pedales
		var target_angular_speed: float = 0.0
		var pitch_control_mult: float = 1.25 if current_level_num == 10 else 1.0
		if input_gas > 0.0:
			target_angular_speed -= 5.8 * input_gas * pitch_control_mult
		if input_brake > 0.0:
			target_angular_speed += 5.8 * input_brake * pitch_control_mult
			
		if input_gas > 0.0 or input_brake > 0.0:
			angular_velocity = lerp(angular_velocity, target_angular_speed, 12.0 * delta)
		else:
			angular_velocity = lerp(angular_velocity, 0.0, 2.2 * delta)

		# Nivel 2 (Desierto Magma-Cristal): Racha de viento de arena en el aire empuja hacia atrás
		if current_level_num == 2:
			apply_central_force(Vector2(-95.0, 0.0))
			
	angular_velocity = clamp(angular_velocity, -4.6, 4.6)
	
	# Verificar si el vehículo se volteó de cabeza contra el suelo
	_check_upside_down(delta, on_ground)

func _check_upside_down(delta: float, on_ground: bool) -> void:
	var current_up: Vector2 = Vector2.UP.rotated(rotation)
	var is_inverted: bool = current_up.y > 0.15
	
	if is_inverted and (on_ground or linear_velocity.length() < 120.0):
		upside_down_timer += delta
		if upside_down_timer > 0.15:
			crash(true)
	else:
		upside_down_timer = max(0.0, upside_down_timer - delta * 3.0)

func _apply_wheel_suspension(delta: float, mount: Node2D, ray: RayCast2D, shapecast: ShapeCast2D, wheel_sprite: Sprite2D, dust: CPUParticles2D, is_rear: bool) -> bool:
	var mount_local_pos: Vector2 = mount.position
	var base_scale: Vector2 = _base_rear_scale if is_rear else _base_front_scale
	var wheel_radius: float = WHEEL_RADIUS * base_scale.x
	var shape_radius: float = wheel_radius * 0.85
	var down_dir: Vector2 = Vector2.DOWN.rotated(rotation)
	var up_dir: Vector2 = -down_dir
	
	var is_grounded: bool = false
	var hit_point: Vector2 = Vector2.ZERO
	var hit_normal: Vector2 = up_dir
	var hit_dist: float = RAY_LENGTH
	
	# 1. Detección volumétrica circular con ShapeCast2D (evita que el borde de la llanta se enganche en crestas)
	if shapecast != null and shapecast.is_colliding():
		var col_count: int = shapecast.get_collision_count()
		var safe_frac: float = shapecast.get_closest_collision_safe_fraction()
		var sweep_len: float = max(0.0, RAY_LENGTH - shape_radius)
		var center_hit_dist: float = safe_frac * sweep_len + shape_radius
		var best_dist: float = RAY_LENGTH + 50.0
		var best_point: Vector2 = mount.global_position + down_dir * center_hit_dist
		var best_normal: Vector2 = up_dir
		for i in range(col_count):
			var cp: Vector2 = shapecast.get_collision_point(i)
			var cn: Vector2 = shapecast.get_collision_normal(i)
			if cn.length_squared() < 0.01 or cn.dot(up_dir) < 0.05:
				cn = up_dir
			var proj_dist: float = (cp - mount.global_position).dot(down_dir)
			var eff_dist: float = clamp(min(proj_dist, center_hit_dist), 0.0, RAY_LENGTH)
			if eff_dist < best_dist:
				best_dist = eff_dist
				best_point = cp
				best_normal = cn.normalized()
		is_grounded = true
		hit_dist = clamp(best_dist, 0.0, RAY_LENGTH)
		hit_point = best_point
		hit_normal = best_normal
	
	# 2. Respaldo y fusión con RayCast2D para máxima fiabilidad en terreno plano y pendientes pronunciadas
	if ray.is_colliding():
		var r_point: Vector2 = ray.get_collision_point()
		var r_normal: Vector2 = ray.get_collision_normal()
		var r_dist: float = max(0.0, (r_point - mount.global_position).dot(down_dir))
		if not is_grounded or r_dist < hit_dist:
			is_grounded = true
			hit_point = r_point
			hit_normal = r_normal if r_normal.length_squared() > 0.01 else up_dir
			hit_dist = r_dist
		elif is_grounded and r_normal.length_squared() > 0.01:
			hit_normal = (hit_normal + r_normal).normalized()
	
	if is_grounded:
		# Compresión del amortiguador invisible (con amplio recorrido activo)
		var compression: float = clamp((rest_length - hit_dist) / rest_length, -0.20, 0.98)
		
		# Velocidad en el punto de suspensión proyectada en la normal del terreno
		var arm_world: Vector2 = mount_local_pos.rotated(rotation)
		var point_vel: Vector2 = linear_velocity + Vector2(-angular_velocity * arm_world.y, angular_velocity * arm_world.x)
		var vel_normal: float = point_vel.dot(hit_normal)
		
		# Detectar aterrizaje desde un salto para generar rebote realista y compresión del neumático
		var was_grounded: bool = _rear_was_grounded if is_rear else _front_was_grounded
		if not was_grounded and vel_normal < -90.0:
			var impact_strength: float = clamp(-vel_normal / 650.0, 0.15, 1.0)
			SoundManager.play_landing(impact_strength)
			if is_rear:
				_rear_squash = impact_strength * 0.32
				_rear_wheel_vel_y = -abs(vel_normal) * 0.35
			else:
				_front_squash = impact_strength * 0.32
				_front_wheel_vel_y = -abs(vel_normal) * 0.35
			_chassis_bob_vel += abs(vel_normal) * 0.42
			dust.restart()
			dust.emitting = true
		
		if is_rear:
			_rear_was_grounded = true
		else:
			_front_was_grounded = true
		
		# Amortiguación asimétrica: absorbe al comprimir (vel_normal < 0) y deja rebotar con vida al extender (vel_normal > 0)
		var effective_damping: float = spring_damping * (1.15 if vel_normal < 0.0 else 0.58)
		var spring_force_mag: float = (compression * spring_stiffness) - (vel_normal * effective_damping)
		
		# Tope hidráulico progresivo al final del recorrido en saltos grandes
		if compression > 0.65:
			spring_force_mag += pow((compression - 0.65) / 0.35, 1.6) * spring_stiffness * 1.85
		spring_force_mag = clamp(spring_force_mag, 0.0, 115000.0)
		
		# Aplicar fuerza de suspensión elástica
		apply_force(hit_normal * spring_force_mag, arm_world)
		
		# Vectores de superficie y velocidad longitudinal
		var ground_tangent: Vector2 = Vector2(-hit_normal.y, hit_normal.x).normalized()
		var forward_dir: Vector2 = Vector2.RIGHT.rotated(rotation)
		var forward_speed: float = linear_velocity.dot(forward_dir)
		var surface_speed: float = point_vel.dot(ground_tangent)
		var effective_grip: float = tire_grip_multiplier * _route_grip_mult
		if is_on_ice:
			effective_grip *= 0.35
		
		# PUNTO DE CONTACTO DEL NEUMÁTICO CON EL SUELO (debajo del centro de masa para transferencia de peso real)
		var contact_arm: Vector2 = (mount_local_pos + Vector2(0, wheel_sprite.position.y + wheel_radius * 0.6)).rotated(rotation)
		
		# TRACCIÓN TRASERA Y QUEMADO DE LLANTA (BURNOUT):
		if is_rear:
			var standing_burnout: bool = input_gas > 0.0 and input_brake > 0.0 and abs(forward_speed) < 110.0
			
			if standing_burnout and GameManager.current_fuel > 0.0:
				# Quemando llanta en el lugar (Freno + Acelerador): la rueda trasera gira a tope soltando humo
				_rear_spin_speed = lerp(_rear_spin_speed, 1100.0, 12.0 * delta)
				_burnout_intensity = lerp(_burnout_intensity, 1.0, 10.0 * delta)
				var hold_force: Vector2 = -ground_tangent * surface_speed * (65.0 * _route_grip_mult)
				apply_force(hold_force, contact_arm)
			elif input_gas > 0.0 and GameManager.current_fuel > 0.0:
				# Al acelerar desde parado o baja velocidad, la llanta trasera primero patina ("quema llanta")
				# y engancha tracción progresivamente según el agarre de la ruta (_route_grip_mult)
				var route_slip_factor: float = 1.0 + (1.0 - _route_grip_mult) * 0.65
				if is_on_ice:
					route_slip_factor *= 2.5
				var target_spin: float = max(surface_speed * 1.15, 780.0 * route_slip_factor)
				_rear_spin_speed = lerp(_rear_spin_speed, target_spin, 14.0 * delta)
				var slip_speed: float = max(0.0, _rear_spin_speed - max(0.0, surface_speed))
				
				# Intensidad del burnout cuando arranca desde quieto o patina en subida / hielo / arena
				if is_on_ice:
					_burnout_intensity = 0.98
				elif abs(forward_speed) < 190.0 or slip_speed > 260.0:
					_burnout_intensity = clamp(slip_speed / 520.0, 0.25, 1.0)
				else:
					_burnout_intensity = lerp(_burnout_intensity, 0.0, 6.0 * delta)
				
				if forward_speed < -15.0:
					var brake_rev: Vector2 = ground_tangent * (brake_power * 1.2 * input_gas * _route_grip_mult)
					apply_force(brake_rev, contact_arm)
				else:
					# Rampa progresiva de tracción: al arrancar primero patina (burnout) y luego engancha suavemente
					var speed_ramp: float = clamp(abs(forward_speed) / 210.0, 0.0, 1.0)
					var time_ramp: float = clamp(gas_hold_time / 0.70, 0.0, 1.0)
					var launch_ramp: float = lerp(0.42, 1.0, max(speed_ramp, time_ramp * 0.85))
					var speed_limit_factor: float = clamp(1.0 - max(0.0, forward_speed - 420.0) / 380.0, 0.15, 1.0)
					var ice_feathering: float = 1.0
					if is_on_ice:
						# En hielo: acelerar a fondo genera deslizamiento total; medio pedal permite traccionar
						ice_feathering = clamp(1.35 - input_gas * 1.0, 0.18, 1.0)
					var drive_f: Vector2 = ground_tangent * (motor_power * input_gas * effective_grip * launch_ramp * speed_limit_factor * ice_feathering)
					if is_in_water():
						drive_f *= 0.22 if absf(forward_speed) < 165.0 else 0.72
					apply_force(drive_f, contact_arm)
			elif input_brake > 0.0:
				_burnout_intensity = lerp(_burnout_intensity, 0.0, 10.0 * delta)
				if forward_speed > 20.0:
					# Frenado con derrape trasero si va rápido
					_rear_spin_speed = lerp(_rear_spin_speed, surface_speed * 0.25, 14.0 * delta)
					var brake_f: Vector2 = -ground_tangent * clamp(forward_speed * 82.0, 9500.0, brake_power) * input_brake * _route_grip_mult
					apply_force(brake_f, contact_arm)
				else:
					# Reversa con tracción trasera
					if GameManager.current_fuel > 0.0:
						_rear_spin_speed = lerp(_rear_spin_speed, min(surface_speed - 250.0, -450.0), 10.0 * delta)
						var reverse_f: Vector2 = -ground_tangent * (motor_power * 0.78 * input_brake * effective_grip)
						if is_in_water():
							reverse_f *= 0.22 if absf(forward_speed) < 165.0 else 0.72
						apply_force(reverse_f, contact_arm)
			else:
				_burnout_intensity = lerp(_burnout_intensity, 0.0, 8.0 * delta)
				_rear_spin_speed = lerp(_rear_spin_speed, surface_speed, 12.0 * delta)
				var roll_friction: Vector2 = -ground_tangent * surface_speed * (6.0 * effective_grip)
				apply_force(roll_friction, contact_arm)
				
			# Humo blanco de neumático quemado + tierra/nieve/arena en la rueda trasera
			rear_burnout_smoke.position.y = wheel_sprite.position.y + wheel_radius * 0.65
			rear_burnout_smoke.emitting = (_burnout_intensity > 0.18) or (input_brake > 0.0 and forward_speed > 240.0)
			dust.position.y = wheel_sprite.position.y + wheel_radius * 0.65
			dust.emitting = (_burnout_intensity > 0.12) or (input_gas > 0.0 and forward_speed > -5.0) or (input_brake > 0.0 and forward_speed <= 0.0) or (abs(surface_speed) > 45.0)
		else:
			# Rueda delantera: frena suavemente al hundir la trompa
			if input_brake > 0.0 and forward_speed > 25.0:
				var front_brake: Vector2 = -ground_tangent * clamp(forward_speed * 35.0, 3000.0, brake_power * 0.45) * input_brake * _route_grip_mult
				apply_force(front_brake, contact_arm)
			dust.position.y = wheel_sprite.position.y + wheel_radius * 0.65
			dust.emitting = (input_brake > 0.0 and forward_speed > 35.0)
		
		# Adherencia lateral en pendientes para ambas ruedas modulada por _route_grip_mult
		var lateral_grip: Vector2 = -ground_tangent * surface_speed * (5.8 * effective_grip)
		apply_force(lateral_grip, arm_world)
		
		# MOVIMIENTO ELÁSTICO VISUAL DE LA RUEDA (amortiguador invisible de recorrido natural):
		# Recorre desde y = 14.0 (compresión profunda en saltos, separada del chasis en y = -14)
		# hasta y = 44.0 (extensión completa), con dinámica de resorte propia para que rebote con fluidez
		var squat_add: float = 0.0
		if is_rear and input_gas > 0.0:
			squat_add = -4.5 * input_gas # La parte trasera se comprime al acelerar / quemar llanta
		elif not is_rear and input_brake > 0.0 and forward_speed > 20.0:
			squat_add = -4.0 * input_brake # La trompa se comprime al frenar
			
		var target_wheel_y: float = clamp(hit_dist - wheel_radius + squat_add, 14.0, 44.0)
		var wy: float = wheel_sprite.position.y
		var wvel: float = _rear_wheel_vel_y if is_rear else _front_wheel_vel_y
		var w_force: float = (target_wheel_y - wy) * 320.0 - wvel * 18.0
		wvel += w_force * delta
		wy = clamp(wy + wvel * delta, 13.0, 46.0)
		# Rastreo directo del suelo si el terreno sube rápido para que la llanta nunca atraviese el piso
		if wy > target_wheel_y + 3.0:
			wy = lerp(wy, target_wheel_y, 0.78)
		wheel_sprite.position.y = wy
		if is_rear:
			_rear_wheel_vel_y = wvel
		else:
			_front_wheel_vel_y = wvel
			
		# Deformación elástica del neumático (Squash & Stretch al rebotar en saltos)
		var sq: float = _rear_squash if is_rear else _front_squash
		sq = lerp(sq, clamp((compression - 0.45) * 0.22, 0.0, 0.18), 12.0 * delta)
		wheel_sprite.scale = Vector2(base_scale.x * (1.0 + sq * 0.65), base_scale.y * (1.0 - sq * 0.55))
		if is_rear:
			_rear_squash = sq
		else:
			_front_squash = sq
		
		# Rotación visual de la rueda (la trasera usa _rear_spin_speed para girar rápido al quemar llanta)
		var visual_roll_speed: float = _rear_spin_speed if is_rear else surface_speed
		wheel_sprite.rotation += (visual_roll_speed / 24.0) * delta * 2.2
		
		return true
	else:
		# EN EL AIRE: El amortiguador invisible se estira hacia abajo con rebote elástico
		if is_rear:
			_rear_was_grounded = false
			_burnout_intensity = lerp(_burnout_intensity, 0.0, 8.0 * delta)
			rear_burnout_smoke.emitting = false
		else:
			_front_was_grounded = false
			
		var target_air_y: float = 42.0
		var wy: float = wheel_sprite.position.y
		var wvel: float = _rear_wheel_vel_y if is_rear else _front_wheel_vel_y
		var w_force: float = (target_air_y - wy) * 140.0 - wvel * 9.5
		wvel += w_force * delta
		wy = clamp(wy + wvel * delta, 13.0, 46.0)
		wheel_sprite.position.y = wy
		if is_rear:
			_rear_wheel_vel_y = wvel
			_rear_squash = lerp(_rear_squash, -0.06, 8.0 * delta)
			wheel_sprite.scale = Vector2(base_scale.x * (1.0 + _rear_squash * 0.5), base_scale.y * (1.0 - _rear_squash * 0.5))
		else:
			_front_wheel_vel_y = wvel
			_front_squash = lerp(_front_squash, -0.06, 8.0 * delta)
			wheel_sprite.scale = Vector2(base_scale.x * (1.0 + _front_squash * 0.5), base_scale.y * (1.0 - _front_squash * 0.5))
			
		if input_gas > 0.0 and is_rear:
			_rear_spin_speed = lerp(_rear_spin_speed, 850.0, 10.0 * delta)
			wheel_sprite.rotation += 26.0 * delta
		elif input_brake > 0.0 and is_rear:
			_rear_spin_speed = lerp(_rear_spin_speed, -550.0, 10.0 * delta)
			wheel_sprite.rotation -= 22.0 * delta
		else:
			_rear_spin_speed = lerp(_rear_spin_speed, 0.0, 4.0 * delta)
			
		dust.emitting = false
		return false

func _read_inputs() -> void:
	var old_gas: float = input_gas
	input_gas = 1.0 if (Input.is_action_pressed("accelerate") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0
	input_brake = 1.0 if (Input.is_action_pressed("brake") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0

	# Sonido dinámico al pisar el acelerador desde quieto o baja velocidad
	if input_gas > 0.0 and old_gas <= 0.0 and linear_velocity.length() < 300.0 and GameManager.current_fuel > 0.0:
		SoundManager.play_accel(randf_range(0.96, 1.08))
	prev_gas = input_gas

func _update_fuel(delta: float) -> void:
	if not is_crashed and GameManager.is_game_active:
		var rate: float = fuel_consumption_rate * (1.15 if input_gas > 0.0 else (0.75 if input_brake > 0.0 else 0.40))
		if is_in_water() and current_level_num == 6:
			# Nivel 6 (Pantano Tóxico): vapor ácido en el motor consume 75% más combustible
			rate *= 1.75
		GameManager.current_fuel = maxf(0.0, GameManager.current_fuel - rate * delta)

func _update_rpm(delta: float) -> void:
	if is_crashed or GameManager.current_fuel <= 0.0:
		_rpm_ratio = lerp(_rpm_ratio, 0.0, 8.0 * delta)
		return
	var wheel_speed_norm: float = clamp(linear_velocity.length() / 760.0, 0.0, 1.0)
	var spin_norm: float = clamp(abs(_rear_spin_speed) / 820.0, 0.0, 1.0)
	var throttle_boost: float = input_gas * 0.22 + _burnout_intensity * 0.25
	var raw_rpm: float = max(wheel_speed_norm, spin_norm * (0.88 if input_gas > 0.0 else 0.62)) + throttle_boost
	var target_rpm: float = clamp(0.10 + raw_rpm * 0.90, 0.08, 1.0)
	_rpm_ratio = lerp(_rpm_ratio, target_rpm, 14.0 * delta)

func get_rpm_ratio() -> float:
	if is_crashed or GameManager.current_fuel <= 0.0:
		return 0.0
	var wheel_speed_norm: float = clamp(linear_velocity.length() / 760.0, 0.0, 1.0)
	var spin_norm: float = clamp(abs(_rear_spin_speed) / 820.0, 0.0, 1.0)
	var throttle_boost: float = input_gas * 0.22 + _burnout_intensity * 0.25
	var instant_rpm: float = clamp(0.10 + (max(wheel_speed_norm, spin_norm * (0.88 if input_gas > 0.0 else 0.62)) + throttle_boost) * 0.90, 0.0, 1.0)
	return clamp(lerp(_rpm_ratio, instant_rpm, 0.35), 0.0, 1.0)

func get_pitch_degrees() -> float:
	return rad_to_deg(rotation)

func _update_audio() -> void:
	var speed: float = max(linear_velocity.length(), abs(_rear_spin_speed) * 0.75 if input_gas > 0.0 else 0.0)
	var forward_speed: float = linear_velocity.dot(Vector2.RIGHT.rotated(rotation))
	SoundManager.update_engine_pitch(speed / 580.0, input_gas > 0.0 or input_brake > 0.0)
	SoundManager.play_wind(min(1.0, linear_velocity.length() / 1400.0))

	# Frenado dinámico realista sin spam de canales
	var on_ground: bool = _rear_was_grounded or _front_was_grounded
	var is_braking: bool = on_ground and input_brake > 0.0 and forward_speed > 60.0
	SoundManager.set_brake_active(is_braking, forward_speed / 450.0)

	# Quemado de llanta / derrape continuo controlado
	var is_burning: bool = _rear_was_grounded and (_burnout_intensity > 0.15 or (input_gas > 0.0 and input_brake > 0.0 and linear_velocity.length() < 120.0))
	SoundManager.set_burnout_active(is_burning, _burnout_intensity)

func _check_air_and_stunts(delta: float, on_ground: bool) -> void:
	var delta_rot: float = rotation - previous_rotation
	if delta_rot > PI:
		delta_rot -= TAU
	elif delta_rot < -PI:
		delta_rot += TAU
	total_rotation += delta_rot
	previous_rotation = rotation
	
	if not on_ground:
		air_time += delta
		if total_rotation < -TAU * (flip_count + 1):
			flip_count += 1
			SoundManager.play_flip()
			stunt_performed.emit("¡BACKFLIP!", 500)
			GameManager.add_coins(50)
		elif total_rotation > TAU * (flip_count + 1):
			flip_count += 1
			SoundManager.play_flip()
			stunt_performed.emit("¡FRONTFLIP!", 500)
			GameManager.add_coins(50)
	else:
		if air_time > 1.2:
			var bonus: int = int(air_time * 180.0)
			stunt_performed.emit("¡GRAN SALTO!", bonus)
			GameManager.add_coins(int(bonus / 8.0))
		air_time = 0.0
		total_rotation = 0.0
		flip_count = 0

func _on_head_touched_ground(body: Node) -> void:
	if is_crashed:
		return
	if body is StaticBody2D or body.name.begins_with("Terrain"):
		crash(true)

func crash(is_rollover: bool = false) -> void:
	if is_crashed:
		return
	is_crashed = true
	rear_burnout_smoke.emitting = false
	rear_dust.emitting = false
	front_dust.emitting = false
	if is_rollover:
		SoundManager.play_rollover()
	else:
		SoundManager.play_sfx("crash")
	SoundManager.stop_engine()
	crashed.emit()
	GameManager.trigger_game_over("¡TE VOLTEASTE! FIN DEL CAMINO")
