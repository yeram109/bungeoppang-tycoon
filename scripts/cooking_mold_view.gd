extends VBoxContainer
signal mold_clicked
const Mold = preload("res://scripts/cooking_mold.gd")
var title_label: Label
var cook_button: Button
var progress: ProgressBar
var feedback_label: Label
var button_style := StyleBoxFlat.new()

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 3)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	add_child(title_label)
	cook_button = Button.new()
	cook_button.custom_minimum_size.y = 66
	cook_button.focus_mode = Control.FOCUS_NONE
	cook_button.add_theme_font_size_override("font_size", 18)
	button_style.set_corner_radius_all(10)
	for style in ["normal", "hover", "pressed", "disabled"]:
		cook_button.add_theme_stylebox_override(style, button_style)
	cook_button.pressed.connect(func(): mold_clicked.emit())
	add_child(cook_button)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	add_child(progress)
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 13)
	feedback_label.custom_minimum_size.y = 20
	feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(feedback_label)

func render(mold: RefCounted, index: int, now: int, active: bool, message: String = "") -> void:
	title_label.text = "틀 %d" % (index + 1)
	cook_button.disabled = not active
	var first: bool = mold.state in [Mold.State.FIRST_BATTER, Mold.State.FILLING_ADDED, Mold.State.SIDE_1] or (mold.state == Mold.State.BURNT and mold.first_quality == Mold.SideQuality.BURNT)
	var quality: int = Mold.first_quality_at(mold.elapsed_at(now)) if first else mold.second_quality
	progress.max_value = 9.0 if first else 6.0
	progress.value = mold.elapsed_at(now) / 1_000_000.0
	var phase := "1면" if first else "2면"
	var hint := ""
	var color := Color("665345")
	if mold.state == Mold.State.EMPTY:
		cook_button.text = "빈 틀\n주전자로 첫 반죽"
		hint = "반죽 → 팥 → 반죽"
	else:
		var quality_text: String = ["조리 중", "완벽", "일반", "탐"][quality]
		color = [Color("8c806b"), Color("b88428"), Color("825135"), Color("292523")][quality]
		match mold.state:
			Mold.State.FIRST_BATTER: hint = "주걱으로 팥 넣기"
			Mold.State.FILLING_ADDED: hint = "주전자로 반죽 추가"
			Mold.State.SIDE_1: hint = "도구 없이 클릭하여 뒤집기" if quality != Mold.SideQuality.COOKING else "5초부터 뒤집기"
			Mold.State.SIDE_2: hint = "두 번째 면 굽는 중"
			Mold.State.READY: hint = "맛있는 붕어빵" if mold.quality == Mold.Quality.DELICIOUS else "일반 붕어빵"
			Mold.State.BURNT: hint = "탄 붕어빵 · 틀에 남음"
		cook_button.text = "%s · %s\n%s" % [phase, quality_text, hint]
		hint = "계속 조리 중 · 수거 미지원" if mold.state == Mold.State.READY else ("수거 미지원" if mold.state == Mold.State.BURNT else "첫 면 5~7초 / 두 번째 면 3~4.5초 완벽")
	feedback_label.text = message if not message.is_empty() else hint
	feedback_label.modulate = Color("ffb4a0") if not message.is_empty() else Color.WHITE
	button_style.bg_color = color
