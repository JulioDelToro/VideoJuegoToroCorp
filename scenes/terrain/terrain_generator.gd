extends Node2D
class_name TerrainGenerator

# Generador dinámico de terreno infinito procedural con puentes, rampas acrobáticas,
# colinas rítmicas, dificultad progresiva y gráficos mejorados estilo Hill Climb Racing

@export var chunk_width: float = 1800.0
@export var step_resolution: float = 24.0 # Mayor resolución de curvas para terreno suave
@export var spawn_ahead_distance: float = 4000.0
@export var despawn_behind_distance: float = 4500.0 # Asegura que nunca se corte visualmente detrás

const CHUNK_SCENE = preload("res://scenes/terrain/terrain_chunk.tscn")

var active_chunks: Array[TerrainChunk] = []
var _chunk_pool: Array[Node2D] = []
var _next_chunk_idx: int = -1
var highest_generated_x: float = -1800.0
var target_node: Node2D = null

var hill_scale: float = 1.0
var level_num: int = 1
var goal_world_x: float = 21200.0
var surface_color: Color = Color(0.18, 0.78, 0.42)
var surface_highlight: Color = Color(0.25, 0.98, 0.78)
var dirt_color: Color = Color(0.22, 0.15, 0.12)
var sub_dirt_color: Color = Color(0.12, 0.09, 0.14)
var accent_color: Color = Color(0.18, 0.95, 0.82)

func _ready() -> void:
	var route_data: Dictionary = GameManager.get_selected_route_data()
	level_num = int(route_data.get("level_num", 1))
	hill_scale = float(route_data.get("hill_scale", 1.0))
	surface_color = route_data.get("surface_color", Color(0.18, 0.78, 0.42)) as Color
	var default_highlight: Color = surface_color.lightened(0.18)
	surface_highlight = route_data.get("surface_highlight", default_highlight) as Color
	dirt_color = route_data.get("dirt_color", Color(0.22, 0.15, 0.12)) as Color
	sub_dirt_color = route_data.get("sub_dirt_color", Color(0.12, 0.09, 0.14)) as Color
	accent_color = route_data.get("accent_color", surface_highlight) as Color
	goal_world_x = 200.0 + GameManager.get_level_goal_distance() * 60.0

	_generate_initial_terrain()

func set_target(target: Node2D) -> void:
	target_node = target

func _process(_delta: float) -> void:
	if not target_node:
		return

	var target_x: float = target_node.global_position.x
	var min_chunk: int = int(floor((target_x - despawn_behind_distance) / chunk_width))

	# Reciclar primero chunks antiguos que quedaron detrás de min_chunk - 1 hacia _chunk_pool
	var i: int = active_chunks.size() - 1
	while i >= 0:
		var chunk: TerrainChunk = active_chunks[i]
		if chunk.chunk_index < min_chunk - 1 or chunk.chunk_end_x < target_x - despawn_behind_distance:
			active_chunks.remove_at(i)
			_recycle_chunk(chunk)
		i -= 1

	# Generar o reutilizar chunks hacia adelante desde el pool
	while highest_generated_x < target_x + spawn_ahead_distance:
		_spawn_chunk(_next_chunk_idx)

func _generate_initial_terrain() -> void:
	_next_chunk_idx = -1
	highest_generated_x = float(_next_chunk_idx) * chunk_width
	while highest_generated_x < 3800.0:
		_spawn_chunk(_next_chunk_idx)

func _spawn_next_chunk() -> void:
	_spawn_chunk(_next_chunk_idx)

func _spawn_chunk(chunk_idx: int) -> void:
	var start_x: float = float(chunk_idx) * chunk_width
	var end_x: float = start_x + chunk_width

	var chunk: TerrainChunk = null
	if not _chunk_pool.is_empty():
		var pooled_node: Node2D = _chunk_pool.pop_back()
		chunk = pooled_node as TerrainChunk
		if chunk.get_parent() == null:
			add_child(chunk)
	else:
		chunk = CHUNK_SCENE.instantiate() as TerrainChunk
		add_child(chunk)

	chunk.chunk_index = chunk_idx
	var spawn_items: bool = end_x > 450.0
	chunk.setup(
		start_x,
		end_x,
		step_resolution,
		get_height_at,
		spawn_items,
		surface_color,
		surface_highlight,
		dirt_color,
		sub_dirt_color,
		level_num,
		accent_color,
		goal_world_x
	)

	active_chunks.append(chunk)
	highest_generated_x = maxf(highest_generated_x, end_x)
	_next_chunk_idx = maxi(_next_chunk_idx, chunk_idx + 1)

func _recycle_chunk(chunk: TerrainChunk) -> void:
	chunk.deactivate_for_pool()
	_chunk_pool.append(chunk)

func get_base_height_at(world_x: float) -> float:
	# Zona inicial plana (< 450px) para arranque seguro, fluido y sin saltos
	if world_x < 450.0:
		return 680.0

	var dist: float = world_x - 450.0
	var spawn_blend: float = clampf(dist / 250.0, 0.0, 1.0)
	var diff_factor: float = clampf(dist / 24000.0, 0.0, 1.0)
	var amp_scale: float = hill_scale * spawn_blend * (1.0 + diff_factor * 0.25)

	var wave_total: float = 0.0

	# 10 Topografías matemáticas únicas e inconfundibles para cada nivel (1 a 10)
	match level_num:
		1:
			# Nivel 1: Pradera Cyber-Solar — Colinas amplias y fluidas estilo Countryside, muy perdonadoras
			var wave1: float = sin(dist * 0.0008) * 55.0
			var wave2: float = sin(dist * 0.0020 + 0.8) * 20.0
			var wave3: float = sin(dist * 0.0045) * 6.0
			var jump_feature: float = 0.0
			var jump_cycle: float = fmod(dist, 2000.0)
			if jump_cycle > 1050.0 and jump_cycle < 1500.0:
				var jt: float = (jump_cycle - 1050.0) / 450.0
				jump_feature = -sin(jt * PI) * 45.0
			wave_total = (wave1 + wave2 + wave3 + jump_feature) * amp_scale

		2:
			# Nivel 2: Desierto Magma-Cristal — Dunas gigantescas con largas trepadas y bajadas pronunciadas
			var w1_amp: float = lerpf(70.0, 130.0, clampf(dist / 2500.0, 0.0, 1.0))
			var wave1: float = sin(dist * 0.0005) * w1_amp
			var wave2: float = sin(dist * 0.0016 + 1.2) * 45.0
			var wave3: float = sin(dist * 0.0040) * 10.0
			var jump_feature: float = 0.0
			if dist > 2500.0:
				var jump_cycle: float = fmod(dist, 2200.0)
				if jump_cycle > 1200.0 and jump_cycle < 1650.0:
					var jt: float = (jump_cycle - 1200.0) / 450.0
					jump_feature = -sin(jt * PI) * 55.0
			wave_total = (wave1 + wave2 + wave3 + jump_feature) * amp_scale

		3:
			# Nivel 3: Jungla Bioluminiscente — Relieve orgánico irregular con baches de raíces y esporas
			var wave1: float = sin(dist * 0.0012) * 75.0
			var wave2: float = sin(dist * 0.0032 + 1.5) * 35.0
			var wave3: float = sin(dist * 0.0060) * 12.0
			var root_bump: float = sin(dist * 0.012 + 0.6) * 5.0
			wave_total = (wave1 + wave2 + wave3 + root_bump) * amp_scale

		4:
			# Nivel 4: Glaciar Volcánico — Crestas glaciales escalonadas y aristas afiladas de hielo
			var s4: float = sin(dist * 0.0009)
			var ice_ridge: float = signf(s4) * pow(absf(s4), 0.72)
			var wave1: float = ice_ridge * 115.0
			var wave2: float = sin(dist * 0.0022 + 1.0) * 35.0
			var wave3: float = cos(dist * 0.0048) * 12.0
			wave_total = (wave1 + wave2 + wave3) * amp_scale

		5:
			# Nivel 5: Cañón Steampunk — Mesetas y altiplanos rectos tipo cañón con paredes abruptas
			var raw_canyon: float = sin(dist * 0.0007) * 160.0
			var wave1: float = clampf(raw_canyon, -85.0, 85.0)
			var wave2: float = sin(dist * 0.0022 + 0.6) * 28.0
			var wave3: float = sin(dist * 0.0052) * 8.0
			wave_total = (wave1 + wave2 + wave3) * amp_scale

		6:
			# Nivel 6: Pantano Tóxico — Llanuras fangosas bajas y planas con montículos radiactivos repentinos
			var wave1: float = sin(dist * 0.0006) * 40.0
			var wave2: float = sin(dist * 0.0025) * 30.0
			var sludge_cycle: float = fmod(dist, 1300.0)
			var sludge_mound: float = 0.0
			if sludge_cycle > 750.0 and sludge_cycle < 1150.0:
				var sm_t: float = (sludge_cycle - 750.0) / 400.0
				sludge_mound = -pow(sin(sm_t * PI), 1.5) * 60.0
			var wave3: float = sin(dist * 0.0055) * 7.0
			wave_total = (wave1 + wave2 + sludge_mound + wave3) * amp_scale

		7:
			# Nivel 7: Autopista Synthwave — Montaña rusa de alta velocidad con ondas fluidas y gran inercia
			var wave1: float = sin(dist * 0.0011) * 135.0
			var wave2: float = sin(dist * 0.0028) * 50.0
			var wave3: float = sin(dist * 0.0062 + 1.8) * 14.0
			var roll_cycle: float = fmod(dist, 1600.0)
			var roll_kicker: float = 0.0
			if roll_cycle > 900.0 and roll_cycle < 1350.0:
				var rk_t: float = (roll_cycle - 900.0) / 450.0
				roll_kicker = -sin(rk_t * PI) * 70.0
			wave_total = (wave1 + wave2 + wave3 + roll_kicker) * amp_scale

		8:
			# Nivel 8: Cumbre Caramelo — Colinas de joroba doble ("camel hills") con ritmo saltarín
			var wave1: float = absf(sin(dist * 0.0014)) * 95.0 - 45.0
			var wave2: float = sin(dist * 0.0030) * 25.0
			var wave3: float = sin(dist * 0.0065 + 0.7) * 9.0
			wave_total = (wave1 + wave2 + wave3) * amp_scale

		9:
			# Nivel 9: Ruinas Alien-Doradas — Terrazas escalonadas geométricas suavizadas
			var step_t: float = dist * 0.0008
			var raw_step: float = sin(step_t) * 4.0
			var fl: float = floorf(raw_step)
			var fr: float = raw_step - fl
			var smooth_terr: float = fl + smoothstep(0.68, 1.0, fr)
			var wave1: float = (smooth_terr / 4.0) * 120.0
			var wave2: float = sin(dist * 0.0022 + 1.0) * 25.0
			var wave3: float = sin(dist * 0.0048) * 8.0
			wave_total = (wave1 + wave2 + wave3) * amp_scale

		10:
			# Nivel 10: Nebulosa Lunar-Cósmica — Cuencas de cráteres lunares profundos y crestas de impacto
			var crater_cycle: float = fmod(dist, 2400.0)
			var crater_shape: float = 0.0
			if crater_cycle < 550.0:
				var t_rim1: float = crater_cycle / 550.0
				crater_shape = -sin(t_rim1 * PI * 0.5) * 45.0
			elif crater_cycle < 700.0:
				var t_crest: float = (crater_cycle - 550.0) / 150.0
				crater_shape = lerpf(-45.0, 10.0, t_crest)
			elif crater_cycle < 1750.0:
				var t_basin: float = (crater_cycle - 700.0) / 1050.0
				crater_shape = 10.0 + sin(t_basin * PI) * 115.0
			elif crater_cycle < 1900.0:
				var t_exit: float = (crater_cycle - 1750.0) / 150.0
				crater_shape = lerpf(10.0, -35.0, t_exit)
			elif crater_cycle < 2100.0:
				var t_rim2: float = (crater_cycle - 1900.0) / 200.0
				crater_shape = lerpf(-35.0, 0.0, t_rim2)
			else:
				crater_shape = 0.0

			var wave_lunar: float = sin(dist * 0.0007) * 55.0 + sin(dist * 0.0018 + 0.4) * 22.0
			wave_total = (crater_shape + wave_lunar) * amp_scale

		_:
			# Fallback para otros niveles
			var wave1: float = sin(dist * 0.0010) * 75.0
			var wave2: float = sin(dist * 0.0024 + 1.2) * 30.0
			wave_total = (wave1 + wave2) * amp_scale

	return 680.0 + wave_total

func get_height_at(world_x: float) -> float:
	var base_h: float = get_base_height_at(world_x)

	# Moldeado determinista de obstáculos especiales por chunk
	var c_idx: int = int(floor(world_x / chunk_width))
	var local_x: float = world_x - float(c_idx) * chunk_width
	var obs_type: int = TerrainChunk.get_chunk_obstacle_type(c_idx, level_num, goal_world_x)

	if obs_type == 1:
		# Obstáculo 1: Laguna de Agua Profunda (bancos nivelados en y = 650.0, fosa en 520..1320)
		if local_x >= 400.0 and local_x < 520.0:
			var tb_in: float = smoothstep(400.0, 520.0, local_x)
			return lerpf(base_h, 650.0, tb_in)
		elif local_x >= 520.0 and local_x <= 1320.0:
			var t_w: float = (local_x - 520.0) / 800.0
			return 650.0 + sin(t_w * PI) * (135.0 + float(level_num) * 4.0)
		elif local_x > 1320.0 and local_x <= 1460.0:
			var tb_out: float = smoothstep(1320.0, 1460.0, local_x)
			return lerpf(650.0, base_h, tb_out)

	elif obs_type == 2 or obs_type == 3:
		# Obstáculo 2 y 3: Rampa de Lanzamiento + Precipicio Mortal (+ Tronco Rodante en tipo 3)
		var gap_end: float = 950.0 + float(level_num - 1) * 8.0

		# Referencia de altura de aproximación suave y adaptada a la topografía del chunk
		var chunk_start_x: float = float(c_idx) * chunk_width
		var ref_h: float = get_base_height_at(chunk_start_x + 280.0)
		var target_runup_y: float = clampf(ref_h, 640.0, 720.0)
		var launch_top: float = target_runup_y - 125.0

		# 1. Terreno ondulante natural previo a la aproximación
		if local_x < 120.0:
			return base_h

		# 2. Transición ultra-suave y progresiva (120..420, 300px) que elimina cualquier pared abrupta
		elif local_x >= 120.0 and local_x < 420.0:
			var t_in: float = smoothstep(120.0, 420.0, local_x)
			return lerpf(base_h, target_runup_y, t_in)

		# 3. Recta de aproximación limpia y plana (420..500): sin baches para asegurar máxima velocidad
		elif local_x >= 420.0 and local_x < 500.0:
			return target_runup_y

		# 4. Rampa de Lanzamiento HACIA ARRIBA (500..760, ancho 260px, asciende de target_runup_y a launch_top)
		elif local_x >= 500.0 and local_x <= 760.0:
			var tr: float = (local_x - 500.0) / 260.0
			if obs_type == 3:
				# Rampa con cuna suave para el tronco rodante (690..760) reposando en local_x=725
				if local_x < 690.0:
					return target_runup_y - sin(tr * PI * 0.5) * 125.0
				else:
					var tc3: float = (local_x - 690.0) / 70.0
					return launch_top + 10.0 + sin(tc3 * PI) * 1.5
			return target_runup_y - pow(tr, 1.25) * 125.0

		# 5. Caída vertical al Precipicio Mortal (760..785)
		elif local_x > 760.0 and local_x < 785.0:
			var td: float = (local_x - 760.0) / 25.0
			var launch_lip_y: float = (launch_top + 10.0) if obs_type == 3 else launch_top
			return lerpf(launch_lip_y, 1250.0, td)

		# 6. Fondo del precipicio abismal (785..gap_end - 25.0)
		elif local_x >= 785.0 and local_x <= gap_end - 25.0:
			return 1250.0

		# 7. Ascenso hacia el labio de recepción (gap_end - 25.0..gap_end, 30px debajo del despegue)
		elif local_x > gap_end - 25.0 and local_x <= gap_end:
			var tu: float = (local_x - (gap_end - 25.0)) / 25.0
			return lerpf(1250.0, target_runup_y - 95.0, tu)

		# 8. RAMPA DE RECEPCIÓN DOWNHILL ("RECIBIR HACIA ABAJO") (gap_end..gap_end + 360.0)
		# Desciende suavemente de target_runup_y - 95.0 a target_runup_y + 20.0 amortiguando la caída y acelerando el vehículo hacia adelante
		elif local_x > gap_end and local_x <= gap_end + 360.0:
			var t_land: float = (local_x - gap_end) / 360.0
			return (target_runup_y - 95.0) + sin(t_land * PI * 0.5) * 115.0

		# 9. Transición de salida suave hacia la topografía natural (gap_end + 360.0..gap_end + 520.0, 160px)
		elif local_x > gap_end + 360.0 and local_x <= gap_end + 520.0:
			var t_exit: float = smoothstep(gap_end + 360.0, gap_end + 520.0, local_x)
			return lerpf(target_runup_y + 20.0, base_h, t_exit)

	return base_h


