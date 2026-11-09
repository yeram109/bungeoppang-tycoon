extends VBoxContainer
## Shared presentation for each independent mold.
signal mold_clicked
const Mold = preload("res://scripts/mold.gd")
var title_label: Label
var cook_button: Button
var progress: ProgressBar
var feedback_label: Label
var button_style := StyleBoxFlat.new()

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	add_child(title_label)
	cook_button = Button.new()
	cook_button.custom_minimum_size = Vector2(0, 110)
	cook_button.focus_mode = Control.FOCUS_NONE
	cook_button.add_theme_font_size_override("font_size", 22)
	button_style.set_corner_radius_all(12)
	for style_name in ["normal", "hover", "pressed", "disabled"]:
		cook_button.add_theme_stylebox_override(style_name, button_style)
	cook_button.pressed.connect(func(): mold_clicked.emit())
	add_child(cook_button)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 18
	progress.max_value = 6.0
	progress.show_percentage = false
	add_child(progress)
	feedback_label = Label.new()
	feedback_label.custom_minimum_size.y = 52
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 16)
	add_child(feedback_label)

func render(mold: RefCounted, index: int, now: int, active: bool) -> void:
	title_label.text = "붕어빵 틀 %d" % (index + 1)
	cook_button.disabled = not active
	var elapsed: int = mold.elapsed_at(now)
	progress.value = elapsed / 1_000_000.0
	feedback_label.text = mold.feedback
	var color := Color("665345")
	if mold.state == Mold.State.EMPTY:
		cook_button.text = "빈 틀\n반죽 투입"
		if mold.feedback.begins_with("탐"):
			color = Color("292523")
	else:
		var quality: int = Mold.quality_at(elapsed)
		var quality_text: String = ["조리 중", "완벽", "일반", "탐"][quality]
		color = [Color("8c806b"), Color("b88428"), Color("825135"), Color("292523")][quality]
		var action := "뒤집기" if mold.state == Mold.State.SIDE_1 else "판매"
		cook_button.text = "%d면 · %s\n%.1f초 / %s" % [mold.state, quality_text, elapsed / 1_000_000.0, action]
	if button_style.bg_color != color:
		button_style.bg_color = color
