extends Control

# Panel de Mejoras - Overlay sobre el Hub Menu

signal closed

@onready var label_coins: Label = $PanelCard/Margin/VBox/TopBar/CoinsBox/CoinsLabel
@onready var btn_close: Button = $PanelCard/Margin/VBox/TopBar/BtnClose

@onready var btn_engine: Button = $PanelCard/Margin/VBox/GridUpgrades/CardEngine/VBox/BtnUpgrade
@onready var level_engine: Label = $PanelCard/Margin/VBox/GridUpgrades/CardEngine/VBox/LevelLabel
@onready var bar_engine: ProgressBar = $PanelCard/Margin/VBox/GridUpgrades/CardEngine/VBox/ProgressBar

@onready var btn_suspension: Button = $PanelCard/Margin/VBox/GridUpgrades/CardSuspension/VBox/BtnUpgrade
@onready var level_suspension: Label = $PanelCard/Margin/VBox/GridUpgrades/CardSuspension/VBox/LevelLabel
@onready var bar_suspension: ProgressBar = $PanelCard/Margin/VBox/GridUpgrades/CardSuspension/VBox/ProgressBar

@onready var btn_tires: Button = $PanelCard/Margin/VBox/GridUpgrades/CardTires/VBox/BtnUpgrade
@onready var level_tires: Label = $PanelCard/Margin/VBox/GridUpgrades/CardTires/VBox/LevelLabel
@onready var bar_tires: ProgressBar = $PanelCard/Margin/VBox/GridUpgrades/CardTires/VBox/ProgressBar

@onready var btn_thruster: Button = $PanelCard/Margin/VBox/GridUpgrades/CardThruster/VBox/BtnUpgrade
@onready var level_thruster: Label = $PanelCard/Margin/VBox/GridUpgrades/CardThruster/VBox/LevelLabel
@onready var bar_thruster: ProgressBar = $PanelCard/Margin/VBox/GridUpgrades/CardThruster/VBox/ProgressBar

func _ready() -> void:
	btn_close.pressed.connect(func(): SoundManager.play_sfx("click"); closed.emit())
	
	btn_engine.pressed.connect(func(): _try_upgrade("engine"))
	btn_suspension.pressed.connect(func(): _try_upgrade("suspension"))
	btn_tires.pressed.connect(func(): _try_upgrade("tires"))
	btn_thruster.pressed.connect(func(): _try_upgrade("thruster"))
	
	GameManager.upgrades_updated.connect(_update_ui)
	GameManager.coins_changed.connect(func(_c): _update_ui())
	
	_update_ui()
	_animate_in()

func _animate_in() -> void:
	var card = $PanelCard
	card.scale = Vector2(0.8, 0.8)
	card.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.2)

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
