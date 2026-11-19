extends Control

# Menú del Taller de Mejoras de TOROCORP
# Permite mejorar Motor, Suspensión, Neumáticos y Propulsor con ToroCoins

@onready var label_coins: Label = $TopBar/CoinsBox/CoinsLabel
@onready var btn_back: Button = $TopBar/BtnBack
@onready var btn_play: Button = $BottomBar/BtnDrive

# Botones y etiquetas de cada mejora
@onready var btn_engine: Button = $GridUpgrades/CardEngine/VBox/BtnUpgrade
@onready var level_engine: Label = $GridUpgrades/CardEngine/VBox/LevelLabel
@onready var bar_engine: ProgressBar = $GridUpgrades/CardEngine/VBox/ProgressBar

@onready var btn_suspension: Button = $GridUpgrades/CardSuspension/VBox/BtnUpgrade
@onready var level_suspension: Label = $GridUpgrades/CardSuspension/VBox/LevelLabel
@onready var bar_suspension: ProgressBar = $GridUpgrades/CardSuspension/VBox/ProgressBar

@onready var btn_tires: Button = $GridUpgrades/CardTires/VBox/BtnUpgrade
@onready var level_tires: Label = $GridUpgrades/CardTires/VBox/LevelLabel
@onready var bar_tires: ProgressBar = $GridUpgrades/CardTires/VBox/ProgressBar

@onready var btn_thruster: Button = $GridUpgrades/CardThruster/VBox/BtnUpgrade
@onready var level_thruster: Label = $GridUpgrades/CardThruster/VBox/LevelLabel
@onready var bar_thruster: ProgressBar = $GridUpgrades/CardThruster/VBox/ProgressBar

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	btn_play.pressed.connect(_on_play_pressed)
	
	btn_engine.pressed.connect(func(): _try_upgrade("engine"))
	btn_suspension.pressed.connect(func(): _try_upgrade("suspension"))
	btn_tires.pressed.connect(func(): _try_upgrade("tires"))
	btn_thruster.pressed.connect(func(): _try_upgrade("thruster"))
	
	GameManager.upgrades_updated.connect(_update_ui)
	GameManager.coins_changed.connect(func(_c): _update_ui())
	
	_update_ui()

func _update_ui() -> void:
	label_coins.text = str(GameManager.total_coins)
	
	_update_card("engine", btn_engine, level_engine, bar_engine)
	_update_card("suspension", btn_suspension, level_suspension, bar_suspension)
	_update_card("tires", btn_tires, level_tires, bar_tires)
	_update_card("thruster", btn_thruster, level_thruster, bar_thruster)

func _update_card(category: String, btn: Button, lbl: Label, bar: ProgressBar) -> void:
	var lvl = GameManager.upgrades.get(category, 1)
	bar.value = lvl
	
	if lvl >= 5:
		lbl.text = "NIVEL MÁXIMO (5/5)"
		btn.text = "COMPLETO"
		btn.disabled = true
	else:
		lbl.text = "NIVEL %d / 5" % lvl
		var cost = GameManager.get_next_upgrade_cost(category)
		btn.text = "MEJORAR: %d 🪙" % cost
		btn.disabled = GameManager.total_coins < cost

func _try_upgrade(category: String) -> void:
	if GameManager.buy_upgrade(category):
		_update_ui()
	else:
		SoundManager.play_sfx("click", 0.8)

func _on_back_pressed() -> void:
	SoundManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_play_pressed() -> void:
	SoundManager.play_sfx("click")
	GameManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
