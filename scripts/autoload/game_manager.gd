extends Node

# GameManager - Autoload Singleton
# Gestiona el estado global del juego, monedas, mejoras, vehículos y guardado persistente.

signal coins_changed(new_coins: int)
signal rubies_changed(new_rubies: int)
signal distance_updated(distance_m: float)
signal game_over_triggered(reason: String)
signal upgrades_updated
signal vehicle_changed(vehicle_id: String)
signal route_changed(route_id: String)
signal level_completed(level_num: int, unlocked_route_id: String, reward_coins: int)

const SAVE_PATH := "user://savegame.json"

var total_coins: int = 150
var total_rubies: int = 0
var high_score_distance: float = 0.0

# Estadísticas de la partida actual
var current_coins: int = 0
var current_distance: float = 0.0
var current_fuel: float = 100.0
var current_boost: float = 100.0
var is_game_active: bool = false
var level_completed_in_run: bool = false
var last_unlocked_route_id: String = ""
var last_level_reward: int = 0

# Niveles de mejoras (1 a 5)
var upgrades := {
	"engine": 1,
	"suspension": 1,
	"tires": 1,
	"thruster": 1
}

const UPGRADE_COSTS := {
	"engine": [0, 80, 200, 500, 1200, 2500],
	"suspension": [0, 60, 160, 400, 1000, 2000],
	"tires": [0, 70, 180, 450, 1100, 2200],
	"thruster": [0, 100, 250, 600, 1500, 3000]
}

const UPGRADE_NAMES := {
	"engine": "Motor Toro-V8",
	"suspension": "Amortiguación Hidráulica",
	"tires": "Neumáticos Oruga 4x4",
	"thruster": "Tanque de Combustible"
}

# ── Sistema de Vehículos (11 Vehículos) ───────────────────────────
const VEHICLE_CATALOG := {
	"toro_rojo": {
		"name": "Toro 4x4",
		"price": 0,
		"body_texture": "res://assets/sprites/veh_4x4.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Todoterreno 4x4 clásico. Equilibrado, resistente y listo para cualquier colina.",
		"color": Color(0.90, 0.20, 0.15),
		"rear_wheel_x": -70.0,
		"front_wheel_x": 70.0,
		"rear_wheel_scale": 0.90,
		"front_wheel_scale": 0.90,
		"driver_pos": Vector2(10, -28),
		"motor_mult": 1.00,
		"susp_mult": 1.00,
	},
	"scuter": {
		"name": "Scooter Urbana",
		"price": 800,
		"body_texture": "res://assets/sprites/veh_scooter.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Ligera y muy ágil en el aire para hacer giros y acrobacias rápidas.",
		"color": Color(0.15, 0.78, 0.72),
		"rear_wheel_x": -55.0,
		"front_wheel_x": 58.0,
		"rear_wheel_scale": 0.68,
		"front_wheel_scale": 0.68,
		"driver_pos": Vector2(-15, -34),
		"motor_mult": 0.92,
		"susp_mult": 0.95,
	},
	"moto": {
		"name": "Moto Cross X",
		"price": 1800,
		"body_texture": "res://assets/sprites/veh_moto.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Motocicleta de enduro con gran arranque y suspensión de largo recorrido.",
		"color": Color(0.96, 0.45, 0.08),
		"rear_wheel_x": -62.0,
		"front_wheel_x": 65.0,
		"rear_wheel_scale": 0.82,
		"front_wheel_scale": 0.82,
		"driver_pos": Vector2(-10, -36),
		"motor_mult": 1.15,
		"susp_mult": 1.10,
	},
	"tractor": {
		"name": "Tractor Agrícola",
		"price": 3200,
		"body_texture": "res://assets/sprites/veh_tractor.png",
		"wheel_texture": "res://assets/sprites/wheel_monster.png",
		"description": "Enorme rueda trasera con torque brutal para trepar cualquier subida.",
		"color": Color(0.20, 0.72, 0.22),
		"rear_wheel_x": -65.0,
		"front_wheel_x": 72.0,
		"rear_wheel_scale": 1.28,
		"front_wheel_scale": 0.76,
		"driver_pos": Vector2(-35, -42),
		"motor_mult": 1.18,
		"susp_mult": 1.08,
	},
	"policia": {
		"name": "Auto de Policía",
		"price": 5000,
		"body_texture": "res://assets/sprites/veh_police.png",
		"wheel_texture": "res://assets/sprites/wheel_sport.png",
		"description": "Patrulla interceptora con motor modificado, sirenas y defensa frontal.",
		"color": Color(0.20, 0.45, 0.95),
		"rear_wheel_x": -72.0,
		"front_wheel_x": 72.0,
		"rear_wheel_scale": 0.88,
		"front_wheel_scale": 0.88,
		"driver_pos": Vector2(12, -28),
		"motor_mult": 1.22,
		"susp_mult": 1.06,
	},
	"camion_basura": {
		"name": "Camión de Basura",
		"price": 7600,
		"body_texture": "res://assets/sprites/veh_garbage.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Pesado y estable con gran tracción trasera y chasis reforzado.",
		"color": Color(0.16, 0.62, 0.28),
		"rear_wheel_x": -75.0,
		"front_wheel_x": 78.0,
		"rear_wheel_scale": 0.96,
		"front_wheel_scale": 0.96,
		"driver_pos": Vector2(75, -26),
		"motor_mult": 1.20,
		"susp_mult": 1.14,
	},
	"autobus": {
		"name": "Autobús Escolar",
		"price": 10400,
		"body_texture": "res://assets/sprites/veh_bus.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Largo y súper estable en colinas, difícil de volcar en terrenos largos.",
		"color": Color(0.96, 0.74, 0.08),
		"rear_wheel_x": -82.0,
		"front_wheel_x": 82.0,
		"rear_wheel_scale": 0.92,
		"front_wheel_scale": 0.92,
		"driver_pos": Vector2(62, -26),
		"motor_mult": 1.24,
		"susp_mult": 1.14,
	},
	"bomberos": {
		"name": "Camión de Bomberos",
		"price": 13600,
		"body_texture": "res://assets/sprites/veh_firetruck.png",
		"wheel_texture": "res://assets/sprites/wheel.png",
		"description": "Unidad de rescate con motor diésel turboalimentado y gran suspensión.",
		"color": Color(0.88, 0.14, 0.14),
		"rear_wheel_x": -78.0,
		"front_wheel_x": 78.0,
		"rear_wheel_scale": 0.98,
		"front_wheel_scale": 0.98,
		"driver_pos": Vector2(75, -28),
		"motor_mult": 1.30,
		"susp_mult": 1.16,
	},
	"carro_velocidad": {
		"name": "Carro de Velocidad",
		"price": 17000,
		"body_texture": "res://assets/sprites/veh_speedcar.png",
		"wheel_texture": "res://assets/sprites/wheel_sport.png",
		"description": "Superdeportivo aerodinámico con alerón de competición. ¡Velocidad extrema!",
		"color": Color(0.05, 0.65, 0.98),
		"rear_wheel_x": -72.0,
		"front_wheel_x": 74.0,
		"rear_wheel_scale": 0.86,
		"front_wheel_scale": 0.86,
		"driver_pos": Vector2(15, -22),
		"motor_mult": 1.45,
		"susp_mult": 1.12,
	},
	"camion_monstruo": {
		"name": "Camión Monstruo",
		"price": 22000,
		"body_texture": "res://assets/sprites/veh_monster.png",
		"wheel_texture": "res://assets/sprites/wheel_monster.png",
		"description": "Llantas gigantes y amortiguadores extremos que aplastan cualquier bache.",
		"color": Color(0.55, 0.15, 0.85),
		"rear_wheel_x": -72.0,
		"front_wheel_x": 72.0,
		"rear_wheel_scale": 1.34,
		"front_wheel_scale": 1.34,
		"driver_pos": Vector2(15, -38),
		"motor_mult": 1.40,
		"susp_mult": 1.30,
	},
	"banana_movil": {
		"name": "Banana con Ruedas",
		"price": 30000,
		"body_texture": "res://assets/sprites/veh_banana.png",
		"wheel_texture": "res://assets/sprites/wheel_sport.png",
		"description": "¡El vehículo definitivo lleno de potasio! Súper rápido, ágil y divertido.",
		"color": Color(1.00, 0.88, 0.12),
		"rear_wheel_x": -68.0,
		"front_wheel_x": 68.0,
		"rear_wheel_scale": 0.88,
		"front_wheel_scale": 0.88,
		"driver_pos": Vector2(-5, -28),
		"motor_mult": 1.52,
		"susp_mult": 1.25,
	},
}

const VEHICLE_ORDER: Array[String] = [
	"toro_rojo", "scuter", "moto", "tractor", "policia",
	"camion_basura", "autobus", "bomberos", "carro_velocidad",
	"camion_monstruo", "banana_movil"
]

var owned_vehicles: Array = ["toro_rojo"]
var selected_vehicle: String = "toro_rojo"

# ── Sistema de 10 Niveles Progresivos con Temáticas Fusionadas ────
const ROUTE_ORDER: Array[String] = [
	"nivel_1", "nivel_2", "nivel_3", "nivel_4", "nivel_5",
	"nivel_6", "nivel_7", "nivel_8", "nivel_9", "nivel_10"
]

const ROUTE_CATALOG := {
	"nivel_1": {
		"level_num": 1,
		"name": "Nivel 1: Pradera Cyber-Solar",
		"short_name": "Pradera Cyber-Solar",
		"icon": "🌿⚡",
		"theme_fusion": "Bosque Esmeralda × Tecnología Solar Neón",
		"goal_distance": 350.0,
		"reward_coins": 250,
		"price": 0,
		"description": "Colinas orgánicas fusionadas con cristales solares cian. ¡Llega a 350 m para desbloquear el Nivel 2!",
		"gravity_scale": 1.0,
		"grip_mult": 1.0,
		"hill_scale": 0.90,
		"sky_color": Color(0.09, 0.19, 0.34),
		"sky_top": Color(0.06, 0.14, 0.28),
		"sky_bottom": Color(0.18, 0.46, 0.58),
		"surface_color": Color(0.18, 0.78, 0.42),
		"surface_highlight": Color(0.25, 0.98, 0.78),
		"dirt_color": Color(0.22, 0.15, 0.12),
		"sub_dirt_color": Color(0.12, 0.09, 0.14),
		"dust_color": Color(0.42, 0.85, 0.65, 0.82),
		"accent_color": Color(0.18, 0.95, 0.82),
	},
	"nivel_2": {
		"level_num": 2,
		"name": "Nivel 2: Desierto Magma-Cristal",
		"short_name": "Desierto Magma-Cristal",
		"icon": "🏜️🌋",
		"theme_fusion": "Dunas Egipcias × Ríos de Lava y Cuarzo",
		"goal_distance": 450.0,
		"reward_coins": 350,
		"price": 0,
		"description": "Dunas doradas atravesadas por vetas de magma incandescente y cristales rojos.",
		"gravity_scale": 1.0,
		"grip_mult": 0.92,
		"hill_scale": 1.02,
		"sky_color": Color(0.28, 0.11, 0.07),
		"sky_top": Color(0.18, 0.06, 0.05),
		"sky_bottom": Color(0.62, 0.24, 0.10),
		"surface_color": Color(0.92, 0.58, 0.18),
		"surface_highlight": Color(1.00, 0.82, 0.28),
		"dirt_color": Color(0.46, 0.16, 0.09),
		"sub_dirt_color": Color(0.26, 0.07, 0.05),
		"dust_color": Color(0.95, 0.52, 0.20, 0.85),
		"accent_color": Color(1.00, 0.38, 0.12),
	},
	"nivel_3": {
		"level_num": 3,
		"name": "Nivel 3: Jungla Bioluminiscente",
		"short_name": "Jungla Bioluminiscente",
		"icon": "🌴🔮",
		"theme_fusion": "Selva Amazónica × Hongos Neón Nocturnos",
		"goal_distance": 550.0,
		"reward_coins": 500,
		"price": 0,
		"description": "Terreno selvático húmedo iluminado por esporas fluorescentes violetas y turquesas.",
		"gravity_scale": 0.96,
		"grip_mult": 0.94,
		"hill_scale": 1.06,
		"sky_color": Color(0.07, 0.05, 0.22),
		"sky_top": Color(0.04, 0.03, 0.15),
		"sky_bottom": Color(0.16, 0.10, 0.38),
		"surface_color": Color(0.12, 0.76, 0.68),
		"surface_highlight": Color(0.75, 0.32, 1.00),
		"dirt_color": Color(0.15, 0.10, 0.26),
		"sub_dirt_color": Color(0.08, 0.05, 0.16),
		"dust_color": Color(0.58, 0.35, 0.98, 0.85),
		"accent_color": Color(0.82, 0.32, 1.00),
	},
	"nivel_4": {
		"level_num": 4,
		"name": "Nivel 4: Glaciar Volcánico",
		"short_name": "Glaciar Volcánico",
		"icon": "❄️🔥",
		"theme_fusion": "Hielo Ártico × Géiseres de Fuego Termal",
		"goal_distance": 650.0,
		"reward_coins": 650,
		"price": 0,
		"description": "Pistas de hielo resbaladizo sobre roca volcánica ardiente. ¡Controla el patinaje!",
		"gravity_scale": 1.0,
		"grip_mult": 0.78,
		"hill_scale": 1.10,
		"sky_color": Color(0.08, 0.18, 0.30),
		"sky_top": Color(0.05, 0.12, 0.24),
		"sky_bottom": Color(0.38, 0.22, 0.28),
		"surface_color": Color(0.76, 0.92, 1.00),
		"surface_highlight": Color(1.00, 0.48, 0.22),
		"dirt_color": Color(0.26, 0.20, 0.28),
		"sub_dirt_color": Color(0.18, 0.10, 0.14),
		"dust_color": Color(0.82, 0.94, 1.00, 0.88),
		"accent_color": Color(0.35, 0.88, 1.00),
	},
	"nivel_5": {
		"level_num": 5,
		"name": "Nivel 5: Cañón Steampunk-Chatarra",
		"short_name": "Cañón Steampunk",
		"icon": "⚙️🏜️",
		"theme_fusion": "Cañón Oxidado × Maquinaria de Vapor y Bronce",
		"goal_distance": 750.0,
		"reward_coins": 800,
		"price": 0,
		"description": "Lomas de cobre y acero remachado con excelente agarre mecánico y saltos industriales.",
		"gravity_scale": 1.02,
		"grip_mult": 1.04,
		"hill_scale": 1.15,
		"sky_color": Color(0.22, 0.16, 0.12),
		"sky_top": Color(0.14, 0.10, 0.08),
		"sky_bottom": Color(0.45, 0.32, 0.20),
		"surface_color": Color(0.78, 0.48, 0.22),
		"surface_highlight": Color(0.96, 0.76, 0.38),
		"dirt_color": Color(0.30, 0.22, 0.18),
		"sub_dirt_color": Color(0.18, 0.13, 0.11),
		"dust_color": Color(0.72, 0.56, 0.42, 0.86),
		"accent_color": Color(0.95, 0.68, 0.25),
	},
	"nivel_6": {
		"level_num": 6,
		"name": "Nivel 6: Pantano Tóxico-Mutante",
		"short_name": "Pantano Tóxico",
		"icon": "🧪🐊",
		"theme_fusion": "Ciénaga Oscura × Laboratorio Químico Neón",
		"goal_distance": 900.0,
		"reward_coins": 1000,
		"price": 0,
		"description": "Lodo radiactivo verde ácido con burbujas químicas y colinas ondulantes.",
		"gravity_scale": 0.94,
		"grip_mult": 0.85,
		"hill_scale": 1.18,
		"sky_color": Color(0.06, 0.16, 0.10),
		"sky_top": Color(0.04, 0.10, 0.07),
		"sky_bottom": Color(0.16, 0.36, 0.18),
		"surface_color": Color(0.48, 0.96, 0.14),
		"surface_highlight": Color(0.82, 1.00, 0.28),
		"dirt_color": Color(0.18, 0.24, 0.14),
		"sub_dirt_color": Color(0.10, 0.13, 0.08),
		"dust_color": Color(0.56, 0.98, 0.22, 0.85),
		"accent_color": Color(0.55, 1.00, 0.18),
	},
	"nivel_7": {
		"level_num": 7,
		"name": "Nivel 7: Autopista Synthwave-84",
		"short_name": "Autopista Synthwave",
		"icon": "🌆🕶️",
		"theme_fusion": "Ciudad Ciberpunk × Rejilla Láser Retro-Futurista",
		"goal_distance": 1050.0,
		"reward_coins": 1250,
		"price": 0,
		"description": "Ondas de neón magenta y cian bajo un atardecer sintético de alta velocidad.",
		"gravity_scale": 0.92,
		"grip_mult": 1.06,
		"hill_scale": 1.22,
		"sky_color": Color(0.14, 0.04, 0.26),
		"sky_top": Color(0.08, 0.02, 0.18),
		"sky_bottom": Color(0.52, 0.10, 0.44),
		"surface_color": Color(0.98, 0.16, 0.68),
		"surface_highlight": Color(0.15, 0.96, 1.00),
		"dirt_color": Color(0.18, 0.06, 0.30),
		"sub_dirt_color": Color(0.09, 0.03, 0.18),
		"dust_color": Color(0.98, 0.28, 0.82, 0.85),
		"accent_color": Color(1.00, 0.22, 0.76),
	},
	"nivel_8": {
		"level_num": 8,
		"name": "Nivel 8: Cumbre Caramelo-Helado",
		"short_name": "Cumbre Caramelo",
		"icon": "🍭❄️",
		"theme_fusion": "Reino de Dulces × Avalancha de Nieve Algodón",
		"goal_distance": 1200.0,
		"reward_coins": 1500,
		"price": 0,
		"description": "Colinas de glaseado rosa y chocolate con nieve resbaladiza de azúcar glas.",
		"gravity_scale": 0.90,
		"grip_mult": 0.82,
		"hill_scale": 1.24,
		"sky_color": Color(0.24, 0.14, 0.28),
		"sky_top": Color(0.18, 0.10, 0.24),
		"sky_bottom": Color(0.54, 0.32, 0.48),
		"surface_color": Color(1.00, 0.54, 0.78),
		"surface_highlight": Color(0.96, 0.96, 1.00),
		"dirt_color": Color(0.38, 0.20, 0.16),
		"sub_dirt_color": Color(0.24, 0.12, 0.10),
		"dust_color": Color(1.00, 0.76, 0.90, 0.88),
		"accent_color": Color(1.00, 0.48, 0.76),
	},
	"nivel_9": {
		"level_num": 9,
		"name": "Nivel 9: Ruinas Alien-Doradas",
		"short_name": "Ruinas Alien-Doradas",
		"icon": "🛸🏛️",
		"theme_fusion": "Templo Dorado Ancestral × Gravedad Antigravitatoria Alien",
		"goal_distance": 1400.0,
		"reward_coins": 1800,
		"price": 0,
		"description": "Monolitos de oro puro con anomalías gravitatorias (0.68G) que potencian grandes saltos.",
		"gravity_scale": 0.68,
		"grip_mult": 0.92,
		"hill_scale": 1.28,
		"sky_color": Color(0.05, 0.16, 0.18),
		"sky_top": Color(0.03, 0.10, 0.14),
		"sky_bottom": Color(0.16, 0.42, 0.36),
		"surface_color": Color(0.96, 0.78, 0.22),
		"surface_highlight": Color(0.32, 1.00, 0.78),
		"dirt_color": Color(0.28, 0.24, 0.14),
		"sub_dirt_color": Color(0.16, 0.14, 0.08),
		"dust_color": Color(0.98, 0.84, 0.36, 0.86),
		"accent_color": Color(0.98, 0.82, 0.24),
	},
	"nivel_10": {
		"level_num": 10,
		"name": "Nivel 10: Nebulosa Lunar-Cósmica",
		"short_name": "Nebulosa Lunar-Cósmica",
		"icon": "🌙🌌",
		"theme_fusion": "Cráteres Lunares × Dimensión Astral de Baja Gravedad",
		"goal_distance": 1600.0,
		"reward_coins": 2500,
		"price": 0,
		"description": "¡El desafío final! Gravedad espacial (0.60G), cráteres gigantes y energía cósmica.",
		"gravity_scale": 0.60,
		"grip_mult": 0.88,
		"hill_scale": 1.34,
		"sky_color": Color(0.03, 0.03, 0.09),
		"sky_top": Color(0.02, 0.02, 0.06),
		"sky_bottom": Color(0.18, 0.08, 0.32),
		"surface_color": Color(0.68, 0.72, 0.86),
		"surface_highlight": Color(0.58, 0.38, 1.00),
		"dirt_color": Color(0.26, 0.26, 0.38),
		"sub_dirt_color": Color(0.14, 0.14, 0.24),
		"dust_color": Color(0.76, 0.78, 0.96, 0.88),
		"accent_color": Color(0.66, 0.48, 1.00),
	},
}

var unlocked_level: int = 1
var owned_routes: Array = ["nivel_1"]
var selected_route: String = "nivel_1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	_sync_owned_routes_with_unlocked_level()
	save_game()

func _sync_owned_routes_with_unlocked_level() -> void:
	unlocked_level = clampi(unlocked_level, 1, ROUTE_ORDER.size())
	for i in range(unlocked_level):
		var rid: String = ROUTE_ORDER[i]
		if not (rid in owned_routes):
			owned_routes.append(rid)
	if not (selected_route in ROUTE_CATALOG) or not is_route_owned(selected_route):
		selected_route = ROUTE_ORDER[clampi(unlocked_level - 1, 0, ROUTE_ORDER.size() - 1)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func start_new_run() -> void:
	current_coins = 0
	current_distance = 0.0
	current_fuel = 100.0 * get_fuel_capacity_factor()
	current_boost = 100.0
	is_game_active = true
	level_completed_in_run = false
	last_unlocked_route_id = ""
	last_level_reward = 0
	save_game()

func add_coins(amount: int) -> void:
	current_coins += amount
	total_coins += amount
	coins_changed.emit(total_coins)
	save_game()
	
	# Pitch del efecto de sonido según el valor de la moneda
	var pitch: float = 1.0
	if amount >= 100:
		pitch = 1.45
	elif amount >= 50:
		pitch = 1.30
	elif amount >= 20:
		pitch = 1.15
	SoundManager.play_sfx("coin", pitch)

func add_rubies(amount: int = 1) -> void:
	total_rubies += amount
	rubies_changed.emit(total_rubies)
	SoundManager.play_sfx("ruby", 1.2)
	save_game()

func add_fuel(amount: float = 100.0) -> void:
	var max_fuel: float = 100.0 * get_fuel_capacity_factor()
	current_fuel = min(max_fuel, current_fuel + amount)
	SoundManager.play_sfx("fuel")

func update_distance(x_position: float, start_x: float) -> void:
	if not is_game_active:
		return
	var dist: float = max(0.0, (x_position - start_x) / 60.0)
	if dist > current_distance:
		current_distance = dist
		distance_updated.emit(current_distance)
		if current_distance > high_score_distance:
			high_score_distance = current_distance
		var goal_dist: float = get_level_goal_distance()
		if not level_completed_in_run and current_distance >= goal_dist:
			complete_current_level()

func complete_current_level() -> void:
	if level_completed_in_run:
		return
	level_completed_in_run = true
	var rdata: Dictionary = get_selected_route_data()
	var lvl_num: int = int(rdata.get("level_num", 1))
	var reward: int = int(rdata.get("reward_coins", 250))
	last_level_reward = reward
	current_coins += reward
	total_coins += reward
	coins_changed.emit(total_coins)

	var newly_unlocked_id: String = ""
	if lvl_num >= unlocked_level and lvl_num < ROUTE_ORDER.size():
		unlocked_level = lvl_num + 1
		newly_unlocked_id = ROUTE_ORDER[unlocked_level - 1]
		if not (newly_unlocked_id in owned_routes):
			owned_routes.append(newly_unlocked_id)
		last_unlocked_route_id = newly_unlocked_id

	SoundManager.play_sfx("coin", 1.5)
	save_game()
	level_completed.emit(lvl_num, newly_unlocked_id, reward)
	trigger_game_over("🏆 ¡NIVEL %d SUPERADO! (+%d 🪙)" % [lvl_num, reward])

func advance_to_next_level() -> bool:
	var rdata: Dictionary = get_selected_route_data()
	var lvl_num: int = int(rdata.get("level_num", 1))
	if lvl_num < ROUTE_ORDER.size():
		var next_id: String = ROUTE_ORDER[lvl_num]
		if is_route_owned(next_id):
			select_route(next_id)
			return true
	return false

func trigger_game_over(reason: String) -> void:
	if not is_game_active:
		return
	is_game_active = false
	if current_distance > high_score_distance:
		high_score_distance = current_distance
	save_game()
	game_over_triggered.emit(reason)

# Retorna multiplicadores de mejora controlados y progresivos
func get_engine_torque_factor() -> float:
	var lvl: int = int(upgrades.get("engine", 1))
	return 1.0 + (lvl - 1) * 0.07 # +7% por nivel (de 1.0x a 1.28x)

func get_suspension_stiffness_factor() -> float:
	var lvl: int = int(upgrades.get("suspension", 1))
	return 1.0 + (lvl - 1) * 0.03 # +3% por nivel (soporte firme sin rebotar, de 1.0x a 1.12x)

func get_suspension_damping_factor() -> float:
	var lvl: int = int(upgrades.get("suspension", 1))
	return 1.0 + (lvl - 1) * 0.10 # +10% absorción hidráulica por nivel (de 1.0x a 1.40x)

func get_suspension_factor() -> float:
	return get_suspension_damping_factor()

func get_tire_grip_factor() -> float:
	var lvl: int = int(upgrades.get("tires", 1))
	return 1.0 + (lvl - 1) * 0.08 # +8% adherencia en pendientes (de 1.0x a 1.32x)

func get_fuel_capacity_factor() -> float:
	var lvl: int = int(upgrades.get("thruster", 1))
	return 1.0 + (lvl - 1) * 0.15 # +15% de capacidad de gasolina por nivel (de 1.0x a 1.60x)

func get_thruster_power_factor() -> float:
	return 1.0

func get_thruster_efficiency_factor() -> float:
	return 1.0

func can_upgrade(category: String) -> bool:
	var current_lvl: int = int(upgrades.get(category, 1))
	if current_lvl >= 5:
		return false
	var cost: int = UPGRADE_COSTS[category][current_lvl + 1]
	return total_coins >= cost

func buy_upgrade(category: String) -> bool:
	if not can_upgrade(category):
		return false
	var current_lvl: int = int(upgrades.get(category, 1))
	var cost: int = UPGRADE_COSTS[category][current_lvl + 1]
	total_coins -= cost
	upgrades[category] = current_lvl + 1
	coins_changed.emit(total_coins)
	upgrades_updated.emit()
	SoundManager.play_sfx("fuel")
	save_game()
	return true

func get_next_upgrade_cost(category: String) -> int:
	var current_lvl: int = int(upgrades.get(category, 1))
	if current_lvl >= 5:
		return -1
	return UPGRADE_COSTS[category][current_lvl + 1]

# ── Sistema de Vehículos ──────────────────────────────────────────
func get_vehicle_data(vehicle_id: String) -> Dictionary:
	return VEHICLE_CATALOG.get(vehicle_id, {})

func is_vehicle_owned(vehicle_id: String) -> bool:
	return vehicle_id in owned_vehicles

func can_buy_vehicle(vehicle_id: String) -> bool:
	if is_vehicle_owned(vehicle_id):
		return false
	var data: Dictionary = get_vehicle_data(vehicle_id)
	if data.is_empty():
		return false
	return total_coins >= int(data.get("price", 999999))

func buy_vehicle(vehicle_id: String) -> bool:
	if not can_buy_vehicle(vehicle_id):
		return false
	var data: Dictionary = get_vehicle_data(vehicle_id)
	total_coins -= int(data["price"])
	owned_vehicles.append(vehicle_id)
	coins_changed.emit(total_coins)
	SoundManager.play_sfx("fuel")
	save_game()
	return true

func select_vehicle(vehicle_id: String) -> void:
	if not is_vehicle_owned(vehicle_id):
		return
	selected_vehicle = vehicle_id
	vehicle_changed.emit(vehicle_id)
	save_game()

func get_selected_vehicle_data() -> Dictionary:
	return get_vehicle_data(selected_vehicle)

# ── Sistema de Niveles / Mapas Progresivos ────────────────────────
func get_route_data(route_id: String) -> Dictionary:
	return ROUTE_CATALOG.get(route_id, ROUTE_CATALOG["nivel_1"])

func get_route_level_num(route_id: String) -> int:
	var data: Dictionary = get_route_data(route_id)
	return int(data.get("level_num", 1))

func is_route_owned(route_id: String) -> bool:
	var lvl_num: int = get_route_level_num(route_id)
	return (route_id in owned_routes) or (lvl_num <= unlocked_level)

func can_buy_route(_route_id: String) -> bool:
	return false

func buy_route(_route_id: String) -> bool:
	return false

func select_route(route_id: String) -> void:
	if not is_route_owned(route_id):
		return
	selected_route = route_id
	route_changed.emit(route_id)
	save_game()

func get_selected_route_data() -> Dictionary:
	return get_route_data(selected_route)

func get_level_goal_distance(route_id: String = "") -> float:
	var target_id: String = route_id if not route_id.is_empty() else selected_route
	var data: Dictionary = get_route_data(target_id)
	return float(data.get("goal_distance", 350.0))

func get_level_progress_ratio() -> float:
	var goal: float = max(1.0, get_level_goal_distance())
	return clamp(current_distance / goal, 0.0, 1.0)

# ── Persistencia en user:// ───────────────────────────────────────
func save_game() -> void:
	var data := {
		"total_coins": total_coins,
		"total_rubies": total_rubies,
		"high_score_distance": high_score_distance,
		"upgrades": upgrades,
		"owned_vehicles": owned_vehicles,
		"selected_vehicle": selected_vehicle,
		"unlocked_level": unlocked_level,
		"owned_routes": owned_routes,
		"selected_route": selected_route,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_str: String = file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			var pdict: Dictionary = parsed as Dictionary
			total_coins = int(pdict.get("total_coins", 150))
			total_rubies = int(pdict.get("total_rubies", 0))
			high_score_distance = float(pdict.get("high_score_distance", 0.0))
			if pdict.has("upgrades") and pdict["upgrades"] is Dictionary:
				for k in upgrades.keys():
					if pdict["upgrades"].has(k):
						upgrades[k] = int(pdict["upgrades"][k])
			# Cargar vehículos
			if pdict.has("owned_vehicles") and pdict["owned_vehicles"] is Array:
				owned_vehicles = []
				for v in pdict["owned_vehicles"]:
					if v is String and v in VEHICLE_CATALOG:
						owned_vehicles.append(v)
				if owned_vehicles.is_empty():
					owned_vehicles = ["toro_rojo"]
			if pdict.has("selected_vehicle") and parsed["selected_vehicle"] is String:
				if pdict["selected_vehicle"] in owned_vehicles:
					selected_vehicle = str(pdict["selected_vehicle"])
				else:
					selected_vehicle = str(owned_vehicles[0])
			# Cargar nivel desbloqueado y rutas
			unlocked_level = clampi(int(pdict.get("unlocked_level", 1)), 1, ROUTE_ORDER.size())
			owned_routes = []
			if pdict.has("owned_routes") and pdict["owned_routes"] is Array:
				for r in pdict["owned_routes"]:
					if r is String and r in ROUTE_CATALOG:
						owned_routes.append(r)
			_sync_owned_routes_with_unlocked_level()
			if pdict.has("selected_route") and pdict["selected_route"] is String:
				var sel_r: String = str(pdict["selected_route"])
				if sel_r in ROUTE_CATALOG and is_route_owned(sel_r):
					selected_route = sel_r
				else:
					selected_route = ROUTE_ORDER[clampi(unlocked_level - 1, 0, ROUTE_ORDER.size() - 1)]
