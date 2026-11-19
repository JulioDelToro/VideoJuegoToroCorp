extends Node2D
class_name TerrainChunk

# Chunk de terreno con colisión física, césped superior bicapa, relleno de tierra uniforme sin líneas
# y secretos subterráneos: fósiles de dinosaurios, cráneos, gemas de cristal y piedras variadas

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var collision_poly: CollisionPolygon2D = $StaticBody2D/CollisionPolygon2D
@onready var visual_poly: Polygon2D = $VisualPoly
@onready var sub_grass_line: Line2D = $SubGrassLine
@onready var grass_line: Line2D = $GrassLine
@onready var props_container: Node2D = $Props
@onready var collectibles_container: Node2D = $Collectibles

var chunk_start_x: float = 0.0
var chunk_end_x: float = 0.0
var chunk_index: int = 0

var level_num: int = 1
var goal_world_x: float = 21200.0
var surface_color: Color = Color(0.18, 0.78, 0.42)
var surface_highlight: Color = Color(0.25, 0.98, 0.78)
var dirt_color: Color = Color(0.22, 0.15, 0.12)
var sub_dirt_color: Color = Color(0.12, 0.09, 0.14)
var accent_color: Color = Color(0.18, 0.95, 0.82)

var _sub_dirt_poly: Polygon2D = null
var _crust_bevel_line: Line2D = null
var _strata_line: Line2D = null

const COIN_SCENE = preload("res://scenes/collectibles/coin.tscn")
const FUEL_SCENE = preload("res://scenes/collectibles/fuel_canister.tscn")
const RUBY_SCENE = preload("res://scenes/collectibles/ruby.tscn")

const PROP_RAMP = preload("res://assets/sprites/sign_ramp.png")
const PROP_MARKER = preload("res://assets/sprites/sign_marker.png")

# Fósiles y secretos subterráneos
const FOSSIL_DINO = preload("res://assets/sprites/fossil_dino.png")
const FOSSIL_SKULL = preload("res://assets/sprites/fossil_skull.png")
const BURIED_GEM = preload("res://assets/sprites/buried_gem.png")
const ROCK_VAR_0 = preload("res://assets/sprites/rock_var_0.png")
const ROCK_VAR_1 = preload("res://assets/sprites/rock_var_1.png")
const ROCK_VAR_2 = preload("res://assets/sprites/rock_var_2.png")

static func get_chunk_obstacle_type(c_idx: int, lvl: int, goal_x: float) -> int:
	if c_idx <= 0:
		return 0
	var c_start: float = float(c_idx) * 1800.0
	# Mantener el área del arco de meta completamente despejada de obstáculos
	if absf((c_start + 900.0) - goal_x) < 650.0 or (goal_x >= c_start - 250.0 and goal_x <= c_start + 2050.0):
		return 0

	# Para chunks avanzados (c_idx >= 6): mantener estrictamente el tipo insignia del nivel
	if c_idx >= 6:
		if c_idx % 2 == 1:
			match lvl:
				3, 6:
					return 1
				4:
					return 0 # Hielo
				5:
					return 4 # Seesaw
				8:
					return 3 # Tronco
				9:
					return 5 # Puente alien
				_:
					return 2
		return 0

	# Aislamiento estricto de obstáculos por bioma (chunks 1 a 5) — 1 mecánica insignia por nivel:
	match lvl:
		1: # Pradera Cyber-Solar: Solo rampas de salto acrobático con recepción en bajada (c_idx == 2 y 5)
			if c_idx == 2 or c_idx == 5:
				return 2
		2: # Desierto Magma-Cristal: Rampas sobre fosas de magma (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 2
		3: # Jungla Bioluminiscente: Lagunas bioluminiscentes profundas (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 1
		4: # Glaciar Volcánico: Hielo Puro / Cero Tracción (Zonas IceSlickArea en chunks 1 y 3)
			return 0
		5: # Cañón Steampunk: Plataforma Balancín / Subibaja (c_idx == 2 o 3)
			if c_idx == 2 or c_idx == 3:
				return 4
		6: # Pantano Tóxico: Pozas de lodo y agua ácida corrosiva (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 1
		7: # Autopista Synthwave: Mega rampas de salto de alta velocidad (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 2
		8: # Cumbre Caramelo: Tronco dulce rodante en rampa (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 3
		9: # Ruinas Alien-Doradas: Puente de Paneles Quebradizos Antigravedad (c_idx == 2 o 3)
			if c_idx == 2 or c_idx == 3:
				return 5
			elif c_idx == 1 or c_idx == 5:
				return 2
		10: # Nebulosa Lunar-Cósmica: Mega rampas sobre cráteres cósmicos (c_idx == 1, 3, 5)
			if c_idx == 1 or c_idx == 3 or c_idx == 5:
				return 2
		_:
			if c_idx % 2 == 1:
				return 2

	return 0

func setup(
	start_x: float,
	end_x: float,
	step: float,
	height_func: Callable,
	spawn_collectibles: bool = true,
	p_surface_color: Color = Color(0.18, 0.78, 0.42),
	p_surface_highlight: Color = Color(0.25, 0.98, 0.78),
	p_dirt_color: Color = Color(0.22, 0.15, 0.12),
	p_sub_dirt_color: Color = Color(0.12, 0.09, 0.14),
	p_level_num: int = 1,
	p_accent_color: Color = Color(0.18, 0.95, 0.82),
	p_goal_world_x: float = 21200.0
) -> void:
	chunk_start_x = start_x
	chunk_end_x = end_x
	surface_color = p_surface_color
	surface_highlight = p_surface_highlight
	dirt_color = p_dirt_color
	sub_dirt_color = p_sub_dirt_color
	level_num = p_level_num
	accent_color = p_accent_color
	goal_world_x = p_goal_world_x

	_clear_dynamic_children()
	visible = true
	collision_poly.disabled = false
	collision_poly.set_deferred("disabled", false)

	var surface_points: PackedVector2Array = PackedVector2Array()
	var x: float = start_x
	while x <= end_x + 0.1:
		var y: float = float(height_func.call(x))
		surface_points.append(Vector2(x, y))
		x += step

	if surface_points[surface_points.size() - 1].x < end_x:
		surface_points.append(Vector2(end_x, float(height_func.call(end_x))))

	# Borde de superficie bicapa estilizado según el bioma activo
	grass_line.points = surface_points
	grass_line.default_color = surface_highlight

	var shadow_points: PackedVector2Array = PackedVector2Array()
	var bevel_points: PackedVector2Array = PackedVector2Array()
	var sub_dirt_points: PackedVector2Array = PackedVector2Array()
	var strata_points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in surface_points:
		shadow_points.append(p + Vector2(0.0, 5.0))
		bevel_points.append(p + Vector2(0.0, 14.0))
		sub_dirt_points.append(p + Vector2(0.0, 115.0))
		strata_points.append(p + Vector2(0.0, 115.0))
	sub_grass_line.points = shadow_points
	sub_grass_line.default_color = surface_color

	# Polígono cerrado profundo hacia el fondo (4800px para que NUNCA se corte)
	var poly_points: PackedVector2Array = surface_points.duplicate()
	var bottom_depth: float = 4800.0
	poly_points.append(Vector2(end_x, bottom_depth))
	poly_points.append(Vector2(start_x, bottom_depth))

	collision_poly.polygon = poly_points
	visual_poly.polygon = poly_points
	visual_poly.texture = null
	visual_poly.color = dirt_color

	# Sombra biselada bajo el césped para efecto de relieve 3D
	if _crust_bevel_line == null:
		_crust_bevel_line = Line2D.new()
		_crust_bevel_line.name = "CrustBevelLine"
		_crust_bevel_line.width = 10.0
		_crust_bevel_line.z_index = 1
		add_child(_crust_bevel_line)
	_crust_bevel_line.points = bevel_points
	_crust_bevel_line.default_color = Color(dirt_color.r * 0.65, dirt_color.g * 0.65, dirt_color.b * 0.65, 0.72)

	# Capa subterránea profunda con el color secundario del bioma (sub_dirt_color)
	if _sub_dirt_poly == null:
		_sub_dirt_poly = Polygon2D.new()
		_sub_dirt_poly.name = "SubDirtPoly"
		_sub_dirt_poly.z_index = 0
		add_child(_sub_dirt_poly)
		move_child(_sub_dirt_poly, visual_poly.get_index() + 1)
	sub_dirt_points.append(Vector2(end_x, bottom_depth))
	sub_dirt_points.append(Vector2(start_x, bottom_depth))
	_sub_dirt_poly.polygon = sub_dirt_points
	_sub_dirt_poly.color = sub_dirt_color

	# Veta mineral entre estratos geológicos
	if _strata_line == null:
		_strata_line = Line2D.new()
		_strata_line.name = "StrataLine"
		_strata_line.width = 4.0
		_strata_line.z_index = 1
		add_child(_strata_line)
	_strata_line.points = strata_points
	_strata_line.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.22)

	# Arco de Meta celebratorio si la distancia objetivo cae dentro de este chunk
	if goal_world_x >= chunk_start_x and goal_world_x < chunk_end_x:
		var goal_y: float = float(height_func.call(goal_world_x))
		_add_finish_line_arch(goal_world_x, goal_y)

	if spawn_collectibles:
		_spawn_chunk_obstacle(surface_points, height_func)
		_spawn_items_along_surface(surface_points, height_func)
		_spawn_surface_and_underground_props(surface_points, height_func)
		_spawn_fused_theme_props(surface_points, height_func)
		_spawn_ambient_life(surface_points, height_func)

func build_chunk(
	start_x: float,
	end_x: float,
	step: float,
	height_func: Callable,
	spawn_collectibles: bool = true
) -> void:
	setup(
		start_x,
		end_x,
		step,
		height_func,
		spawn_collectibles,
		surface_color,
		surface_highlight,
		dirt_color,
		sub_dirt_color,
		level_num,
		accent_color,
		goal_world_x
	)

func deactivate_for_pool() -> void:
	_clear_dynamic_children()
	collision_poly.set_deferred("disabled", true)
	visible = false

func _clear_dynamic_children() -> void:
	if collectibles_container != null:
		for child: Node in collectibles_container.get_children():
			child.queue_free()
	if props_container != null:
		for child: Node in props_container.get_children():
			child.queue_free()

func _spawn_chunk_obstacle(_points: PackedVector2Array, height_func: Callable) -> void:
	# ── MECÁNICAS ÚNICAS DE AMBIENTE / SUPERFICIE POR NIVEL ───────────────────
	_spawn_level_unique_features(height_func)

	var obs_type: int = get_chunk_obstacle_type(chunk_index, level_num, goal_world_x)
	if obs_type == 0:
		return

	if obs_type == 1:
		# ── OBSTÁCULO 1: LAGUNA DE AGUA PROFUNDA / LODO ÁCIDO ─────────────────
		var x1: float = chunk_start_x + 525.0
		var x2: float = chunk_start_x + 1315.0
		var water_y: float = 668.0

		var water_pts: PackedVector2Array = PackedVector2Array()
		var wave_pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 24
		for s_i: int in range(steps + 1):
			var t: float = float(s_i) / float(steps)
			var wx: float = lerpf(x1, x2, t)
			var wy: float = water_y + sin(t * PI * 6.0) * 3.5
			water_pts.append(Vector2(wx, wy))
			wave_pts.append(Vector2(wx, wy))

		# Cerrar el polígono siguiendo la cuenca del fondo para que no sobresalga de la tierra
		for s_i: int in range(steps, -1, -1):
			var t_b: float = float(s_i) / float(steps)
			var bx: float = lerpf(x1, x2, t_b)
			var by: float = maxf(water_y + 8.0, float(height_func.call(bx)) + 8.0)
			water_pts.append(Vector2(bx, by))

		var is_acid: bool = (level_num == 6)
		var basin_color: Color = Color(0.20, 0.90, 0.12, 0.65) if is_acid else (Color(0.08, 0.72, 0.88, 0.65) if level_num == 3 else Color(0.08, 0.55, 0.92, 0.58))
		var surface_line_col: Color = Color(0.75, 1.0, 0.25, 0.95) if is_acid else (Color(0.68, 0.38, 1.0, 0.92) if level_num == 3 else Color(0.45, 0.92, 1.0, 0.88))

		var water_poly: Polygon2D = Polygon2D.new()
		water_poly.name = "WaterBasinPoly"
		water_poly.polygon = water_pts
		water_poly.color = basin_color
		water_poly.z_index = 3
		props_container.add_child(water_poly)

		var wave_line: Line2D = Line2D.new()
		wave_line.name = "WaterSurfaceLine"
		wave_line.points = wave_pts
		wave_line.width = 5.0
		wave_line.default_color = surface_line_col
		wave_line.z_index = 4
		props_container.add_child(wave_line)

		# Partículas temáticas en el líquido (burbujas ácidas en Nivel 6 o esporas en Nivel 3)
		var bubble_particles: CPUParticles2D = CPUParticles2D.new()
		bubble_particles.name = "LiquidBubbles"
		bubble_particles.position = Vector2(chunk_start_x + 920.0, water_y + 10.0)
		bubble_particles.amount = 18
		bubble_particles.lifetime = 2.0
		bubble_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		bubble_particles.emission_rect_extents = Vector2(360.0, 15.0)
		bubble_particles.direction = Vector2(0.0, -1.0)
		bubble_particles.spread = 20.0
		bubble_particles.gravity = Vector2(0.0, -25.0)
		bubble_particles.initial_velocity_min = 15.0
		bubble_particles.initial_velocity_max = 35.0
		bubble_particles.scale_amount_min = 2.0
		bubble_particles.scale_amount_max = 4.5
		bubble_particles.color = Color(0.82, 1.0, 0.25, 0.75) if is_acid else Color(0.45, 0.92, 1.0, 0.65)
		bubble_particles.z_index = 4
		props_container.add_child(bubble_particles)

		# Zona de física acuática que frena el vehículo si no pasa con velocidad
		var water_area: Area2D = Area2D.new()
		water_area.name = "WaterHazardZone"
		water_area.add_to_group("water_hazard")
		water_area.collision_layer = 0
		water_area.collision_mask = 2
		water_area.position = Vector2(chunk_start_x + 920.0, 730.0)

		var w_col: CollisionShape2D = CollisionShape2D.new()
		var w_rect: RectangleShape2D = RectangleShape2D.new()
		w_rect.size = Vector2(760.0, 140.0)
		w_col.shape = w_rect
		water_area.add_child(w_col)

		water_area.body_entered.connect(func(body: Node) -> void:
			if body is Vehicle and body.has_method("set_in_water"):
				body.call("set_in_water", true)
		)
		water_area.body_exited.connect(func(body: Node) -> void:
			if body is Vehicle and body.has_method("set_in_water"):
				body.call("set_in_water", false)
		)
		props_container.add_child(water_area)

		var sign_x: float = chunk_start_x + 420.0
		var sign_y: float = float(height_func.call(sign_x))
		var sign_text: String = "☣️ ¡LODO ÁCIDO CORROSIVO!\n¡EVAPORA TU COMBUSTIBLE!" if is_acid else "🌊 ¡LAGUNA BIOLUMINISCENTE!\n¡CRUZA A MÁXIMA VELOCIDAD!"
		var sign_col: Color = Color(0.75, 1.0, 0.25, 1.0) if is_acid else Color(0.20, 0.85, 1.0, 1.0)
		var sign_node: Node2D = _create_obstacle_warning_sign(sign_x, sign_y, sign_text, sign_col)
		props_container.add_child(sign_node)

	elif obs_type in [2, 3, 4, 5]:
		# ── OBSTÁCULOS 2, 3, 4, 5: RAMPA / CAÑÓN / BALANCÍN / PUENTE ALIEN ───
		var gap_end: float = 950.0 + float(level_num - 1) * 8.0

		# Banda neón de aceleración sobre la rampa de despegue (520.0 .. 760.0)
		var ramp_strip: Line2D = Line2D.new()
		ramp_strip.name = "RampNeonStrip"
		var strip_pts: PackedVector2Array = PackedVector2Array()
		for r_i: int in range(13):
			var rx: float = chunk_start_x + lerpf(520.0, 760.0, float(r_i) / 12.0)
			var ry: float = float(height_func.call(rx)) - 3.0
			strip_pts.append(Vector2(rx, ry))
		ramp_strip.points = strip_pts
		ramp_strip.width = 7.0
		ramp_strip.default_color = Color(0.20, 0.95, 0.70, 0.95) if (obs_type == 2 and level_num == 1) else (Color(1.0, 0.88, 0.18, 0.95) if obs_type == 2 else Color(1.0, 0.45, 0.18, 0.95))
		ramp_strip.z_index = 4
		props_container.add_child(ramp_strip)

		# Banda neón de recepción en la bajada tras el abismo (gap_end + 10.0 .. gap_end + 320.0)
		var landing_strip: Line2D = Line2D.new()
		landing_strip.name = "LandingReceptionStrip"
		var land_pts: PackedVector2Array = PackedVector2Array()
		for l_i: int in range(13):
			var lx: float = chunk_start_x + lerpf(gap_end + 10.0, gap_end + 320.0, float(l_i) / 12.0)
			var ly: float = float(height_func.call(lx)) - 3.0
			land_pts.append(Vector2(lx, ly))
		landing_strip.points = land_pts
		landing_strip.width = 7.0
		landing_strip.default_color = Color(1.0, 0.88, 0.25, 0.95) if (obs_type == 2 and level_num == 1) else Color(0.20, 0.95, 0.70, 0.95)
		landing_strip.z_index = 4
		props_container.add_child(landing_strip)

		# Picos mortales y zona de abismo (solo para niveles >= 2 donde el precipicio es mortal)
		var is_safe_tutorial_jump: bool = (obs_type == 2 and level_num == 1)
		if not is_safe_tutorial_jump:
			_spawn_abyss_kill_zone(gap_end)

		var warn_text: String = ""
		var warn_col: Color = Color(1.0, 0.32, 0.22, 1.0)
		if is_safe_tutorial_jump:
			warn_text = "🚀 ¡RAMPA ACROBÁTICA!\n¡ACELERA Y VUELA SEGURO!"
			warn_col = Color(0.25, 0.95, 0.70, 1.0)
		elif obs_type == 4:
			warn_text = "⚙️ ¡PUENTE BALANCÍN MECÁNICO!\n¡USA EL PESO PARA INCLINARLO!"
			warn_col = Color(0.95, 0.75, 0.28, 1.0)
		elif obs_type == 5:
			warn_text = "🛸 ¡PUENTE ALIEN QUEBRADIZO!\n¡COLAPSA EN 1.2s - NO PARES!"
			warn_col = Color(0.20, 0.95, 0.85, 1.0)
		elif obs_type == 3:
			warn_text = "🪵 ¡TRONCO DULCE EN LA RAMPA!\n¡UN TOQUE Y RUEDA AL ABISMO!"
			warn_col = Color(0.95, 0.72, 0.35, 1.0)
		elif level_num == 2:
			warn_text = "🏜️ ¡FOSA DE MAGMA!\n¡VIENTO EN CONTRA EN EL AIRE!"
			warn_col = Color(1.0, 0.42, 0.15, 1.0)
		elif level_num == 7:
			warn_text = "🌆 ¡MEGA RAMPA SYNTHWAVE!\n¡ALTA VELOCIDAD Y NEÓN!"
			warn_col = Color(1.0, 0.20, 0.80, 1.0)
		elif level_num == 10:
			warn_text = "🌌 ¡CRÁTER CÓSMICO (0.60G)!\n¡DOMINA TU ROTACIÓN EN EL AIRE!"
			warn_col = Color(0.70, 0.50, 1.0, 1.0)
		else:
			warn_text = "⚠️ ¡PRECIPICIO!\n¡ACELERA Y RAMPEA!"
			warn_col = Color(1.0, 0.32, 0.22, 1.0)

		var sign_x2: float = chunk_start_x + 400.0
		var sign_y2: float = float(height_func.call(sign_x2))
		var sign_node2: Node2D = _create_obstacle_warning_sign(sign_x2, sign_y2, warn_text, warn_col)
		props_container.add_child(sign_node2)

		if obs_type == 3:
			# ── TRONCO FÍSICO RODANTE EN EL LABIO DE LA RAMPA ─────────────────
			# Muy ligero (4.8kg), baja fricción y amortiguación angular mínima (0.02)
			# Un toque suave del parachoques o rueda del vehículo lo hace girar y rodar de inmediato al abismo
			var log_node: RigidBody2D = RigidBody2D.new()
			log_node.name = "RampPhysicsLog"
			var log_radius: float = 38.0
			var log_spawn_y: float = float(height_func.call(chunk_start_x + 725.0)) - log_radius
			log_node.position = Vector2(chunk_start_x + 725.0, log_spawn_y)
			log_node.collision_layer = 1
			log_node.collision_mask = 3
			log_node.mass = 4.8
			log_node.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
			log_node.linear_damp = 0.05
			log_node.angular_damp = 0.02

			var phys_mat: PhysicsMaterial = PhysicsMaterial.new()
			phys_mat.friction = 0.18
			phys_mat.bounce = 0.12
			log_node.physics_material_override = phys_mat

			var log_col: CollisionShape2D = CollisionShape2D.new()
			log_col.name = "CollisionShape2D"
			var log_circle: CircleShape2D = CircleShape2D.new()
			log_circle.radius = log_radius
			log_col.shape = log_circle
			log_node.add_child(log_col)

			# Visuales temáticos estilizados según el nivel
			var bark_color: Color = Color(0.40, 0.24, 0.14)
			var wood_face_color: Color = Color(0.82, 0.65, 0.44)
			var ring_color: Color = Color(0.65, 0.48, 0.30)
			var crack_color: Color = Color(0.48, 0.32, 0.18)
			var knot_color: Color = Color(0.28, 0.16, 0.08)

			if level_num == 4:
				# Glaciar Volcánico: Tronco invernal de corteza helada
				bark_color = Color(0.28, 0.32, 0.38)
				wood_face_color = Color(0.72, 0.84, 0.92)
				ring_color = Color(0.52, 0.68, 0.80)
				crack_color = Color(0.35, 0.50, 0.65)
				knot_color = Color(0.22, 0.28, 0.36)
			elif level_num == 8:
				# Cumbre Caramelo: Tronco dulce de caramelo y azúcar
				bark_color = Color(0.96, 0.42, 0.62)
				wood_face_color = Color(1.0, 0.95, 0.96)
				ring_color = Color(0.95, 0.35, 0.55)
				crack_color = Color(0.98, 0.25, 0.48)
				knot_color = Color(0.98, 0.18, 0.32)
			elif level_num == 9:
				# Ruinas Alien-Doradas: Cilindro extraterrestre dorado con tecnología alienígena
				bark_color = Color(0.85, 0.70, 0.18)
				wood_face_color = Color(0.20, 0.18, 0.12)
				ring_color = Color(0.18, 0.95, 0.85)
				crack_color = Color(0.25, 1.0, 0.88)
				knot_color = Color(1.0, 0.85, 0.25)

			# 1. Anillo exterior de corteza de árbol (32 puntos, radio 38.0)
			var bark_poly: Polygon2D = Polygon2D.new()
			bark_poly.name = "BarkPoly"
			var bark_pts: PackedVector2Array = PackedVector2Array()
			for b_i: int in range(32):
				var b_ang: float = float(b_i) * TAU / 32.0
				bark_pts.append(Vector2(cos(b_ang) * log_radius, sin(b_ang) * log_radius))
			bark_poly.polygon = bark_pts
			bark_poly.color = bark_color
			bark_poly.z_index = 4
			log_node.add_child(bark_poly)

			# 2. Cara de corte interior de la madera (32 puntos, radio 34.0)
			var wood_poly: Polygon2D = Polygon2D.new()
			wood_poly.name = "WoodCutFacePoly"
			var wood_pts: PackedVector2Array = PackedVector2Array()
			for w_i: int in range(32):
				var w_ang: float = float(w_i) * TAU / 32.0
				wood_pts.append(Vector2(cos(w_ang) * 34.0, sin(w_ang) * 34.0))
			wood_poly.polygon = wood_pts
			wood_poly.color = wood_face_color
			wood_poly.z_index = 4
			log_node.add_child(wood_poly)

			# 3. Anillos anuales de crecimiento concéntricos (radios 24, 16, 8)
			for r_val: float in [24.0, 16.0, 8.0]:
				var ring_line: Line2D = Line2D.new()
				ring_line.name = "GrowthRing_%d" % int(r_val)
				var ring_pts: PackedVector2Array = PackedVector2Array()
				for a_i: int in range(25):
					var a_ang: float = float(a_i) * TAU / 24.0
					var r_offset: float = sin(a_ang * 3.0) * 0.6
					ring_pts.append(Vector2(cos(a_ang) * (r_val + r_offset), sin(a_ang) * (r_val + r_offset)))
				ring_line.points = ring_pts
				ring_line.width = 1.8
				ring_line.default_color = ring_color
				ring_line.z_index = 4
				log_node.add_child(ring_line)

			# 4. Grietas y vetas radiales desde el centro a la corteza para evidenciar la rotación
			var crack_angles: Array[float] = [0.35, 1.55, 2.75, 4.05, 5.25]
			for ca_i: int in range(crack_angles.size()):
				var ca: float = crack_angles[ca_i]
				var crack_line: Line2D = Line2D.new()
				crack_line.name = "RadialCrack_%d" % ca_i
				var r_in: float = 5.0
				var r_out: float = 33.0
				var p1: Vector2 = Vector2(cos(ca) * r_in, sin(ca) * r_in)
				var mid_ang: float = ca + 0.08
				var p_mid: Vector2 = Vector2(cos(mid_ang) * (r_out * 0.55), sin(mid_ang) * (r_out * 0.55))
				var p2: Vector2 = Vector2(cos(ca) * r_out, sin(ca) * r_out)
				crack_line.points = PackedVector2Array([p1, p_mid, p2])
				crack_line.width = 2.0
				crack_line.default_color = crack_color
				crack_line.z_index = 4
				log_node.add_child(crack_line)

			# 5. Nudo de corteza / brote exterior saliente que rota alrededor del tronco
			var knot_poly: Polygon2D = Polygon2D.new()
			knot_poly.name = "BarkKnot"
			knot_poly.polygon = PackedVector2Array([
				Vector2(33.0, -9.0),
				Vector2(42.0, -5.0),
				Vector2(43.0, 5.0),
				Vector2(34.0, 9.0),
				Vector2(30.0, 0.0)
			])
			knot_poly.color = knot_color
			knot_poly.z_index = 4
			log_node.add_child(knot_poly)

			# 6. Variantes temáticas especiales por bioma
			if level_num == 4:
				# Glaciar: Nieve escarchada azulada sobre la corteza
				var snow_line: Line2D = Line2D.new()
				snow_line.name = "GlacierSnowBark"
				var snow_pts: PackedVector2Array = PackedVector2Array()
				for sn_i: int in range(16):
					var sn_ang: float = -PI * 0.7 + float(sn_i) * (PI * 1.4) / 15.0
					snow_pts.append(Vector2(cos(sn_ang) * log_radius, sin(sn_ang) * log_radius))
				snow_line.points = snow_pts
				snow_line.width = 3.8
				snow_line.default_color = Color(0.85, 0.95, 1.0, 0.95)
				snow_line.z_index = 4
				log_node.add_child(snow_line)
			elif level_num == 8:
				# Cumbre Caramelo: Franjas blancas de azúcar espirales
				for st_i: int in range(3):
					var st_ang: float = float(st_i) * TAU / 3.0
					var candy_stripe: Line2D = Line2D.new()
					candy_stripe.name = "CandyStripe_%d" % st_i
					candy_stripe.points = PackedVector2Array([
						Vector2(cos(st_ang) * 7.0, sin(st_ang) * 7.0),
						Vector2(cos(st_ang + 0.35) * 22.0, sin(st_ang + 0.35) * 22.0),
						Vector2(cos(st_ang + 0.65) * 34.0, sin(st_ang + 0.65) * 34.0)
					])
					candy_stripe.width = 3.2
					candy_stripe.default_color = Color(1.0, 1.0, 1.0, 0.95)
					candy_stripe.z_index = 4
					log_node.add_child(candy_stripe)
			elif level_num == 9:
				# Ruinas Alien-Doradas: Núcleo cibernético y glifos circulares dorados
				var alien_core: Polygon2D = Polygon2D.new()
				alien_core.name = "AlienCore"
				var core_pts: PackedVector2Array = PackedVector2Array()
				for ac_i: int in range(8):
					var ac_ang: float = float(ac_i) * TAU / 8.0
					core_pts.append(Vector2(cos(ac_ang) * 11.0, sin(ac_ang) * 11.0))
				alien_core.polygon = core_pts
				alien_core.color = Color(0.18, 0.95, 0.85, 0.95)
				alien_core.z_index = 4
				log_node.add_child(alien_core)

				var rune_rim: Line2D = Line2D.new()
				rune_rim.name = "AlienRuneRim"
				var rune_pts: PackedVector2Array = PackedVector2Array()
				for rn_i: int in range(9):
					var rn_ang: float = float(rn_i) * TAU / 8.0
					rune_pts.append(Vector2(cos(rn_ang) * log_radius, sin(rn_ang) * log_radius))
				rune_rim.points = rune_pts
				rune_rim.width = 2.5
				rune_rim.default_color = Color(1.0, 0.88, 0.35, 0.95)
				rune_rim.z_index = 4
				log_node.add_child(rune_rim)

			props_container.add_child(log_node)

		elif obs_type == 4:
			# ── OBSTÁCULO 4: PLATAFORMA BALANCÍN / SUBIBAJA STEAMPUNK (NIVEL 5) ───
			var gap_end4: float = 950.0 + float(level_num - 1) * 8.0
			var center_x4: float = (760.0 + gap_end4) * 0.5
			var pivot_y4: float = 540.0
			var plank_len: float = (gap_end4 - 760.0) + 95.0

			# 1. Base triangular de fulcro steampunk
			var fulcrum: Polygon2D = Polygon2D.new()
			fulcrum.name = "SeesawFulcrum"
			fulcrum.polygon = PackedVector2Array([
				Vector2(chunk_start_x + center_x4 - 28.0, 850.0),
				Vector2(chunk_start_x + center_x4 + 28.0, 850.0),
				Vector2(chunk_start_x + center_x4 + 10.0, pivot_y4),
				Vector2(chunk_start_x + center_x4 - 10.0, pivot_y4)
			])
			fulcrum.color = Color(0.38, 0.24, 0.16, 1.0)
			fulcrum.z_index = 3
			props_container.add_child(fulcrum)

			# Aro del eje de pivote central
			var fulcrum_ring: Line2D = Line2D.new()
			fulcrum_ring.name = "PivotRing"
			var r_pts: PackedVector2Array = PackedVector2Array()
			for a_i: int in range(17):
				var ang: float = float(a_i) * TAU / 16.0
				r_pts.append(Vector2(chunk_start_x + center_x4 + cos(ang) * 14.0, pivot_y4 + sin(ang) * 14.0))
			fulcrum_ring.points = r_pts
			fulcrum_ring.width = 4.0
			fulcrum_ring.default_color = Color(0.92, 0.72, 0.28, 1.0)
			fulcrum_ring.z_index = 4
			props_container.add_child(fulcrum_ring)

			# 2. Viga oscilante animable con colisión física
			var seesaw: SeesawPlatform = SeesawPlatform.new()
			seesaw.name = "SteampunkSeesaw"
			seesaw.position = Vector2(chunk_start_x + center_x4, pivot_y4)
			seesaw.pivot_world_x = chunk_start_x + center_x4
			seesaw.rotation = -0.16
			seesaw.collision_layer = 1
			seesaw.collision_mask = 0

			var s_col: CollisionShape2D = CollisionShape2D.new()
			var s_box: RectangleShape2D = RectangleShape2D.new()
			s_box.size = Vector2(plank_len, 22.0)
			s_col.shape = s_box
			seesaw.add_child(s_col)

			var plank_poly: Polygon2D = Polygon2D.new()
			plank_poly.polygon = PackedVector2Array([
				Vector2(-plank_len * 0.5, -11.0),
				Vector2(plank_len * 0.5, -11.0),
				Vector2(plank_len * 0.5, 11.0),
				Vector2(-plank_len * 0.5, 11.0)
			])
			plank_poly.color = Color(0.48, 0.32, 0.20, 1.0)
			plank_poly.z_index = 4
			seesaw.add_child(plank_poly)

			var plank_rim: Line2D = Line2D.new()
			plank_rim.points = PackedVector2Array([
				Vector2(-plank_len * 0.5, -11.0),
				Vector2(plank_len * 0.5, -11.0),
				Vector2(plank_len * 0.5, 11.0),
				Vector2(-plank_len * 0.5, 11.0),
				Vector2(-plank_len * 0.5, -11.0)
			])
			plank_rim.width = 3.0
			plank_rim.default_color = Color(0.96, 0.78, 0.32, 1.0)
			plank_rim.z_index = 4
			seesaw.add_child(plank_rim)

			# Sensor de presencia del vehículo sobre la viga
			var t_area: Area2D = Area2D.new()
			t_area.name = "PlankTriggerArea"
			t_area.collision_layer = 0
			t_area.collision_mask = 2
			var t_col: CollisionShape2D = CollisionShape2D.new()
			var t_box: RectangleShape2D = RectangleShape2D.new()
			t_box.size = Vector2(plank_len, 55.0)
			t_col.shape = t_box
			t_col.position = Vector2(0.0, -28.0)
			t_area.add_child(t_col)

			t_area.body_entered.connect(func(body: Node) -> void:
				if body is Vehicle:
					seesaw.vehicle_ref = body as Vehicle
			)
			t_area.body_exited.connect(func(body: Node) -> void:
				if body == seesaw.vehicle_ref:
					seesaw.vehicle_ref = null
			)
			seesaw.add_child(t_area)
			props_container.add_child(seesaw)

		elif obs_type == 5:
			# ── OBSTÁCULO 5: PUENTE DE PANELES QUEBRADIZOS ANTIGRAVEDAD (NIVEL 9) ──
			var gap_end5: float = 950.0 + float(level_num - 1) * 8.0
			var gap_span: float = gap_end5 - 760.0
			var p_w: float = gap_span / 3.0 - 6.0

			for p_i: int in range(3):
				var p_x: float = chunk_start_x + 760.0 + (float(p_i) + 0.5) * (gap_span / 3.0)
				var p_y: float = lerpf(528.0, 552.0, (float(p_i) + 0.5) / 3.0)

				var panel: BrittleAlienPanel = BrittleAlienPanel.new()
				panel.name = "AlienEnergyPanel_%d" % p_i
				panel.position = Vector2(p_x, p_y)
				panel.collision_layer = 1
				panel.collision_mask = 0

				var p_col: CollisionShape2D = CollisionShape2D.new()
				var p_box: RectangleShape2D = RectangleShape2D.new()
				p_box.size = Vector2(p_w, 16.0)
				p_col.shape = p_box
				panel.add_child(p_col)
				panel.col_shape = p_col

				var poly: Polygon2D = Polygon2D.new()
				poly.polygon = PackedVector2Array([
					Vector2(-p_w * 0.5, -8.0),
					Vector2(p_w * 0.5, -8.0),
					Vector2(p_w * 0.5, 8.0),
					Vector2(-p_w * 0.5, 8.0)
				])
				poly.color = Color(0.18, 0.95, 0.85, 0.88)
				poly.z_index = 4
				panel.add_child(poly)
				panel.visual_poly = poly

				var core_line: Line2D = Line2D.new()
				core_line.points = PackedVector2Array([
					Vector2(-p_w * 0.5 + 4.0, 0.0),
					Vector2(p_w * 0.5 - 4.0, 0.0)
				])
				core_line.width = 3.5
				core_line.default_color = Color(1.0, 0.95, 0.45, 0.95)
				core_line.z_index = 4
				panel.add_child(core_line)
				panel.core_line = core_line

				var p_area: Area2D = Area2D.new()
				p_area.name = "PanelSensorArea"
				p_area.collision_layer = 0
				p_area.collision_mask = 2
				var a_col: CollisionShape2D = CollisionShape2D.new()
				var a_box: RectangleShape2D = RectangleShape2D.new()
				a_box.size = Vector2(p_w, 35.0)
				a_col.shape = a_box
				a_col.position = Vector2(0.0, -18.0)
				p_area.add_child(a_col)

				p_area.body_entered.connect(func(body: Node) -> void:
					if body is Vehicle:
						panel.trigger()
				)
				panel.add_child(p_area)
				props_container.add_child(panel)

func _spawn_abyss_kill_zone(gap_end: float) -> void:
	var pit_x1: float = chunk_start_x + 785.0
	var pit_x2: float = chunk_start_x + gap_end - 20.0
	var abyss_glow: Polygon2D = Polygon2D.new()
	abyss_glow.polygon = PackedVector2Array([
		Vector2(pit_x1, 980.0),
		Vector2(pit_x2, 980.0),
		Vector2(pit_x2, 1285.0),
		Vector2(pit_x1, 1285.0)
	])
	abyss_glow.color = Color(0.90, 0.14, 0.08, 0.30)
	abyss_glow.z_index = 2
	props_container.add_child(abyss_glow)

	var spikes_poly: Polygon2D = Polygon2D.new()
	var spike_pts: PackedVector2Array = PackedVector2Array()
	spike_pts.append(Vector2(pit_x1, 1285.0))
	var spike_count: int = 8
	for sp_i: int in range(spike_count):
		var sx_l: float = lerpf(pit_x1, pit_x2, float(sp_i) / float(spike_count))
		var sx_m: float = lerpf(pit_x1, pit_x2, (float(sp_i) + 0.5) / float(spike_count))
		spike_pts.append(Vector2(sx_l, 1280.0))
		spike_pts.append(Vector2(sx_m, 1215.0))
	spike_pts.append(Vector2(pit_x2, 1285.0))
	spikes_poly.polygon = spike_pts
	spikes_poly.color = Color(1.0, 0.28, 0.12, 0.92)
	spikes_poly.z_index = 3
	props_container.add_child(spikes_poly)

	var abyss_area: Area2D = Area2D.new()
	abyss_area.name = "AbyssKillZone"
	abyss_area.collision_layer = 0
	abyss_area.collision_mask = 2
	abyss_area.position = Vector2(chunk_start_x + (760.0 + gap_end) * 0.5, 1020.0)

	var ab_col: CollisionShape2D = CollisionShape2D.new()
	var ab_rect: RectangleShape2D = RectangleShape2D.new()
	ab_rect.size = Vector2(gap_end - 760.0, 480.0)
	ab_col.shape = ab_rect
	abyss_area.add_child(ab_col)

	abyss_area.body_entered.connect(func(body: Node) -> void:
		if body is Vehicle:
			var veh: Vehicle = body as Vehicle
			if not veh.is_crashed:
				veh.is_crashed = true
				SoundManager.play_sfx("crash")
				SoundManager.stop_engine()
				GameManager.trigger_game_over("¡CAÍSTE AL PRECIPICIO!")
	)
	props_container.add_child(abyss_area)

func _spawn_level_unique_features(height_func: Callable) -> void:
	match level_num:
		2: # Nivel 2 (Desierto Magma-Cristal): Ráfagas de viento de arena en el aire en chunks 1 y 3
			if chunk_index == 1 or chunk_index == 3:
				for d_x: float in [480.0, 960.0, 1420.0]:
					var p_x: float = chunk_start_x + d_x
					var p_y: float = float(height_func.call(p_x)) - 18.0
					var sand: CPUParticles2D = CPUParticles2D.new()
					sand.name = "SandDustDrift"
					sand.position = Vector2(p_x, p_y)
					sand.amount = 26
					sand.lifetime = 2.4
					sand.direction = Vector2(-1.0, 0.05)
					sand.spread = 20.0
					sand.gravity = Vector2(0.0, 20.0)
					sand.initial_velocity_min = 160.0
					sand.initial_velocity_max = 300.0
					sand.scale_amount_min = 2.5
					sand.scale_amount_max = 5.0
					sand.color = Color(0.96, 0.74, 0.35, 0.50)
					sand.z_index = 4
					props_container.add_child(sand)

		4: # Nivel 4 (Glaciar Volcánico): Zonas de Hielo Puro / Cero Tracción (Ice Slick) en chunks 1 y 3
			if chunk_index == 1 or chunk_index == 3:
				var x_start: float = chunk_start_x + 420.0
				var x_end: float = chunk_start_x + 1380.0
				var ice_pts_top: PackedVector2Array = PackedVector2Array()
				var ice_pts_bot: PackedVector2Array = PackedVector2Array()
				var steps: int = 30
				for s_i: int in range(steps + 1):
					var ix: float = lerpf(x_start, x_end, float(s_i) / float(steps))
					var iy: float = float(height_func.call(ix))
					ice_pts_top.append(Vector2(ix, iy - 22.0))
					ice_pts_bot.append(Vector2(ix, iy + 30.0))

				var ice_poly_pts: PackedVector2Array = ice_pts_top.duplicate()
				for s_i: int in range(steps, -1, -1):
					ice_poly_pts.append(ice_pts_bot[s_i])

				# Polígono visual brillante de capa de hielo
				var ice_poly: Polygon2D = Polygon2D.new()
				ice_poly.name = "IceSlickPoly"
				ice_poly.polygon = ice_poly_pts
				ice_poly.color = Color(0.72, 0.92, 1.0, 0.58)
				ice_poly.z_index = 2
				props_container.add_child(ice_poly)

				# Líneas de destello reflectante del hielo
				var ice_shine: Line2D = Line2D.new()
				ice_shine.name = "IceShineLine"
				var shine_pts: PackedVector2Array = PackedVector2Array()
				for s_i: int in range(steps + 1):
					var ix: float = lerpf(x_start, x_end, float(s_i) / float(steps))
					shine_pts.append(Vector2(ix, float(height_func.call(ix)) - 2.0))
				ice_shine.points = shine_pts
				ice_shine.width = 6.0
				ice_shine.default_color = Color(0.92, 0.98, 1.0, 0.88)
				ice_shine.z_index = 3
				props_container.add_child(ice_shine)

				# Zona de detección física: Area2D que activa set_on_ice en el vehículo
				var ice_area: Area2D = Area2D.new()
				ice_area.name = "IceSlickArea"
				ice_area.collision_layer = 0
				ice_area.collision_mask = 2
				var col_poly: CollisionPolygon2D = CollisionPolygon2D.new()
				col_poly.polygon = ice_poly_pts
				ice_area.add_child(col_poly)

				ice_area.body_entered.connect(func(body: Node) -> void:
					if body is Vehicle and body.has_method("set_on_ice"):
						body.call("set_on_ice", true)
				)
				ice_area.body_exited.connect(func(body: Node) -> void:
					if body is Vehicle and body.has_method("set_on_ice"):
						body.call("set_on_ice", false)
				)
				props_container.add_child(ice_area)

				var sign_x: float = chunk_start_x + 350.0
				var sign_y: float = float(height_func.call(sign_x))
				var sign_node: Node2D = _create_obstacle_warning_sign(
					sign_x,
					sign_y,
					"❄️ ¡ZONA DE HIELO PURO!\n¡CERO TRACCIÓN - MEDIO PEDAL!",
					Color(0.40, 0.88, 1.0, 1.0)
				)
				props_container.add_child(sign_node)

		7: # Nivel 7 (Autopista Synthwave): Plataforma Turbo Boost Pad Neón en chunks 2 y 4
			if chunk_index == 2 or chunk_index == 4:
				var boost_x: float = chunk_start_x + 520.0
				var boost_y: float = float(height_func.call(boost_x))
				var pad_node: Node2D = _create_turbo_boost_pad(boost_x, boost_y)
				props_container.add_child(pad_node)

				var sign_x: float = chunk_start_x + 380.0
				var sign_y: float = float(height_func.call(sign_x))
				var sign_node: Node2D = _create_obstacle_warning_sign(
					sign_x,
					sign_y,
					"⚡ ¡TURBO BOOST NEÓN!\n¡IMPULSO CATAPULTA A FONDO!",
					Color(1.0, 0.20, 0.80, 1.0)
				)
				props_container.add_child(sign_node)

		10: # Nivel 10 (Nebulosa Lunar-Cósmica): Partículas cósmicas astrales en chunks 1, 3, 5
			if chunk_index == 1 or chunk_index == 3 or chunk_index == 5:
				for s_x: float in [520.0, 880.0, 1240.0]:
					var p_x: float = chunk_start_x + s_x
					var p_y: float = float(height_func.call(p_x)) - 25.0
					var star: CPUParticles2D = CPUParticles2D.new()
					star.name = "CosmicStardust"
					star.position = Vector2(p_x, p_y)
					star.amount = 22
					star.lifetime = 3.2
					star.direction = Vector2(0.3, -1.0)
					star.spread = 45.0
					star.gravity = Vector2(0.0, -12.0)
					star.initial_velocity_min = 35.0
					star.initial_velocity_max = 85.0
					star.scale_amount_min = 2.5
					star.scale_amount_max = 5.5
					star.color = Color(0.72, 0.48, 1.0, 0.60)
					star.z_index = 4
					props_container.add_child(star)

func _create_turbo_boost_pad(pos_x: float, pos_y: float) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = "TurboBoostPad"
	root.position = Vector2(pos_x, pos_y)
	root.z_index = 3

	# Base metálica con iluminación neón
	var base: Polygon2D = Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-55.0, 4.0), Vector2(55.0, 4.0),
		Vector2(48.0, -12.0), Vector2(-48.0, -12.0)
	])
	base.color = Color(0.12, 0.05, 0.22, 0.95)
	root.add_child(base)

	var rim: Line2D = Line2D.new()
	rim.points = PackedVector2Array([
		Vector2(-55.0, 4.0), Vector2(-48.0, -12.0),
		Vector2(48.0, -12.0), Vector2(55.0, 4.0)
	])
	rim.width = 3.0
	rim.default_color = Color(1.0, 0.15, 0.85, 0.95)
	root.add_child(rim)

	# 3 Flechas chevrón neón apuntando hacia adelante (>>>)
	for arr_i: int in range(3):
		var ax: float = -28.0 + float(arr_i) * 28.0
		var chevron: Line2D = Line2D.new()
		chevron.points = PackedVector2Array([
			Vector2(ax - 8.0, -2.0), Vector2(ax + 4.0, -6.0), Vector2(ax - 8.0, -10.0)
		])
		chevron.width = 4.0
		chevron.default_color = Color(0.15, 0.98, 1.0, 0.95)
		root.add_child(chevron)

	# Área de activación de impulso que llama apply_turbo_boost en el vehículo
	var area: Area2D = Area2D.new()
	area.name = "BoostTriggerArea"
	area.collision_layer = 0
	area.collision_mask = 2
	var col: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = Vector2(110.0, 40.0)
	col.shape = box
	col.position = Vector2(0.0, -18.0)
	area.add_child(col)

	area.body_entered.connect(func(body: Node) -> void:
		if body is Vehicle and body.has_method("apply_turbo_boost"):
			body.call("apply_turbo_boost", 420.0)
	)
	root.add_child(area)

	return root

func _create_obstacle_warning_sign(pos_x: float, pos_y: float, text: String, border_col: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	root.position = Vector2(pos_x, pos_y)
	root.z_index = 4

	var post: Polygon2D = Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-5.0, 6.0), Vector2(5.0, 6.0), Vector2(5.0, -76.0), Vector2(-5.0, -76.0)
	])
	post.color = Color(0.24, 0.20, 0.18, 1.0)
	root.add_child(post)

	var board: Polygon2D = Polygon2D.new()
	board.polygon = PackedVector2Array([
		Vector2(-118.0, -132.0), Vector2(118.0, -132.0), Vector2(118.0, -72.0), Vector2(-118.0, -72.0)
	])
	board.color = Color(0.08, 0.10, 0.15, 0.94)
	root.add_child(board)

	var border: Line2D = Line2D.new()
	border.points = PackedVector2Array([
		Vector2(-118.0, -132.0), Vector2(118.0, -132.0),
		Vector2(118.0, -72.0), Vector2(-118.0, -72.0), Vector2(-118.0, -132.0)
	])
	border.width = 3.5
	border.default_color = border_col
	root.add_child(border)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.position = Vector2(-114.0, -128.0)
	lbl.size = Vector2(228.0, 52.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(lbl)

	return root

func _spawn_surface_and_underground_props(points: PackedVector2Array, height_func: Callable) -> void:
	var n_pts: int = points.size()
	if n_pts < 6:
		return

	var obs_type: int = get_chunk_obstacle_type(chunk_index, level_num, goal_world_x)

	# 1. Hito de Distancia cada 100m (cada 6000px)
	for dist_m: int in [100, 200, 300, 400, 500, 750, 1000, 1500, 2000, 3000]:
		var target_x: float = float(dist_m * 60)
		if target_x >= chunk_start_x and target_x < chunk_end_x and absf(target_x - goal_world_x) > 180.0:
			var local_dx: float = target_x - chunk_start_x
			if obs_type != 0 and local_dx > 380.0 and local_dx < 1450.0:
				continue
			var target_y: float = float(height_func.call(target_x))
			_add_distance_marker(target_x, target_y, dist_m)

	# 2. Señales de Rampa de Salto antes de saltos pronunciados (solo cuando no hay obstáculo especial)
	if obs_type == 0:
		for i: int in range(2, n_pts - 4):
			var pt: Vector2 = points[i]
			if pt.x < 450.0:
				continue
			var next_pt: Vector2 = points[i + 2]
			var slope: float = (next_pt.y - pt.y) / (next_pt.x - pt.x)
			if slope < -0.45 and randf() < 0.35:
				var ramp_x: float = pt.x - 35.0
				var ramp_y: float = float(height_func.call(ramp_x))
				var spr: Sprite2D = Sprite2D.new()
				spr.texture = PROP_RAMP
				spr.scale = Vector2(0.85, 0.85)
				# Anclar la base del poste al suelo para que nunca flote
				spr.offset = Vector2(0.0, -float(spr.texture.get_height()) * 0.5)
				spr.position = Vector2(ramp_x, ramp_y + 4.0)
				props_container.add_child(spr)
				break

	# 3. Rocas decorativas en la superficie (variados estilos, fuera de obstáculos)
	var rock_textures: Array[Texture2D] = [ROCK_VAR_0, ROCK_VAR_1, ROCK_VAR_2]
	if obs_type == 0 and randf() < 0.5:
		var r_idx: int = randi_range(3, n_pts - 3)
		var pt: Vector2 = points[r_idx]
		if pt.x >= 450.0:
			var rock: Sprite2D = Sprite2D.new()
			rock.texture = rock_textures[randi() % rock_textures.size()]
			rock.position = pt + Vector2(0.0, -18.0)
			rock.rotation = randf_range(-0.2, 0.2)
			rock.scale = Vector2(randf_range(0.8, 1.2), randf_range(0.8, 1.1))
			rock.modulate = dirt_color.lightened(0.42).lerp(Color.WHITE, 0.55)
			props_container.add_child(rock)

	# 4. SECRETOS SUBTERRÁNEOS ESTRICTAMENTE ENTERRADOS EN LA TIERRA
	var extra_depth: float = 220.0 if obs_type != 0 else 0.0
	# Fósil de Dinosaurio (1 cada 3-4 chunks aprox)
	if posmod(int(chunk_start_x), 5400) < 1800 and randf() < 0.75:
		var dino: Sprite2D = Sprite2D.new()
		dino.texture = FOSSIL_DINO
		var dino_x: float = chunk_start_x + randf_range(350.0, 1450.0)
		var safe_y: float = _get_safe_underground_y(dino_x, 150.0, height_func) + extra_depth
		dino.position = Vector2(dino_x, safe_y + randf_range(160.0, 360.0))
		dino.rotation = randf_range(-0.25, 0.25)
		dino.scale = Vector2(randf_range(0.9, 1.2), randf_range(0.9, 1.2))
		dino.modulate = Color(0.95, 0.9, 0.85, 0.9)
		props_container.add_child(dino)

	# Esqueleto / Cráneo humano antiguo (1 cada 2-3 chunks)
	if randf() < 0.45:
		var skull: Sprite2D = Sprite2D.new()
		skull.texture = FOSSIL_SKULL
		var skull_x: float = chunk_start_x + randf_range(200.0, 1600.0)
		var safe_y: float = _get_safe_underground_y(skull_x, 80.0, height_func) + extra_depth
		skull.position = Vector2(skull_x, safe_y + randf_range(130.0, 280.0))
		skull.rotation = randf_range(-0.4, 0.4)
		skull.scale = Vector2(0.85, 0.85)
		props_container.add_child(skull)

	# Gemas de cristal brillante enterradas
	if randf() < 0.6:
		var gem: Sprite2D = Sprite2D.new()
		gem.texture = BURIED_GEM
		var gem_x: float = chunk_start_x + randf_range(250.0, 1550.0)
		var safe_y: float = _get_safe_underground_y(gem_x, 60.0, height_func) + extra_depth
		gem.position = Vector2(gem_x, safe_y + randf_range(120.0, 350.0))
		gem.rotation = randf_range(-0.3, 0.3)
		gem.scale = Vector2(0.8, 0.8)
		props_container.add_child(gem)

	# Varias piedras enterradas en diferentes profundidades
	var num_buried_rocks: int = randi_range(3, 6)
	var rock_tint: Color = sub_dirt_color.lightened(0.48).lerp(Color(0.85, 0.82, 0.8, 0.85), 0.5)
	rock_tint.a = 0.85
	for b_i: int in range(num_buried_rocks):
		var b_rock: Sprite2D = Sprite2D.new()
		b_rock.texture = rock_textures[b_i % rock_textures.size()]
		var rock_x: float = chunk_start_x + randf_range(100.0, 1700.0)
		var safe_y: float = _get_safe_underground_y(rock_x, 80.0, height_func) + extra_depth
		b_rock.position = Vector2(rock_x, safe_y + randf_range(110.0, 480.0))
		b_rock.rotation = randf_range(-1.5, 1.5)
		b_rock.scale = Vector2(randf_range(0.6, 1.3), randf_range(0.6, 1.2))
		b_rock.modulate = rock_tint
		props_container.add_child(b_rock)

func _get_safe_underground_y(x: float, radius: float, height_func: Callable) -> float:
	# Encontrar el punto más bajo del relieve del terreno (mayor Y en coordenadas de pantalla)
	# para garantizar que toda la caja delimitadora del elemento esté 100% bajo tierra.
	var y_left: float = float(height_func.call(x - radius))
	var y_mid: float = float(height_func.call(x))
	var y_right: float = float(height_func.call(x + radius))
	return maxf(y_mid, maxf(y_left, y_right))

func _add_distance_marker(pos_x: float, pos_y: float, dist_m: int) -> void:
	var marker: Node2D = Node2D.new()
	marker.position = Vector2(pos_x, pos_y)
	
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = PROP_MARKER
	spr.scale = Vector2(0.85, 0.85)
	# Anclar la base del poste al suelo: el centro del sprite se desplaza hacia arriba
	# para que el origen (0, 0) sea el extremo inferior del poste clavado 4px en el suelo
	spr.offset = Vector2(0.0, -float(spr.texture.get_height()) * 0.5)
	spr.position = Vector2(0.0, 4.0)
	marker.add_child(spr)
	
	var lbl: Label = Label.new()
	lbl.text = "%dm" % dist_m
	# Ubicar el texto centrado en la tabla de madera superior del cartel
	lbl.position = Vector2(-35.0, -112.0)
	lbl.size = Vector2(70.0, 30.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.15, 0.2, 1.0))
	marker.add_child(lbl)
	
	props_container.add_child(marker)

func _spawn_items_along_surface(points: PackedVector2Array, height_func: Callable = Callable()) -> void:
	var n_pts: int = points.size()
	if n_pts < 12:
		return

	var obs_type: int = get_chunk_obstacle_type(chunk_index, level_num, goal_world_x)

	# Combustible determinista y ajustado: 1 bidón cada 2 chunks (cada 3600px = 60m)
	# ubicado estratégicamente en local_x = 340px (antes de cualquier obstáculo del chunk)
	var spawn_fuel: bool = chunk_index > 0 and posmod(chunk_index, 2) == 0
	var fuel_index: int = clampi(int(340.0 / 24.0), 4, n_pts - 4)

	if spawn_fuel and points[fuel_index].x >= 450.0 and absf(points[fuel_index].x - goal_world_x) > 140.0:
		var fuel: Node2D = FUEL_SCENE.instantiate() as Node2D
		var pt: Vector2 = points[fuel_index]
		fuel.position = pt + Vector2(0.0, -44.0)
		collectibles_container.add_child(fuel)

	if obs_type == 1:
		# Arco de monedas sobre la laguna de agua para guiar el paso rápido
		for c_i: int in range(4):
			var t_c: float = float(c_i) / 3.0
			var cx: float = chunk_start_x + lerpf(660.0, 1180.0, t_c)
			var cy: float = 615.0 - sin(t_c * PI) * 45.0
			_spawn_coin(Vector2(cx, cy), 1)
		return
	elif obs_type in [2, 3, 4, 5]:
		var gap_end: float = 950.0 + float(level_num - 1) * 8.0
		var launch_y: float = float(height_func.call(chunk_start_x + 760.0)) if height_func.is_valid() else 525.0
		if obs_type == 4:
			# Monedas sobre el balancín steampunk
			for c_i4: int in range(4):
				var t_c4: float = float(c_i4) / 3.0
				var cx4: float = chunk_start_x + lerpf(775.0, gap_end - 15.0, t_c4)
				var cy4: float = 505.0
				_spawn_coin(Vector2(cx4, cy4), 1)
			return
		elif obs_type == 5:
			# Monedas y rubí sobre los paneles quebradizos alienígenas
			for c_i5: int in range(3):
				var t_c5: float = (float(c_i5) + 0.5) / 3.0
				var cx5: float = chunk_start_x + lerpf(775.0, gap_end - 15.0, t_c5)
				var cy5: float = 500.0
				if c_i5 == 1:
					_spawn_ruby(Vector2(cx5, cy5 - 20.0))
				else:
					_spawn_coin(Vector2(cx5, cy5), 10)
			return
		elif obs_type == 2 and level_num == 1:
			# Arco acrobático de 5 monedas en Nivel 1 (tutorial con premio central)
			for c_i2: int in range(5):
				var t_c2: float = float(c_i2) / 4.0
				var cx2: float = chunk_start_x + lerpf(760.0, gap_end + 30.0, t_c2)
				var cy2: float = (launch_y - 25.0) - sin(t_c2 * PI) * 85.0
				var val2: int = 20 if c_i2 == 2 else 1
				_spawn_coin(Vector2(cx2, cy2), val2)
			return
		else:
			# Arco aéreo de monedas sobre el precipicio mortal para guiar la parábola del salto
			for c_i2: int in range(4):
				var t_c2: float = float(c_i2) / 3.0
				var cx2: float = chunk_start_x + lerpf(770.0, gap_end - 15.0, t_c2)
				var cy2: float = (launch_y - 20.0) - sin(t_c2 * PI) * 75.0
				var val2: int = 20 if c_i2 == 2 else 1
				_spawn_coin(Vector2(cx2, cy2), val2)
			if randf() < 0.35:
				_spawn_ruby(Vector2(chunk_start_x + (760.0 + gap_end) * 0.5, launch_y - 135.0))
			return

	# Monedas organizadas en chunks normales: máximo 1 o 2 formaciones limpias por chunk (1800px)
	var formations_spawned: int = 0
	var max_formations: int = 1 if randf() < 0.55 else 2
	var i: int = 10
	while i < n_pts - 14 and formations_spawned < max_formations:
		if absi(i - fuel_index) > 6 and points[i].x >= 500.0:
			var is_jump_arc: bool = randf() < 0.32
			var coin_count: int = 3 if randf() < 0.70 else 4
			var point_step: int = 3 # 72px entre cada moneda de la formación
			
			# Monedas mayoritariamente de valor 1; rara vez 20 o 50 en la cima de un salto
			var special_idx: int = -1
			var special_val: int = 1
			if is_jump_arc:
				special_idx = coin_count / 2
				var roll: float = randf()
				if roll < 0.04:
					special_val = 50
				elif roll < 0.18:
					special_val = 20
			
			for j: int in range(coin_count):
				var pt_idx: int = i + j * point_step
				if pt_idx >= n_pts - 2:
					break
				var base_pt: Vector2 = points[pt_idx]
				var y_lift: float = -48.0
				if is_jump_arc:
					var arc_t: float = float(j) / float(maxi(1, coin_count - 1))
					y_lift -= sin(arc_t * PI) * 115.0
				
				var val: int = special_val if j == special_idx else 1
				_spawn_coin(base_pt + Vector2(0.0, y_lift), val)
				
			formations_spawned += 1
			i += coin_count * point_step + randi_range(22, 34)
		else:
			i += 8

	# Rubí rojo exclusivo: aparece con baja probabilidad en zonas elevadas de salto
	if randf() < 0.18 and n_pts > 16:
		var ruby_idx: int = randi_range(8, n_pts - 8)
		if absi(ruby_idx - fuel_index) > 5:
			var ruby_pt: Vector2 = points[ruby_idx]
			if ruby_pt.x >= 550.0:
				_spawn_ruby(ruby_pt + Vector2(0.0, -95.0))

func _spawn_ruby(pos: Vector2) -> void:
	var ruby: Node2D = RUBY_SCENE.instantiate() as Node2D
	ruby.position = pos
	collectibles_container.add_child(ruby)

func _spawn_coin(pos: Vector2, val: int = 1) -> void:
	var coin: Node2D = COIN_SCENE.instantiate() as Node2D
	coin.position = pos
	collectibles_container.add_child(coin)
	coin.call("set_value", val)

func _add_finish_line_arch(pos_x: float, pos_y: float) -> void:
	var arch_root: Node2D = Node2D.new()
	arch_root.name = "FinishLineArch"
	arch_root.position = Vector2(pos_x, pos_y)
	arch_root.z_index = 3

	var pillar_col: Color = Color(0.14, 0.16, 0.22, 1.0)
	var glow_col: Color = accent_color.lightened(0.20)

	# Postes laterales izquierdo y derecho anclados al suelo
	for side: float in [-95.0, 95.0]:
		var pole: Polygon2D = Polygon2D.new()
		pole.polygon = PackedVector2Array([
			Vector2(side - 9.0, 38.0),
			Vector2(side + 9.0, 38.0),
			Vector2(side + 7.0, -255.0),
			Vector2(side - 7.0, -255.0)
		])
		pole.color = pillar_col
		arch_root.add_child(pole)

		var stripe: Line2D = Line2D.new()
		stripe.points = PackedVector2Array([
			Vector2(side, 24.0),
			Vector2(side, -252.0)
		])
		stripe.width = 4.0
		stripe.default_color = glow_col
		arch_root.add_child(stripe)

		# Banderín superior en cada poste
		var flag_poly: Polygon2D = Polygon2D.new()
		var flag_dir: float = 1.0 if side >= 0.0 else -1.0
		flag_poly.polygon = PackedVector2Array([
			Vector2(side, -255.0),
			Vector2(side, -288.0),
			Vector2(side + 36.0 * flag_dir, -271.0)
		])
		flag_poly.color = glow_col
		arch_root.add_child(flag_poly)

	# Pancarta superior del arco de meta
	var banner_bg: Polygon2D = Polygon2D.new()
	banner_bg.polygon = PackedVector2Array([
		Vector2(-115.0, -255.0),
		Vector2(115.0, -255.0),
		Vector2(110.0, -195.0),
		Vector2(-110.0, -195.0)
	])
	banner_bg.color = Color(0.07, 0.09, 0.14, 0.96)
	arch_root.add_child(banner_bg)

	# Patrón ajedrezado blanco y negro en los bordes superior e inferior
	var sq_w: float = 22.0
	for s_idx: int in range(-5, 5):
		var sx: float = float(s_idx) * sq_w
		var is_white_top: bool = posmod(s_idx, 2) == 0
		var top_sq: Polygon2D = Polygon2D.new()
		top_sq.polygon = PackedVector2Array([
			Vector2(sx, -255.0),
			Vector2(sx + sq_w, -255.0),
			Vector2(sx + sq_w, -245.0),
			Vector2(sx, -245.0)
		])
		top_sq.color = Color(0.96, 0.96, 0.98) if is_white_top else Color(0.10, 0.10, 0.12)
		arch_root.add_child(top_sq)

		var bot_sq: Polygon2D = Polygon2D.new()
		bot_sq.polygon = PackedVector2Array([
			Vector2(sx, -205.0),
			Vector2(sx + sq_w, -205.0),
			Vector2(sx + sq_w, -195.0),
			Vector2(sx, -195.0)
		])
		bot_sq.color = Color(0.10, 0.10, 0.12) if is_white_top else Color(0.96, 0.96, 0.98)
		arch_root.add_child(bot_sq)

	var border_line: Line2D = Line2D.new()
	border_line.points = PackedVector2Array([
		Vector2(-115.0, -255.0),
		Vector2(115.0, -255.0),
		Vector2(110.0, -195.0),
		Vector2(-110.0, -195.0),
		Vector2(-115.0, -255.0)
	])
	border_line.width = 4.0
	border_line.default_color = glow_col
	arch_root.add_child(border_line)

	var meta_lbl: Label = Label.new()
	meta_lbl.text = "🏁 META 🏁"
	meta_lbl.position = Vector2(-105.0, -242.0)
	meta_lbl.size = Vector2(210.0, 36.0)
	meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_lbl.add_theme_font_size_override("font_size", 24)
	meta_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
	meta_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	meta_lbl.add_theme_constant_override("shadow_offset_x", 2)
	meta_lbl.add_theme_constant_override("shadow_offset_y", 2)
	arch_root.add_child(meta_lbl)

	props_container.add_child(arch_root)

func _spawn_fused_theme_props(points: PackedVector2Array, height_func: Callable) -> void:
	var n_pts: int = points.size()
	if n_pts < 10:
		return

	var obs_type: int = get_chunk_obstacle_type(chunk_index, level_num, goal_world_x)
	var count: int = randi_range(3, 5)
	for k: int in range(count):
		var idx: int = clampi(int(float(k + 1) * float(n_pts) / float(count + 1)) + randi_range(-3, 3), 3, n_pts - 4)
		var pt: Vector2 = points[idx]
		if pt.x < 480.0 or absf(pt.x - goal_world_x) < 160.0:
			continue
		var local_dx: float = pt.x - chunk_start_x
		if obs_type != 0 and local_dx > 360.0 and local_dx < 1460.0:
			continue
		var ground_y: float = float(height_func.call(pt.x))
		var prop_node: Node2D = _build_theme_prop_for_level(level_num)
		prop_node.position = Vector2(pt.x, ground_y + 4.0)
		props_container.add_child(prop_node)

func _build_theme_prop_for_level(lvl: int) -> Node2D:
	var root: Node2D = Node2D.new()
	var sc: float = randf_range(0.85, 1.25)
	root.scale = Vector2(sc, sc)

	match lvl:
		1:
			# Nivel 1 (Cyber-Solar): Prisma de cristal solar cian + arbusto esmeralda
			var bush: Polygon2D = Polygon2D.new()
			bush.polygon = PackedVector2Array([
				Vector2(-28.0, 4.0), Vector2(-22.0, -18.0), Vector2(-6.0, -26.0),
				Vector2(12.0, -22.0), Vector2(26.0, -12.0), Vector2(28.0, 4.0)
			])
			bush.color = surface_color.darkened(0.18)
			root.add_child(bush)

			var crystal: Polygon2D = Polygon2D.new()
			crystal.polygon = PackedVector2Array([
				Vector2(-10.0, 2.0), Vector2(-14.0, -34.0), Vector2(0.0, -64.0),
				Vector2(14.0, -32.0), Vector2(10.0, 2.0)
			])
			crystal.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.88)
			root.add_child(crystal)

			var core: Polygon2D = Polygon2D.new()
			core.polygon = PackedVector2Array([
				Vector2(-4.0, -4.0), Vector2(0.0, -54.0), Vector2(6.0, -26.0)
			])
			core.color = Color(0.85, 1.0, 1.0, 0.92)
			root.add_child(core)
		2:
			# Nivel 2 (Desierto Magma-Cristal): Agujas de cuarzo rojo/naranja + grieta de lava
			for side_x: float in [-14.0, 0.0, 14.0]:
				var h: float = -62.0 if side_x == 0.0 else -40.0
				var spire: Polygon2D = Polygon2D.new()
				spire.polygon = PackedVector2Array([
					Vector2(side_x - 8.0, 4.0),
					Vector2(side_x - 4.0, h * 0.65),
					Vector2(side_x, h),
					Vector2(side_x + 8.0, 4.0)
				])
				spire.color = accent_color.lightened(0.12 if side_x == 0.0 else -0.12)
				root.add_child(spire)

			var crack: Line2D = Line2D.new()
			crack.points = PackedVector2Array([
				Vector2(-26.0, 2.0), Vector2(-8.0, -3.0), Vector2(8.0, 3.0), Vector2(26.0, -1.0)
			])
			crack.width = 4.0
			crack.default_color = Color(1.0, 0.86, 0.22, 0.95)
			root.add_child(crack)
		3:
			# Nivel 3 (Jungla Bioluminiscente): Hongo gigante neón violeta/cian
			var stem: Polygon2D = Polygon2D.new()
			stem.polygon = PackedVector2Array([
				Vector2(-7.0, 4.0), Vector2(-5.0, -38.0), Vector2(5.0, -38.0), Vector2(7.0, 4.0)
			])
			stem.color = Color(0.72, 0.88, 0.98, 0.92)
			root.add_child(stem)

			var cap: Polygon2D = Polygon2D.new()
			cap.polygon = PackedVector2Array([
				Vector2(-32.0, -34.0), Vector2(-22.0, -54.0), Vector2(0.0, -64.0),
				Vector2(22.0, -54.0), Vector2(32.0, -34.0)
			])
			cap.color = accent_color
			root.add_child(cap)

			var glow_rim: Line2D = Line2D.new()
			glow_rim.points = PackedVector2Array([
				Vector2(-30.0, -35.0), Vector2(0.0, -42.0), Vector2(30.0, -35.0)
			])
			glow_rim.width = 4.0
			glow_rim.default_color = surface_color.lightened(0.35)
			root.add_child(glow_rim)
		4:
			# Nivel 4 (Glaciar Volcánico): Picos de hielo azul + respiradero termal de fuego
			var vent: Polygon2D = Polygon2D.new()
			vent.polygon = PackedVector2Array([
				Vector2(-24.0, 4.0), Vector2(-14.0, -18.0), Vector2(14.0, -18.0), Vector2(24.0, 4.0)
			])
			vent.color = Color(0.98, 0.42, 0.14, 0.92)
			root.add_child(vent)

			var ice: Polygon2D = Polygon2D.new()
			ice.polygon = PackedVector2Array([
				Vector2(-12.0, 2.0), Vector2(-18.0, -44.0), Vector2(-2.0, -72.0),
				Vector2(14.0, -38.0), Vector2(10.0, 2.0)
			])
			ice.color = Color(0.72, 0.94, 1.0, 0.86)
			root.add_child(ice)
		5:
			# Nivel 5 (Steampunk): Engranaje de bronce y tubería de vapor
			var pipe: Polygon2D = Polygon2D.new()
			pipe.polygon = PackedVector2Array([
				Vector2(-10.0, 4.0), Vector2(-10.0, -54.0), Vector2(10.0, -54.0), Vector2(10.0, 4.0)
			])
			pipe.color = Color(0.58, 0.36, 0.20, 1.0)
			root.add_child(pipe)

			var gear: Polygon2D = Polygon2D.new()
			var g_pts: PackedVector2Array = PackedVector2Array()
			for a_i: int in range(16):
				var ang: float = float(a_i) * TAU / 16.0
				var rad: float = 26.0 if posmod(a_i, 2) == 0 else 19.0
				g_pts.append(Vector2(cos(ang) * rad, -36.0 + sin(ang) * rad))
			gear.polygon = g_pts
			gear.color = accent_color
			root.add_child(gear)
		6:
			# Nivel 6 (Pantano Tóxico): Cristales químicos verde ácido y burbujas
			var shard: Polygon2D = Polygon2D.new()
			shard.polygon = PackedVector2Array([
				Vector2(-14.0, 4.0), Vector2(-8.0, -52.0), Vector2(4.0, -64.0),
				Vector2(16.0, -28.0), Vector2(12.0, 4.0)
			])
			shard.color = accent_color
			root.add_child(shard)

			for b_pos: Vector2 in [Vector2(-18.0, -22.0), Vector2(16.0, -42.0), Vector2(2.0, -74.0)]:
				var bub: Polygon2D = Polygon2D.new()
				bub.polygon = PackedVector2Array([
					b_pos + Vector2(-7.0, 0.0), b_pos + Vector2(0.0, -7.0),
					b_pos + Vector2(7.0, 0.0), b_pos + Vector2(0.0, 7.0)
				])
				bub.color = Color(0.82, 1.0, 0.35, 0.88)
				root.add_child(bub)
		7:
			# Nivel 7 (Synthwave-84): Pilar retro-láser magenta/cian con rejilla neón
			var pyra: Polygon2D = Polygon2D.new()
			pyra.polygon = PackedVector2Array([
				Vector2(-26.0, 4.0), Vector2(0.0, -68.0), Vector2(26.0, 4.0)
			])
			pyra.color = Color(0.14, 0.04, 0.28, 0.92)
			root.add_child(pyra)

			var wire: Line2D = Line2D.new()
			wire.points = PackedVector2Array([
				Vector2(-26.0, 4.0), Vector2(0.0, -68.0), Vector2(26.0, 4.0), Vector2(-26.0, 4.0)
			])
			wire.width = 3.5
			wire.default_color = surface_highlight
			root.add_child(wire)
		8:
			# Nivel 8 (Caramelo-Helado): Bastón de caramelo / piruleta escarchada
			var stick: Polygon2D = Polygon2D.new()
			stick.polygon = PackedVector2Array([
				Vector2(-5.0, 4.0), Vector2(-5.0, -52.0), Vector2(5.0, -52.0), Vector2(5.0, 4.0)
			])
			stick.color = Color(0.98, 0.96, 1.0, 1.0)
			root.add_child(stick)

			var candy: Polygon2D = Polygon2D.new()
			var c_pts: PackedVector2Array = PackedVector2Array()
			for c_i: int in range(12):
				var c_ang: float = float(c_i) * TAU / 12.0
				c_pts.append(Vector2(cos(c_ang) * 22.0, -58.0 + sin(c_ang) * 22.0))
			candy.polygon = c_pts
			candy.color = accent_color
			root.add_child(candy)
		9:
			# Nivel 9 (Ruinas Alien-Doradas): Obelisco dorado con cristal de energía flotante
			var obelisk: Polygon2D = Polygon2D.new()
			obelisk.polygon = PackedVector2Array([
				Vector2(-14.0, 4.0), Vector2(-9.0, -52.0), Vector2(0.0, -64.0),
				Vector2(9.0, -52.0), Vector2(14.0, 4.0)
			])
			obelisk.color = accent_color
			root.add_child(obelisk)

			var float_gem: Polygon2D = Polygon2D.new()
			float_gem.polygon = PackedVector2Array([
				Vector2(0.0, -96.0), Vector2(12.0, -82.0), Vector2(0.0, -68.0), Vector2(-12.0, -82.0)
			])
			float_gem.color = surface_highlight
			root.add_child(float_gem)
		_:
			# Nivel 10 (Nebulosa Lunar-Cósmica): Monolito astral púrpura y halo cósmico
			var mono: Polygon2D = Polygon2D.new()
			mono.polygon = PackedVector2Array([
				Vector2(-14.0, 4.0), Vector2(-11.0, -68.0), Vector2(0.0, -82.0),
				Vector2(11.0, -68.0), Vector2(14.0, 4.0)
			])
			mono.color = Color(0.24, 0.16, 0.46, 0.95)
			root.add_child(mono)

			var aura: Line2D = Line2D.new()
			aura.points = PackedVector2Array([
				Vector2(-14.0, 2.0), Vector2(-11.0, -68.0), Vector2(0.0, -82.0),
				Vector2(11.0, -68.0), Vector2(14.0, 2.0)
			])
			aura.width = 3.5
			aura.default_color = accent_color.lightened(0.25)
			root.add_child(aura)

	return root

func _spawn_ambient_life(_points: PackedVector2Array, height_func: Callable) -> void:
	# Probabilidad del 65% de vida ambiental por chunk para que los mapas se sientan vivos
	if randf() > 0.65:
		return
	
	var spawn_count: int = 1 if randf() < 0.70 else 2
	for _s_idx: int in range(spawn_count):
		var center_x: float = chunk_start_x + randf_range(250.0, 1550.0)
		var ground_y: float = float(height_func.call(center_x))
		var center_y: float = ground_y - randf_range(240.0, 480.0)
		
		var ambient_node: Node2D = null
		
		match level_num:
			1:
				# Nivel 1 (Pradera Cyber-Solar): Bandada de aves elegantes volando
				ambient_node = AmbientFlockBirds.new()
			2:
				# Nivel 2 (Desierto Magma-Cristal): Buitres/Cóndores planeando en círculos térmicos
				ambient_node = AmbientDesertVultures.new()
			3:
				# Nivel 3 (Jungla Bioluminiscente): Enjambre de luciérnagas y esporas de neón flotantes
				ambient_node = AmbientNeonFireflies.new()
			4:
				# Nivel 4 (Glaciar Volcánico): Ventisca de nieve helada y halcón ártico
				ambient_node = AmbientArcticStorm.new()
			5:
				# Nivel 5 (Cañón Steampunk): Aves planeando en el cañón (sin trenes)
				ambient_node = AmbientDesertVultures.new()
			6:
				# Nivel 6 (Pantano Tóxico): Libélulas mutantes gigantes de 4 alas fosforescentes
				ambient_node = AmbientSwampDragonfly.new()
			7:
				# Nivel 7 (Autopista Synthwave): Avión jet supersónico ciberpunk con estela y luces de navegación
				ambient_node = AmbientSynthJet.new()
			8:
				# Nivel 8 (Cumbre Caramelo): Globo aerostático de caramelo y mariposas de azúcar
				ambient_node = AmbientCandySky.new()
			9:
				# Nivel 9 (Ruinas Alien-Doradas): OVNI antigravitatorio con anillo de luces y haz de energía
				ambient_node = AmbientAlienSaucer.new()
			_:
				# Nivel 10 (Nebulosa Lunar-Cósmica): Cometas y estrellas fugaces cósmicas con estela estelar
				ambient_node = AmbientCosmicComet.new()
				center_y = ground_y - randf_range(450.0, 750.0)
				
		if ambient_node != null:
			ambient_node.position = Vector2(center_x, center_y)
			ambient_node.z_index = -3 # En el fondo, detrás del terreno
			props_container.add_child(ambient_node)

# ── Clases Procedurales de Vida Ambiental por Bioma ──────────────────────────

class AmbientFlockBirds extends Node2D:
	var speed: float = 135.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 26.0
	var time: float = 0.0
	var bird_offsets: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(-28.0, -14.0), Vector2(-54.0, -26.0), Vector2(-32.0, 16.0)
	]
	func _init() -> void:
		speed = randf_range(110.0, 160.0)
		direction = 1.0 if randf() < 0.6 else -1.0
		max_lifetime = 26.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 11.0
		position.y += sin(time * 0.25) * 0.4
		queue_redraw()

	func _draw() -> void:
		var flap: float = sin(time) * 9.0
		var wing_dir: float = direction
		for b_pos: Vector2 in bird_offsets:
			var bx: float = b_pos.x * wing_dir
			var by: float = b_pos.y
			# Ala izquierda y derecha estilizadas
			var wing_l: PackedVector2Array = PackedVector2Array([
				Vector2(bx, by), Vector2(bx - 12.0 * wing_dir, by - 5.0 + flap), Vector2(bx - 16.0 * wing_dir, by + flap * 0.5)
			])
			var wing_r: PackedVector2Array = PackedVector2Array([
				Vector2(bx, by), Vector2(bx + 12.0 * wing_dir, by - 5.0 + flap), Vector2(bx + 16.0 * wing_dir, by + flap * 0.5)
			])
			draw_polyline(wing_l, Color(0.12, 0.16, 0.22, 0.85), 2.8, true)
			draw_polyline(wing_r, Color(0.12, 0.16, 0.22, 0.85), 2.8, true)
			draw_circle(Vector2(bx, by), 2.4, Color(0.08, 0.10, 0.15, 0.95))

class AmbientDesertVultures extends Node2D:
	var speed: float = 0.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 45.0
	var time: float = 0.0
	var origin: Vector2 = Vector2.ZERO
	var radius_x: float = 160.0
	var radius_y: float = 55.0
	var initialized: bool = false
	func _init() -> void:
		speed = 0.0
		max_lifetime = 45.0
		time = randf() * TAU

	func _process(delta: float) -> void:
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		if not initialized:
			origin = position
			initialized = true
		time += delta * 0.65
		position = origin + Vector2(cos(time) * radius_x, sin(time) * radius_y)
		queue_redraw()

	func _draw() -> void:
		var wing_tilt: float = sin(time * 3.5) * 3.0
		var facing: float = 1.0 if sin(time) > 0.0 else -1.0
		# Silueta majestuosa de cóndor del desierto
		var body_pts: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, -3.0), Vector2(6.0 * facing, 0.0), Vector2(0.0, 3.0), Vector2(-14.0 * facing, 0.0)
		])
		draw_colored_polygon(body_pts, Color(0.14, 0.10, 0.08, 0.9))
		# Alas abiertas con puntas primarias
		var left_wing: PackedVector2Array = PackedVector2Array([
			Vector2(-4.0 * facing, 0.0), Vector2(-8.0 * facing, -24.0 + wing_tilt), Vector2(-2.0 * facing, -26.0 + wing_tilt), Vector2(2.0 * facing, 0.0)
		])
		var right_wing: PackedVector2Array = PackedVector2Array([
			Vector2(-4.0 * facing, 0.0), Vector2(-8.0 * facing, 24.0 - wing_tilt), Vector2(-2.0 * facing, 26.0 - wing_tilt), Vector2(2.0 * facing, 0.0)
		])
		draw_colored_polygon(left_wing, Color(0.18, 0.12, 0.10, 0.85))
		draw_colored_polygon(right_wing, Color(0.15, 0.10, 0.08, 0.85))

class AmbientNeonFireflies extends Node2D:
	var speed: float = 24.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 35.0
	var time: float = 0.0
	var count: int = 7
	var offsets: Array[Vector2] = []
	var colors: Array[Color] = []
	func _init() -> void:
		speed = randf_range(16.0, 32.0)
		direction = 1.0 if randf() < 0.5 else -1.0
		max_lifetime = 35.0
		var palette: Array[Color] = [
			Color(0.25, 1.0, 0.75), Color(0.78, 0.25, 1.0), Color(0.35, 0.85, 1.0), Color(1.0, 0.92, 0.35)
		]
		for k: int in range(count):
			offsets.append(Vector2(randf_range(-70.0, 70.0), randf_range(-40.0, 40.0)))
			colors.append(palette[k % palette.size()])

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 2.8
		position.y += sin(time * 0.4) * 0.6
		queue_redraw()

	func _draw() -> void:
		for k: int in range(count):
			var kf: float = float(k)
			var pulse: float = sin(time * 2.5 + kf * 1.3) * 0.5 + 0.5
			var cur_p: Vector2 = offsets[k] + Vector2(cos(time * 1.2 + kf) * 14.0, sin(time * 1.8 + kf) * 12.0)
			var base_c: Color = colors[k]
			# Halo difuso exterior
			draw_circle(cur_p, 9.0 + 3.0 * pulse, Color(base_c.r, base_c.g, base_c.b, 0.20 * pulse))
			# Núcleo brillante
			draw_circle(cur_p, 3.2, Color(base_c.r, base_c.g, base_c.b, 0.90))
			draw_circle(cur_p, 1.4, Color.WHITE)

class AmbientArcticStorm extends Node2D:
	var speed: float = 0.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 30.0
	var particles: CPUParticles2D = null
	var time: float = 0.0
	var eagle_x: float = 0.0
	func _init() -> void:
		speed = 0.0
		max_lifetime = 30.0
		particles = CPUParticles2D.new()
		particles.amount = 75
		particles.lifetime = 2.4
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(500.0, 20.0)
		particles.direction = Vector2(0.8, 1.0).normalized()
		particles.spread = 18.0
		particles.gravity = Vector2(60.0, 110.0)
		particles.initial_velocity_min = 90.0
		particles.initial_velocity_max = 180.0
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.5
		particles.color = Color(0.92, 0.96, 1.0, 0.85)
		add_child(particles)

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 4.0
		eagle_x += delta * 120.0
		queue_redraw()

	func _draw() -> void:
		# Halcón ártico planeando sobre la ventisca
		var ex: float = -200.0 + fmod(eagle_x, 600.0)
		var ey: float = sin(time * 0.4) * 15.0 - 40.0
		var flap: float = sin(time * 1.5) * 3.5
		draw_polyline(PackedVector2Array([
			Vector2(ex - 18.0, ey - 6.0 + flap), Vector2(ex, ey), Vector2(ex + 18.0, ey - 6.0 + flap)
		]), Color(0.85, 0.94, 1.0, 0.9), 3.0, true)

class AmbientSwampDragonfly extends Node2D:
	var speed: float = 135.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 24.0
	var time: float = 0.0
	func _init() -> void:
		speed = randf_range(110.0, 160.0)
		direction = -1.0 if randf() < 0.5 else 1.0
		max_lifetime = 24.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 24.0
		position.y += sin(time * 0.35) * 2.2 + cos(time * 0.8) * 1.0 # Vuelo errático
		queue_redraw()

	func _draw() -> void:
		var wing_flap: float = sin(time)
		var f: float = direction
		# Cuerpo estilizado esmeralda / lima neón
		draw_line(Vector2(-14.0 * f, 0.0), Vector2(16.0 * f, 0.0), Color(0.15, 0.95, 0.45, 0.95), 3.0)
		draw_circle(Vector2(16.0 * f, 0.0), 4.0, Color(0.2, 1.0, 0.6, 1.0))
		# Ojos brillantes
		draw_circle(Vector2(17.0 * f, -2.0), 1.5, Color(1.0, 0.25, 0.25, 0.9))
		# 4 alas translúcidas con aleteo ultrarrápido
		for wx: float in [-2.0, 7.0]:
			var wing_up: PackedVector2Array = PackedVector2Array([
				Vector2(wx * f, 0.0), Vector2((wx + 4.0) * f, -18.0 * wing_flap), Vector2((wx - 3.0) * f, -18.0 * wing_flap)
			])
			var wing_down: PackedVector2Array = PackedVector2Array([
				Vector2(wx * f, 0.0), Vector2((wx + 4.0) * f, 18.0 * wing_flap), Vector2((wx - 3.0) * f, 18.0 * wing_flap)
			])
			draw_colored_polygon(wing_up, Color(0.65, 1.0, 0.85, 0.55))
			draw_colored_polygon(wing_down, Color(0.65, 1.0, 0.85, 0.55))

class AmbientSynthJet extends Node2D:
	var speed: float = 350.0
	var direction: float = -1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 22.0
	var time: float = 0.0
	var contrail_points: Array[Vector2] = []
	func _init() -> void:
		speed = randf_range(280.0, 420.0)
		direction = -1.0
		max_lifetime = 22.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 6.0
		contrail_points.append(global_position + Vector2(24.0, 0.0))
		if contrail_points.size() > 40:
			contrail_points.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		# Estela de condensación retrofuturista
		if contrail_points.size() > 2:
			var pts: PackedVector2Array = PackedVector2Array()
			for gp: Vector2 in contrail_points:
				pts.append(to_local(gp))
			draw_polyline(pts, Color(0.98, 0.35, 0.85, 0.38), 5.0, true)
			draw_polyline(pts, Color(0.35, 0.95, 1.0, 0.55), 2.2, true)

		# Jet ciberpunk
		var jet_pts: PackedVector2Array = PackedVector2Array([
			Vector2(26.0, 0.0), Vector2(-14.0, 8.0), Vector2(-22.0, 14.0), Vector2(-18.0, 0.0), Vector2(-22.0, -14.0), Vector2(-14.0, -8.0)
		])
		draw_colored_polygon(jet_pts, Color(0.18, 0.12, 0.28, 0.95))
		draw_colored_polygon(PackedVector2Array([
			Vector2(2.0, 0.0), Vector2(-12.0, -26.0), Vector2(-18.0, -26.0), Vector2(-8.0, 0.0)
		]), Color(0.24, 0.16, 0.38, 0.95)) # Ala superior
		draw_colored_polygon(PackedVector2Array([
			Vector2(2.0, 0.0), Vector2(-12.0, 26.0), Vector2(-18.0, 26.0), Vector2(-8.0, 0.0)
		]), Color(0.24, 0.16, 0.38, 0.95)) # Ala inferior
		# Fuego del postquemador (afterburner)
		var flame_len: float = randf_range(16.0, 28.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-18.0, -3.0), Vector2(-18.0 - flame_len, 0.0), Vector2(-18.0, 3.0)
		]), Color(0.15, 0.95, 1.0, 0.95))
		# Luz estroboscópica parpadeante
		if fmod(time, 1.0) < 0.15:
			draw_circle(Vector2(-14.0, -26.0), 3.0, Color(1.0, 0.2, 0.3, 1.0))
			draw_circle(Vector2(-14.0, 26.0), 3.0, Color(0.2, 1.0, 0.4, 1.0))

class AmbientCandySky extends Node2D:
	var speed: float = 48.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 40.0
	var time: float = 0.0
	func _init() -> void:
		speed = randf_range(35.0, 60.0)
		direction = 1.0
		max_lifetime = 40.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 3.5
		position.y += sin(time * 0.5) * 0.8
		queue_redraw()

	func _draw() -> void:
		# Globo aerostático de rayas de dulce
		var r: float = 24.0
		var balloon_center: Vector2 = Vector2(0.0, -32.0)
		draw_circle(balloon_center, r, Color(1.0, 0.45, 0.72, 0.95))
		# Rayas de caramelo
		draw_line(balloon_center + Vector2(-14.0, 0.0), balloon_center + Vector2(-14.0, 18.0), Color(1.0, 0.92, 0.95, 0.9), 3.5)
		draw_line(balloon_center + Vector2(0.0, -r), balloon_center + Vector2(0.0, r), Color(1.0, 0.92, 0.95, 0.9), 4.0)
		draw_line(balloon_center + Vector2(14.0, 0.0), balloon_center + Vector2(14.0, 18.0), Color(1.0, 0.92, 0.95, 0.9), 3.5)
		# Cesta y cuerdas
		draw_line(balloon_center + Vector2(-10.0, r), Vector2(-6.0, 2.0), Color(0.45, 0.32, 0.22, 0.8), 1.5)
		draw_line(balloon_center + Vector2(10.0, r), Vector2(6.0, 2.0), Color(0.45, 0.32, 0.22, 0.8), 1.5)
		draw_rect(Rect2(-7.0, 2.0, 14.0, 10.0), Color(0.65, 0.45, 0.30, 1.0))

class AmbientAlienSaucer extends Node2D:
	var speed: float = 65.0
	var direction: float = 1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 35.0
	var time: float = 0.0
	func _init() -> void:
		speed = randf_range(45.0, 85.0)
		direction = -1.0 if randf() < 0.5 else 1.0
		max_lifetime = 35.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		time += delta * 4.5
		position.y += sin(time * 0.6) * 1.2
		queue_redraw()

	func _draw() -> void:
		# Haz de tracción pulsante hacia abajo
		var beam_alpha: float = sin(time * 2.0) * 0.12 + 0.18
		draw_colored_polygon(PackedVector2Array([
			Vector2(-16.0, 8.0), Vector2(16.0, 8.0), Vector2(45.0, 95.0), Vector2(-45.0, 95.0)
		]), Color(0.2, 1.0, 0.8, beam_alpha))

		# Cúpula de cristal extraterrestre
		var dome_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(11):
			var a: float = PI + float(i) * PI / 10.0
			dome_pts.append(Vector2(cos(a) * 16.0, -4.0 + sin(a) * 16.0))
		draw_colored_polygon(dome_pts, Color(0.35, 0.95, 1.0, 0.85))

		# Platillo metálico dorado
		var saucer_pts: PackedVector2Array = PackedVector2Array([
			Vector2(-38.0, 0.0), Vector2(38.0, 0.0), Vector2(24.0, 9.0), Vector2(-24.0, 9.0)
		])
		draw_colored_polygon(saucer_pts, Color(0.92, 0.76, 0.25, 0.98))
		draw_line(Vector2(-38.0, 0.0), Vector2(38.0, 0.0), Color(1.0, 0.92, 0.55, 1.0), 2.2)

		# Luces perimetrales giratorias neón
		for i: int in range(5):
			var light_x: float = -26.0 + float(i) * 13.0
			var active_light: bool = int(time * 3.0 + float(i)) % 5 == 0
			var l_col: Color = Color(0.2, 1.0, 0.6, 1.0) if active_light else Color(0.95, 0.3, 0.3, 0.8)
			draw_circle(Vector2(light_x, 4.0), 2.6, l_col)

class AmbientCosmicComet extends Node2D:
	var speed: float = 580.0
	var direction: float = -1.0
	var lifetime: float = 0.0
	var max_lifetime: float = 6.0
	var time: float = 0.0
	var trail_history: Array[Vector2] = []
	func _init() -> void:
		speed = randf_range(480.0, 680.0)
		direction = -1.0
		max_lifetime = 6.0

	func _process(delta: float) -> void:
		position.x += speed * direction * delta
		lifetime += delta
		if lifetime > max_lifetime:
			queue_free()
			return
		position.y += speed * delta * 0.42 # Trayectoria diagonal
		trail_history.append(global_position)
		if trail_history.size() > 25:
			trail_history.remove_at(0)
		queue_redraw()

	func _draw() -> void:
		if trail_history.size() > 2:
			var pts: PackedVector2Array = PackedVector2Array()
			for gp: Vector2 in trail_history:
				pts.append(to_local(gp))
			draw_polyline(pts, Color(0.35, 0.85, 1.0, 0.35), 6.0, true)
			draw_polyline(pts, Color(0.95, 0.45, 1.0, 0.65), 3.0, true)
			draw_polyline(pts, Color.WHITE, 1.5, true)
		# Cabeza del cometa incandescente
		draw_circle(Vector2.ZERO, 9.0, Color(0.4, 0.85, 1.0, 0.4))
		draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.95, 1.0, 0.95))
		draw_circle(Vector2.ZERO, 2.5, Color.WHITE)

class SeesawPlatform extends AnimatableBody2D:
	var target_angle: float = -0.16
	var resting_angle: float = -0.16
	var vehicle_ref: Vehicle = null
	var pivot_world_x: float = 0.0

	func _ready() -> void:
		sync_to_physics = true

	func _physics_process(delta: float) -> void:
		if is_instance_valid(vehicle_ref) and not vehicle_ref.is_crashed:
			var dx: float = vehicle_ref.global_position.x - pivot_world_x
			if dx > 15.0:
				target_angle = 0.16
			elif dx < -15.0:
				target_angle = -0.16
		else:
			target_angle = resting_angle

		rotation = lerp_angle(rotation, target_angle, 5.0 * delta)

class BrittleAlienPanel extends StaticBody2D:
	var time_left: float = 1.2
	var is_triggered: bool = false
	var is_broken: bool = false
	var col_shape: CollisionShape2D = null
	var visual_poly: Polygon2D = null
	var core_line: Line2D = null

	func _process(delta: float) -> void:
		if is_triggered and not is_broken:
			time_left -= delta
			var pulse: float = absf(sin(time_left * 28.0))
			if visual_poly != null:
				visual_poly.color = Color(1.0, 0.35 + 0.65 * pulse, 0.2 + 0.8 * pulse, 0.45 + 0.55 * pulse)
			if core_line != null:
				core_line.default_color = Color(1.0, 0.2 + 0.8 * pulse, 0.1, 0.9)
			if time_left <= 0.0:
				break_panel()

	func trigger() -> void:
		if not is_triggered and not is_broken:
			is_triggered = true
			SoundManager.play_sfx("fuel", 1.9)

	func break_panel() -> void:
		is_broken = true
		if col_shape != null:
			col_shape.set_deferred("disabled", true)
		visible = false
		SoundManager.play_sfx("crash", 2.2)

