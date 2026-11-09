extends Control
const Session = preload("res://scripts/game_session.gd")
const MoldScene = preload("res://scenes/mold.tscn")
var session = Session.new()
var mold_views: Array = []
var status_label: Label
var action_button: Button
var result_label: Label
var has_started := false

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "붕어빵 장인"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	header.add_child(status_label)
	var help := Label.new()
	help.text = "틀 클릭: 투입 → 뒤집기 → 판매  |  양면 완벽 100점 · 그 외 판매 60점\n면마다 3~4.5초 완벽 · 4.5초 초과~6초 일반 · 6초 초과 자동 폐기"
	help.add_theme_font_size_override("font_size", 16)
	column.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for index in Session.MOLD_COUNT:
		var view = MoldScene.instantiate()
		row.add_child(view)
		view.mold_clicked.connect(_on_mold_clicked.bind(index))
		mold_views.append(view)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 22)
	column.add_child(result_label)
	action_button = Button.new()
	action_button.text = "게임 시작"
	action_button.custom_minimum_size.y = 44
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_start_round)
	column.add_child(action_button)
	_render(Time.get_ticks_usec())

func _start_round() -> void:
	if session.running:
		return
	has_started = true
	session.start(Time.get_ticks_usec())
	_render(Time.get_ticks_usec())

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	session.advance(now)
	_render(now)

func _on_mold_clicked(index: int) -> void:
	var now := Time.get_ticks_usec()
	session.click_mold(index, now)
	_render(now)

func _render(now: int) -> void:
	var remaining: float = session.remaining_usec(now) / 1_000_000.0 if has_started else 60.0
	status_label.text = "남은 시간 %04.1f초    |    점수 %d점" % [remaining, session.score]
	var ended: bool = has_started and not session.running
	var display_time: int = mini(now, session.started_at + Session.DURATION_USEC) if ended else now
	for index in mold_views.size():
		mold_views[index].render(session.molds[index], index, display_time, session.running)
	result_label.text = "시간 종료! 최종 점수 %d점" % session.score if ended else "60초 동안 세 틀을 동시에 관리하세요."
	action_button.visible = not session.running
	action_button.text = "다시 하기" if ended else "게임 시작"
