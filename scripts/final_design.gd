extends RefCounted
const BASE := "res://assets/design/"
const INK := Color("633e2e")
const PAPER := Color("fff9eb")
const RED := Color("bf4d3e")
var backgrounds: Dictionary = {}
var background: TextureRect
var panel: Panel
var welcome: Label
var heading: Label
var amount: Label
var mode_label: Label
var decoration: TextureRect
var divider: Label
var mold_art: Array[TextureRect] = []
var cooking_effects: Array[Control] = []
var mold_status: Array[Label] = []
var bag_art: Control
var breads: Array[TextureRect] = []
var tool_art: Array[TextureRect] = []
var modes: Array[Button] = []
var ranking_button: Button
var ranking_dialog: AcceptDialog
var form_heading: Label
var revenue_caption: Label
var cursor_art: TextureRect
var drag_art: Control
var clock_art: TextureRect
var coin_art: TextureRect
var sales_bubble: TextureRect
var sale_style := StyleBoxTexture.new()
func texture(name: String) -> Texture2D:
	if not backgrounds.has(name): backgrounds[name] = load(BASE + name + ".png")
	return backgrounds[name]
func place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
func art(parent: Node, name: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture(name)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	place(image, rect)
	return image
func label(parent: Node, text: String, font_size: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(10)
	box.border_color = border
	box.set_border_width_all(2 if border.a > 0 else 0)
	return box
func button_style(button: Button, primary: bool = false, transparent: bool = false) -> void:
	var normal := RED if primary else Color("f8e7cf")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var fill := normal
		if state in ["hover", "hover_pressed"]: fill = normal.lightened(0.08)
		if state == "pressed": fill = normal.darkened(0.07)
		if state == "disabled": fill = Color("e5d7bd")
		if transparent: fill = Color(1, 0.95, 0.84, 0.12) if state in ["hover", "pressed", "hover_pressed"] else Color.TRANSPARENT
		button.add_theme_stylebox_override(state, style(fill, Color("e8ab58") if state in ["focus", "pressed", "hover_pressed"] else Color.TRANSPARENT))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, PAPER if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("94735c"))
	button.add_theme_font_size_override("font_size", 18)
func setup(main) -> void:
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 0)
	main.theme = theme
	main.nickname_confirmation.get_label().add_theme_color_override("font_color", PAPER)
	background = art(main, "start_base", Rect2(0,0,960,540))
	main.move_child(background, 0)
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style(PAPER))
	main.add_child(panel)
	for control in [main.nickname_row, main.difficulty_select, main.validation_label, main.status_label, main.revenue_label, main.mold_row, main.tool_row, main.sales_row, main.bag_button, main.batter_button, main.filling_button, main.sale_zone, main.sales_feedback, main.bag_hint, main.result_label, main.leaderboard_panel, main.save_label, main.save_button, main.action_button, main.back_button]:
		control.reparent(main)
	for child in main.get_children():
		if child is MarginContainer: child.hide()
	for button in [main.action_button, main.save_button, main.back_button]:
		button_style(button, button != main.back_button, button == main.back_button)
	for child in main.nickname_row.get_children():
		if child is Button: button_style(child)
	main.nickname_input.add_theme_stylebox_override("read_only", style(Color("f8e7cf")))
	main.nickname_input.add_theme_stylebox_override("normal", style(Color("f8e7cf")))
	main.nickname_input.add_theme_color_override("font_uneditable_color", INK)
	main.nickname_input.add_theme_color_override("font_color", INK)
	main.nickname_input.add_theme_font_size_override("font_size", 20)
	main.nickname_input.placeholder_text = "닉네임 입력"
	main.nickname_input.add_theme_color_override("font_placeholder_color", Color("94735c"))
	welcome = label(main, "어서 오세요, 사장님!\n오늘도 맛있게 구워볼까요?", 22)
	for id in [main.Mold.Difficulty.EASY, main.Mold.Difficulty.NORMAL]:
		var button := Button.new()
		button.toggle_mode = true
		button.text = main.Mold.difficulty_name(id)
		button.pressed.connect(func():
			main.difficulty_select.select(id)
			main.difficulty_select.item_selected.emit(id))
		main.add_child(button)
		button_style(button)
		modes.append(button)
	heading = label(main, "오늘 장사, 잘 마쳤어요!", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount = label(main, "", 56, RED)
	mode_label = label(main, "", 16, RED)
	decoration = art(main, "fish_logo", Rect2(52,310,128,85))
	divider = label(main, "┊\n┊\n┊\n┊\n┊\n┊\n┊\n┊\n┊\n┊\n┊\n┊", 19, Color("cdb997"))
	for i in main.mold_views.size():
		var view = main.mold_views[i]
		var canvas := Control.new()
		canvas.custom_minimum_size = Vector2(209,155)
		view.add_child(canvas)
		for child in [view.title_label,view.cook_button,view.progress,view.feedback_label]: child.reparent(canvas)
		view.title_label.hide()
		place(view.cook_button,Rect2(0,0,209,132))
		view.cook_button.custom_minimum_size.y = 0
		view.cook_button.clip_text = true
		button_style(view.cook_button,false,true)
		for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: view.cook_button.add_theme_color_override(key,Color.TRANSPARENT)
		mold_art.append(art(view.cook_button,"grill_empty",Rect2(0,0,209,125)))
		var effect = preload("res://scripts/cooking_effects.gd").new()
		view.cook_button.add_child(effect)
		effect.setup(mold_art[-1], i)
		cooking_effects.append(effect)
		var status := label(canvas,"",12,PAPER)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		place(status,Rect2(0,125,209,20))
		mold_status.append(status)
		view.progress.custom_minimum_size.y = 4
		place(view.progress,Rect2(15,148,179,4))
		view.feedback_label.hide()
	for button in [main.batter_button,main.filling_button,main.bag_button]:
		button.custom_minimum_size = Vector2.ZERO
		button.clip_text = true
		button_style(button,false,true)
		for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: button.add_theme_color_override(key,Color.TRANSPARENT)
	tool_art.append(art(main.batter_button,"kettle",Rect2(32,0,148,120)))
	tool_art.append(art(main.filling_button,"bean_pot_idle",Rect2(9,-6,198,136)))
	bag_art = Control.new()
	bag_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.bag_button.add_child(bag_art)
	art(bag_art,"bag_back",Rect2(0,0,184,174))
	for i in 3:
		var bread := art(bag_art,"bread_normal",Rect2(37,34,110,70))
		bread.pivot_offset = Vector2(55,35)
		bread.rotation = PI / 2
		breads.append(bread)
	art(bag_art,"bag_front",Rect2(0,0,184,174))
	sales_bubble = art(main.sales_feedback,"sale_bubble",Rect2(-10,-24,260,96))
	sales_bubble.show_behind_parent = true
	main.sales_feedback.add_theme_color_override("font_color",INK)
	main.sales_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.sales_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main.bag_hint.add_theme_color_override("font_color",INK)
	main.ranking_title.add_theme_font_size_override("font_size",14)
	ranking_button = Button.new()
	ranking_button.text = "TOP 10 ↗"
	ranking_button.pressed.connect(func():
		var lines := PackedStringArray([main.ranking_title.text])
		for row in main.leaderboard_rows.get_children(): lines.append(row.text)
		if not main.ranking.load_message.is_empty(): lines.append(main.ranking.load_message)
		ranking_dialog.dialog_text = "\n".join(lines)
		ranking_dialog.popup_centered(Vector2i(550,420)))
	main.add_child(ranking_button)
	button_style(ranking_button,false,true)
	ranking_dialog = AcceptDialog.new()
	ranking_dialog.title = "TOP 10"
	ranking_dialog.ok_button_text = "닫기"
	main.add_child(ranking_dialog)
	ranking_dialog.get_label().add_theme_color_override("font_color", PAPER)
	form_heading = label(main,"오늘의 기록을 남겨볼까요?",24)
	revenue_caption = label(main,"이번 영업의 최종 수익",16)
	cursor_art = art(main.tool_cursor,"kettle",Rect2(0,0,52,52))
	for node in [main.tool_cursor,main.drag_preview]:
		node.add_theme_color_override("font_color",Color.TRANSPARENT)
		node.add_theme_constant_override("outline_size",0)
	drag_art = bag_art.duplicate()
	main.drag_preview.add_child(drag_art)
	drag_art.position = Vector2.ZERO
	drag_art.scale = Vector2(0.6,0.6)
	clock_art = art(main,"timer_icon",Rect2(785,30,25,25))
	coin_art = art(main,"coin_icon",Rect2(755,65,25,25))
	main.preparation_label.add_theme_color_override("font_color",PAPER)
	main.move_child(main.preparation_label,main.get_child_count()-1)
func money(value: int) -> String:
	var number := str(value)
	var index := number.length()-3
	while index > 0:
		number = number.insert(index,",")
		index -= 3
	return number + "원"
func render(main, now: int = -1) -> void:
	if now < 0: now = Time.get_ticks_usec()
	var play: bool = main.session.running or main.session.preparing
	var ended: bool = main.has_started and not play
	background.texture = texture("play_base" if play else ("result_base" if ended else "start_base"))
	panel.visible = not play and not ended
	place(panel,Rect2(562,90,355,345))
	welcome.visible = not main.has_started
	place(welcome,Rect2(588,120,303,65))
	main.difficulty_select.hide()
	for i in modes.size():
		modes[i].visible = not main.has_started
		modes[i].set_pressed_no_signal(main.difficulty_select.get_selected_id() == (1 if i == 0 else 0))
		place(modes[i],Rect2(588+i*159.5,224,143.5,56))
	for node in [heading,amount,mode_label,decoration,divider]: node.visible = ended
	place(heading,Rect2(0,38,960,50))
	place(mode_label,Rect2(52,125,350,28))
	mode_label.text = main.Mold.difficulty_name(main.session.difficulty) + " 모드"
	place(amount,Rect2(52,177,350,90))
	amount.text = money(main.session.revenue)
	place(divider,Rect2(437,100,14,405))
	revenue_caption.visible = ended
	place(revenue_caption,Rect2(52,163,350,28))
	ranking_button.visible = not main.has_started
	place(ranking_button,Rect2(588,372,303,30))
	main.tool_status.hide()
	main.batter_button.visible = play
	main.filling_button.visible = play
	main.bag_button.visible = play
	main.sale_zone.visible = play
	main.bag_hint.hide()
	place(main.mold_row,Rect2(40,198,648,319))
	main.mold_row.add_theme_constant_override("h_separation",10)
	main.mold_row.add_theme_constant_override("v_separation",8)
	place(main.batter_button,Rect2(720,277,216,120))
	place(main.filling_button,Rect2(720,405,216,125))
	place(main.bag_button,Rect2(728,103,200,166))
	place(bag_art,Rect2(8,-4,184,174))
	place(main.sale_zone,Rect2(24,27,680,148))
	sale_style.texture = texture("sale_handoff_ready" if main.dragging else "sale_handoff_idle")
	main.sale_zone.add_theme_stylebox_override("panel",sale_style)
	main.sale_zone.get_child(0).hide()
	main.sale_zone.tooltip_text = ""
	place(main.sales_feedback,Rect2(50,53,240,65))
	place(main.bag_hint,Rect2(40,130,580,40))
	main.status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.revenue_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	place(main.status_label,Rect2(812,27,114,33))
	main.status_label.text = main.status_label.text.trim_prefix("남은 시간 ")
	clock_art.visible = play
	coin_art.visible = play
	place(main.revenue_label,Rect2(780,60,146,35))
	main.status_label.add_theme_font_size_override("font_size",26)
	main.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	main.revenue_label.add_theme_font_size_override("font_size",29)
	main.revenue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	main.revenue_label.text = money(main.session.revenue)
	main.status_label.visible = play
	main.revenue_label.visible = play
	tool_art[1].texture = texture("bean_pot_selected" if main.session.selected_tool == main.Session.Tool.FILLING else ("bean_pot_hover" if main.filling_button.is_hovered() else "bean_pot_idle"))
	for i in main.mold_views.size():
		var view = main.mold_views[i]
		var mold = main.session.molds[i]
		cooking_effects[i].sync(mold.state, main.session.running)
		cooking_effects[i].update_browning(mold, mini(now, main.session.started_at + main.Session.DURATION_USEC))
		view.cook_button.tooltip_text = ""
		view.progress.hide()
		mold_status[i].hide()
		mold_status[i].text = view.feedback_label.text if not main.session.feedback[i].is_empty() and view.feedback_label.text == main.session.feedback[i] else view.cook_button.text.get_slice("\n",0)
		mold_status[i].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.bag_button.tooltip_text = ""
	main.batter_button.tooltip_text = ""
	main.filling_button.tooltip_text = ""
	cursor_art.texture = texture("kettle" if main.session.selected_tool == main.Session.Tool.BATTER else "spatula_cursor")
	cursor_art.visible = main.mold_row.get_global_rect().has_point(main.get_global_mouse_position())
	var contents: Array = main.session.bag.items
	for i in breads.size():
		breads[i].visible = i < contents.size()
		if i < contents.size():
			breads[i].texture = texture({main.Mold.Quality.NORMAL:"bread_normal",main.Mold.Quality.DELICIOUS:"bread_perfect",main.Mold.Quality.BURNT:"bread_burnt"}[contents[i]])
			breads[i].position.x = 37 + (i-(contents.size()-1)/2.0)*58
	for i in breads.size():
		var ghost = drag_art.get_child(i+1)
		ghost.texture = breads[i].texture
		ghost.visible = breads[i].visible
		ghost.position = breads[i].position
	form_heading.visible = ended and not main.result_recorded
	place(form_heading,Rect2(482,139,416,40))
	main.nickname_row.visible = ended and not main.result_recorded
	main.save_button.visible = ended and not main.result_recorded
	place(main.nickname_row,Rect2(482,223,416,53))
	place(main.validation_label,Rect2(482,281,416,28))
	main.validation_label.add_theme_color_override("font_color",RED)
	place(main.save_button,Rect2(482,322,416,48))
	place(main.result_label,Rect2(52,273,350,70) if ended else Rect2(588,265,303,0))
	main.result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.result_label.add_theme_font_size_override("font_size",13)
	main.result_label.hide()
	decoration.position = Vector2(52,325)
	for i in main.ranking.records.size():
		var record: Dictionary = main.ranking.records[i]
		main.leaderboard_rows.get_child(i).text = "%2d.  %s  ·  %s" % [i+1, record.nickname, money(record.score)]
	main.leaderboard_panel.visible = ended and main.result_recorded
	place(main.leaderboard_panel,Rect2(470,170,440,329))
	place(main.save_label,Rect2(482,382,416,64) if ended and not main.result_recorded else Rect2(470,115,440,40))
	main.save_label.add_theme_font_size_override("font_size",13)
	main.save_label.visible = ended and (main.result_recorded or main.save_label.text.begins_with("기록 저장 실패"))
	place(main.action_button,Rect2(52,408,320,45) if ended else Rect2(588,304,303,54))
	place(main.back_button,Rect2(52,463,320,36))
