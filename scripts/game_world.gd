extends Node2D

## Mundo del juego — renderiza el mapa, gestiona acertijos y victoria.

signal player_won

const TILE_SIZE := 48

# 0=suelo, 1=muro, 2=puerta, 3=meta
var game_map: Array = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,0,1],
	[1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
	[1,0,1,0,0,0,1,0,2,0,0,0,1,0,1],
	[1,0,1,1,1,1,1,0,1,1,1,0,1,0,1],
	[1,0,0,0,0,0,2,0,0,0,1,0,1,0,1],
	[1,1,1,1,1,0,1,1,1,0,1,0,1,0,1],
	[1,0,0,0,1,0,0,0,1,0,2,0,0,0,1],
	[1,0,1,0,1,1,1,0,1,0,1,1,1,1,1],
	[1,0,1,0,0,0,0,0,1,0,0,0,0,3,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]

var map_rows: int
var map_cols: int
var cam_offset: Vector2

# Colores del mapa
var col_floor := Color(0.12, 0.15, 0.20)
var col_wall := Color(0.22, 0.24, 0.31)
var col_wall_inner := Color(0.18, 0.20, 0.27)
var col_door := Color(0.71, 0.47, 0.16)
var col_door_glow := Color(0.86, 0.67, 0.24)
var col_exit := Color(0.25, 0.73, 0.31)
var col_exit_glow := Color(0.39, 0.86, 0.47)
var col_grid := Color(0.10, 0.13, 0.16)

# Acertijos
var riddles: Array = [
	{"pregunta": "Tengo ciudades, pero no casas;\nbosques, pero no árboles;\ny agua, pero no peces.\n¿Qué soy?", "respuesta": "mapa"},
	{"pregunta": "Si me nombras, desaparezco.\n¿Qué soy?", "respuesta": "silencio"},
	{"pregunta": "Cuanto más seco, más mojo.\n¿Qué soy?", "respuesta": "toalla"},
	{"pregunta": "Oro parece, plata no es.\n¿Qué es?", "respuesta": "platano"},
	{"pregunta": "¿Qué tiene un ojo pero no puede ver?", "respuesta": "aguja"},
	{"pregunta": "Soy tuyo pero los demás\nme usan más que tú.\n¿Qué soy?", "respuesta": "nombre"},
	{"pregunta": "Camino sin pies,\nhablo sin boca.\n¿Qué soy?", "respuesta": "carta"},
	{"pregunta": "Blanca por dentro,\nverde por fuera.\nSi quieres que te lo diga, espera.\n¿Qué es?", "respuesta": "pera"},
]

var door_riddles: Dictionary = {}
var riddle_pool: Array = []

@onready var player: Node2D = $Player
@onready var riddle_dialog: CanvasLayer = $RiddleDialog

func _ready() -> void:
	map_rows = game_map.size()
	map_cols = game_map[0].size()
	var map_w = map_cols * TILE_SIZE
	var map_h = map_rows * TILE_SIZE
	cam_offset = Vector2((1024 - map_w) / 2.0, (576 - map_h) / 2.0)

	player.grid_moved.connect(_on_player_grid_moved)
	riddle_dialog.riddle_answered.connect(_on_riddle_answered)

func reset_game() -> void:
	# Restaurar mapa original
	game_map = [
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
		[1,0,0,0,1,0,0,0,1,0,0,0,0,0,1],
		[1,0,1,0,1,0,1,0,1,0,1,1,1,0,1],
		[1,0,1,0,0,0,1,0,2,0,0,0,1,0,1],
		[1,0,1,1,1,1,1,0,1,1,1,0,1,0,1],
		[1,0,0,0,0,0,2,0,0,0,1,0,1,0,1],
		[1,1,1,1,1,0,1,1,1,0,1,0,1,0,1],
		[1,0,0,0,1,0,0,0,1,0,2,0,0,0,1],
		[1,0,1,0,1,1,1,0,1,0,1,1,1,1,1],
		[1,0,1,0,0,0,0,0,1,0,0,0,0,3,1],
		[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	]

	# Asignar acertijos a puertas
	riddle_pool = riddles.duplicate()
	riddle_pool.shuffle()
	door_riddles.clear()
	var idx := 0
	for r in range(map_rows):
		for c in range(map_cols):
			if game_map[r][c] == 2:
				var key = Vector2i(c, r)
				door_riddles[key] = riddle_pool[idx % riddle_pool.size()]
				idx += 1

	# Posicionar jugador
	player.grid_pos = Vector2i(1, 1)
	player.position = grid_to_world(Vector2i(1, 1))
	player.is_moving = false

	riddle_dialog.visible = false
	queue_redraw()

func grid_to_world(grid: Vector2i) -> Vector2:
	return cam_offset + Vector2(grid.x * TILE_SIZE + TILE_SIZE / 2.0, grid.y * TILE_SIZE + TILE_SIZE / 2.0)

func is_cell_walkable(grid: Vector2i) -> int:
	if grid.x < 0 or grid.x >= map_cols or grid.y < 0 or grid.y >= map_rows:
		return -1
	return game_map[grid.y][grid.x]

func _on_player_grid_moved(new_pos: Vector2i) -> void:
	var cell = is_cell_walkable(new_pos)
	if cell == 3:
		# Victoria
		player.grid_pos = new_pos
		player.position = grid_to_world(new_pos)
		get_parent()._show_win()
	elif cell == 2:
		# Puerta — abrir acertijo
		_open_riddle(new_pos)
	# cell 0 handled by player, cell 1 blocked by player

func _open_riddle(door_pos: Vector2i) -> void:
	var key = door_pos
	if door_riddles.has(key):
		riddle_dialog.show_riddle(door_riddles[key], key)

func _on_riddle_answered(correct: bool, door_pos: Vector2i) -> void:
	if correct:
		game_map[door_pos.y][door_pos.x] = 0
		door_riddles.erase(door_pos)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and visible:
		get_parent()._pause_game()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	for r in range(map_rows):
		for c in range(map_cols):
			var pos = cam_offset + Vector2(c * TILE_SIZE, r * TILE_SIZE)
			var rect = Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
			var cell = game_map[r][c]

			match cell:
				0:
					draw_rect(rect, col_floor)
					draw_rect(rect, col_grid, false, 1.0)
				1:
					draw_rect(rect, col_wall)
					var inner = Rect2(pos + Vector2(2, 2), Vector2(TILE_SIZE - 4, TILE_SIZE - 4))
					draw_rect(inner, col_wall_inner)
					draw_line(pos, pos + Vector2(TILE_SIZE, 0), Color(0.25, 0.28, 0.35), 1.0)
				2:
					draw_rect(rect, col_floor)
					var door_rect = Rect2(pos + Vector2(4, 4), Vector2(TILE_SIZE - 8, TILE_SIZE - 8))
					draw_rect(door_rect, col_door)
					draw_rect(door_rect, col_door_glow, false, 2.0)
					# Icono candado
					var cx = pos.x + TILE_SIZE / 2.0
					var cy = pos.y + TILE_SIZE / 2.0
					draw_arc(Vector2(cx, cy - 4), 6, 0, TAU, 16, col_door_glow, 2.0)
					draw_rect(Rect2(cx - 5, cy, 10, 8), col_door_glow)
				3:
					draw_rect(rect, col_floor)
					var exit_rect = Rect2(pos + Vector2(3, 3), Vector2(TILE_SIZE - 6, TILE_SIZE - 6))
					draw_rect(exit_rect, col_exit)
					draw_rect(exit_rect, col_exit_glow, false, 2.0)
