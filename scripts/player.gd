extends Node2D

## Jugador — movimiento por cuadrícula con animación suave.

signal grid_moved(new_pos: Vector2i)

var grid_pos := Vector2i(1, 1)
var is_moving := false
var move_speed := 200.0  # pixeles por segundo
var target_pos := Vector2.ZERO
var direction := "down"

@onready var sprite: Sprite2D = $Sprite2D

const TILE_SIZE := 48

func _ready() -> void:
	# Configurar sprite sheet: 6 columnas × 4 filas
	if sprite and sprite.texture:
		sprite.hframes = 6
		sprite.vframes = 4
		sprite.frame = 0

func _process(delta: float) -> void:
	if is_moving:
		var diff = target_pos - position
		var step = move_speed * delta
		if diff.length() <= step:
			position = target_pos
			is_moving = false
			_set_idle_frame()
		else:
			position += diff.normalized() * step
			_animate_walk(delta)
	else:
		_handle_input()

func _handle_input() -> void:
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		dir = Vector2i(0, -1)
		direction = "up"
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i(0, 1)
		direction = "down"
	elif Input.is_action_pressed("move_left"):
		dir = Vector2i(-1, 0)
		direction = "left"
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i(1, 0)
		direction = "right"

	if dir != Vector2i.ZERO:
		_try_move(dir)

func _try_move(dir: Vector2i) -> void:
	var new_grid = grid_pos + dir
	var game_world = get_parent()
	var cell = game_world.is_cell_walkable(new_grid)

	if cell == 1 or cell == -1:
		# Muro o fuera de límites
		_set_idle_frame()
		return

	if cell == 2 or cell == 3:
		# Puerta o meta — notificar al game world
		grid_moved.emit(new_grid)
		_set_idle_frame()
		return

	# Suelo libre — mover
	grid_pos = new_grid
	target_pos = game_world.grid_to_world(new_grid)
	is_moving = true

var walk_timer := 0.0

func _animate_walk(delta: float) -> void:
	walk_timer += delta
	if walk_timer >= 0.15:
		walk_timer = 0.0
		var row = _direction_row()
		var base = row * 6
		var current_col = (sprite.frame - base) if sprite.frame >= base else 0
		var next_col = (current_col + 1) % 6
		sprite.frame = base + next_col

func _set_idle_frame() -> void:
	var row = _direction_row()
	sprite.frame = row * 6  # primer frame de la fila

func _direction_row() -> int:
	match direction:
		"down": return 0
		"up": return 1
		"left": return 2
		"right": return 3
	return 0
