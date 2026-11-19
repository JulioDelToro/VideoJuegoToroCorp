extends Control

# Panel de Tienda - Comprar nuevos vehículos con oro

signal closed

@onready var grid: HBoxContainer = $PanelCard/Margin/VBox/ScrollContainer/Grid
@onready var btn_close: Button = $PanelCard/Margin/VBox/TopBar/BtnClose
@onready var label_coins: Label = $PanelCard/Margin/VBox/TopBar/CoinsBox/CoinsLabel

func _ready() -> void:
	btn_close.pressed.connect(func(): SoundManager.play_sfx("click"); closed.emit())
	GameManager.coins_changed.connect(func(_c): _rebuild())
	_rebuild()
	_animate_in()

func _animate_in() -> void:
	var card = $PanelCard
	card.scale = Vector2(0.8, 0.8)
	card.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.2)

func _rebuild() -> void:
	label_coins.text = "%d   •   💎 %d" % [GameManager.total_coins, GameManager.total_rubies]
	
	# Limpiar cards
	for child in grid.get_children():
		child.queue_free()
	
	var has_items := false
	for vehicle_id in GameManager.VEHICLE_CATALOG:
		if GameManager.is_vehicle_owned(vehicle_id):
			continue # No mostrar los que ya tiene
		
		has_items = true
		var data = GameManager.get_vehicle_data(vehicle_id)
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 390)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.12, 0.17, 0.96)
		style.border_color = Color(0.9, 0.7, 0.2, 0.6)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 14
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 8
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)
		
		# Color swatch
		var color_bar = ColorRect.new()
		color_bar.custom_minimum_size = Vector2(0, 8)
		color_bar.color = data.get("color", Color.WHITE)
		vbox.add_child(color_bar)
		
		# Vehicle composite preview (body + wheels)
		var preview_box = Control.new()
		preview_box.custom_minimum_size = Vector2(220, 125)
		preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(preview_box)
		
		var wheel_tex = load(data.get("wheel_texture", ""))
		var r_scale: float = float(data.get("rear_wheel_scale", 0.90))
		var f_scale: float = float(data.get("front_wheel_scale", 0.90))
		var r_sz: float = 50.0 * r_scale
		var f_sz: float = 50.0 * f_scale
		var r_cx: float = float(data.get("rear_wheel_x", -70.0)) * 0.78
		var f_cx: float = float(data.get("front_wheel_x", 70.0)) * 0.78
		
		var tex_rect = TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_CENTER)
		tex_rect.offset_left = -105
		tex_rect.offset_top = -64
		tex_rect.offset_right = 105
		tex_rect.offset_bottom = 26
		tex_rect.texture = load(data.get("body_texture", ""))
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.modulate = Color.WHITE
		preview_box.add_child(tex_rect)
		
		if wheel_tex:
			var w_back = TextureRect.new()
			w_back.set_anchors_preset(Control.PRESET_CENTER)
			w_back.offset_left = r_cx - r_sz * 0.5
			w_back.offset_right = r_cx + r_sz * 0.5
			w_back.offset_bottom = 58.0
			w_back.offset_top = 58.0 - r_sz
			w_back.texture = wheel_tex
			w_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			w_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview_box.add_child(w_back)
			
			var w_front = TextureRect.new()
			w_front.set_anchors_preset(Control.PRESET_CENTER)
			w_front.offset_left = f_cx - f_sz * 0.5
			w_front.offset_right = f_cx + f_sz * 0.5
			w_front.offset_bottom = 58.0
			w_front.offset_top = 58.0 - f_sz
			w_front.texture = wheel_tex
			w_front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			w_front.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			preview_box.add_child(w_front)
		
		# Vehicle name
		var name_lbl = Label.new()
		name_lbl.text = data.get("name", "???")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		vbox.add_child(name_lbl)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = data.get("description", "")
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)
		
		# Price label
		var price_lbl = Label.new()
		var price = data.get("price", 0)
		price_lbl.text = "🪙 %d" % price
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 26)
		if GameManager.total_coins >= price:
			price_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.2))
		else:
			price_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
		vbox.add_child(price_lbl)
		
		# Buy button
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 52)
		btn.text = "COMPRAR"
		btn.disabled = not GameManager.can_buy_vehicle(vehicle_id)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		# Amber button style for shop
		var btn_n = StyleBoxTexture.new()
		btn_n.texture = load("res://assets/sprites/btn_amber_normal.png")
		btn_n.texture_margin_left = 34; btn_n.texture_margin_top = 14
		btn_n.texture_margin_right = 34; btn_n.texture_margin_bottom = 22
		var btn_h = StyleBoxTexture.new()
		btn_h.texture = load("res://assets/sprites/btn_amber_hover.png")
		btn_h.texture_margin_left = 34; btn_h.texture_margin_top = 14
		btn_h.texture_margin_right = 34; btn_h.texture_margin_bottom = 22
		var btn_p = StyleBoxTexture.new()
		btn_p.texture = load("res://assets/sprites/btn_amber_pressed.png")
		btn_p.texture_margin_left = 34; btn_p.texture_margin_top = 20
		btn_p.texture_margin_right = 34; btn_p.texture_margin_bottom = 16
		btn.add_theme_stylebox_override("normal", btn_n)
		btn.add_theme_stylebox_override("hover", btn_h)
		btn.add_theme_stylebox_override("pressed", btn_p)
		
		var vid = vehicle_id
		btn.pressed.connect(func():
			SoundManager.play_sfx("click")
			if GameManager.buy_vehicle(vid):
				_rebuild()
		)
		vbox.add_child(btn)
		
		grid.add_child(card)
	
	if not has_items:
		var empty_lbl = Label.new()
		empty_lbl.text = "¡Ya tienes todos los vehículos!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 28)
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(empty_lbl)
