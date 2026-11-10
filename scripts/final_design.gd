extends RefCounted
const BASE := "res://assets/design/"
var backgrounds: Dictionary = {}
var background: TextureRect
var panel: Panel
func texture(name: String) -> Texture2D:
	if not backgrounds.has(name): backgrounds[name] = load(BASE + name + ".png")
	return backgrounds[name]
func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
func setup(main) -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansKR.ttf")
	theme.set_color("font_color", "Label", Color("633e2e"))
	theme.set_color("font_outline_color", "Label", Color("633e2e"))
	theme.set_constant("outline_size", "Label", 1)
	main.theme = theme
	main.nickname_confirmation.get_label().add_theme_color_override("font_color", Color.WHITE)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(background)
	main.move_child(background, 0)
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fff9eb")
	paper.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", paper)
	main.add_child(panel)
	for control in [main.nickname_row, main.difficulty_select, main.validation_label, main.status_label, main.revenue_label, main.mold_row, main.tool_row, main.sales_row, main.bag_button, main.batter_button, main.filling_button, main.sale_zone, main.sales_feedback, main.bag_hint, main.result_label, main.leaderboard_panel, main.save_label, main.save_button, main.action_button, main.back_button]:
		control.reparent(main)
	for child in main.get_children():
		if child is MarginContainer: child.hide()
	main.add_theme_color_override("font_color", Color("633e2e"))
	for control in [main.save_button, main.action_button, main.back_button, main.batter_button, main.filling_button, main.bag_button, main.difficulty_select]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("bf4d3e") if control == main.action_button else Color("f4d5a0")
		style.set_corner_radius_all(10)
		control.add_theme_stylebox_override("normal", style)
		control.add_theme_color_override("font_color", Color.WHITE if control == main.action_button else Color("633e2e"))
	var sale_style := StyleBoxTexture.new()
	sale_style.texture = texture("sale_handoff_idle")
	main.sale_zone.add_theme_stylebox_override("panel", sale_style)
	main.batter_button.icon = texture("kettle")
	main.filling_button.icon = texture("bean_pot_idle")
	for button in [main.batter_button, main.filling_button, main.bag_button]:
		button.clip_text = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 70)
	for view in main.mold_views:
		view.title_label.add_theme_color_override("font_color", Color("fff1d6"))
		view.feedback_label.add_theme_color_override("font_color", Color("fff1d6"))
		view.cook_button.clip_text = true
		view.cook_button.expand_icon = true
		view.cook_button.add_theme_constant_override("icon_max_width", 110)
	main.preparation_label.add_theme_color_override("font_color", Color.WHITE)
	main.move_child(main.preparation_label, main.get_child_count() - 1)
func render(main) -> void:
	var play: bool = main.session.running or main.session.preparing
	var ended: bool = main.has_started and not play
	background.texture = texture("play_base" if play else ("result_base" if ended else "start_base"))
	panel.visible = not play
	place(panel, Rect2(550, 70, 390, 450) if not ended else Rect2(435, 90, 505, 420))
	main.batter_button.visible = play
	main.filling_button.visible = play
	main.bag_button.visible = play
	main.sale_zone.visible = play
	main.bag_hint.visible = play and not main.sales_feedback.visible
	main.tool_status.hide()
	place(main.mold_row, Rect2(30, 186, 670, 340))
	place(main.batter_button, Rect2(720, 282, 216, 105))
	place(main.filling_button, Rect2(720, 405, 216, 115))
	place(main.bag_button, Rect2(720, 105, 216, 160))
	place(main.sale_zone, Rect2(24, 30, 680, 140))
	place(main.sales_feedback, Rect2(45, 45, 280, 85))
	place(main.bag_hint, Rect2(40, 135, 600, 35))
	place(main.status_label, Rect2(720, 28, 216, 30))
	place(main.revenue_label, Rect2(720, 62, 216, 32))
	main.status_label.add_theme_font_size_override("font_size", 20)
	main.bag_button.icon = texture("bag_0")
	for index in main.mold_views.size():
		var m = main.session.molds[index]
		var name: String = ["grill_empty", "grill_batter", "grill_filling", "grill_covered", "grill_cooking", "grill_normal", "grill_burnt"][m.state]
		if m.state == main.Mold.State.READY and m.quality == main.Mold.Quality.DELICIOUS: name = "grill_perfect_with_sparkles"
		main.mold_views[index].cook_button.icon = texture(name)
	place(main.nickname_row, Rect2(455, 110, 465, 40))
	place(main.save_button, Rect2(455, 195, 465, 40))
	main.validation_label.add_theme_color_override("font_color", Color("a83124"))
	place(main.difficulty_select, Rect2(570, 150, 350, 40))
	place(main.validation_label, Rect2(455, 155, 465, 30))
	place(main.result_label, Rect2(40, 120, 390, 115) if ended else Rect2(570, 205, 350, 65))
	main.result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.result_label.add_theme_font_size_override("font_size", 20)
	place(main.leaderboard_panel, Rect2(455, 250, 465, 190) if ended else Rect2(570, 275, 350, 155))
	place(main.save_label, Rect2(455, 455, 465, 45) if ended else Rect2(570, 430, 350, 35))
	place(main.action_button, Rect2(50, 405, 340, 45) if ended else Rect2(570, 470, 350, 40))
	place(main.back_button, Rect2(50, 465, 340, 40))
