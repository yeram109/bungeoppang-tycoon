extends Control
const Session = preload("res://scripts/game_session.gd")
const MoldScene = preload("res://scenes/mold.tscn")
const RankingStore = preload("res://scripts/ranking_store.gd")
var ranking_path := "user://rankings.json"
var ranking: RefCounted
var player_nickname := ""
var result_recorded := false
var nickname_input: LineEdit
var nickname_row: HBoxContainer
var validation_label: Label
var save_label: Label
var back_button: Button
var mold_row: HBoxContainer
var leaderboard_panel: VBoxContainer
var leaderboard_rows: VBoxContainer
var session = Session.new()
var mold_views: Array = []
var status_label: Label
var action_button: Button
var result_label: Label
var has_started := false

func _ready() -> void:
	ranking = RankingStore.new(ranking_path)
	ranking.load_records()
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
	nickname_row = HBoxContainer.new()
	column.add_child(nickname_row)
	var nickname_caption := Label.new()
	nickname_caption.text = "닉네임"
	nickname_row.add_child(nickname_caption)
	nickname_input = LineEdit.new()
	nickname_input.placeholder_text = "한글·영문·숫자 1~12자"
	nickname_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nickname_input.custom_minimum_size.y = 38
	nickname_input.text_submitted.connect(func(_text: String): _start_round())
	nickname_row.add_child(nickname_input)
	# Godot 4.7.2's Windows LineEdit loses committed Korean syllables on
	# the tested Microsoft IME. Use the engine's native Windows edit control.
	if OS.get_name() == "Windows" and DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_INPUT):
		nickname_input.editable = false
		nickname_input.placeholder_text = "오른쪽 버튼으로 닉네임 입력"
		var edit_nickname := Button.new()
		edit_nickname.text = "입력·변경"
		edit_nickname.pressed.connect(_open_nickname_dialog)
		nickname_row.add_child(edit_nickname)
	validation_label = Label.new()
	validation_label.add_theme_color_override("font_color", Color("ffb4a0"))
	column.add_child(validation_label)
	var row := HBoxContainer.new()
	mold_row = row
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
	leaderboard_panel = VBoxContainer.new()
	leaderboard_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(leaderboard_panel)
	var ranking_title := Label.new()
	ranking_title.text = "이 PC TOP 10 · 동점은 먼저 달성한 기록 우선"
	leaderboard_panel.add_child(ranking_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	leaderboard_panel.add_child(scroll)
	leaderboard_rows = VBoxContainer.new()
	leaderboard_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(leaderboard_rows)
	save_label = Label.new()
	save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_label.text = ranking.load_message
	column.add_child(save_label)
	action_button = Button.new()
	action_button.text = "게임 시작"
	action_button.custom_minimum_size.y = 44
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_start_round)
	column.add_child(action_button)
	back_button = Button.new()
	back_button.text = "시작 화면으로"
	back_button.pressed.connect(_show_start)
	column.add_child(back_button)
	_refresh_rankings()
	_render(Time.get_ticks_usec())

func _open_nickname_dialog() -> void:
	if has_started:
		return
	var error := DisplayServer.dialog_input_text("닉네임 입력", "한글·영문·숫자 1~12자", nickname_input.text, _accept_nickname)
	if error != OK:
		validation_label.text = "닉네임 입력창을 열 수 없습니다. 다시 시도해 주세요."

func _accept_nickname(value: String) -> void:
	if has_started:
		return
	nickname_input.text = value.strip_edges()
	validation_label.text = RankingStore.nickname_error(value)

func _start_round() -> void:
	if session.running:
		return
	if not has_started:
		# Commit any Korean IME composition before reading the final nickname.
		nickname_input.apply_ime()
		var error: String = RankingStore.nickname_error(nickname_input.text)
		if not error.is_empty():
			validation_label.text = error
			return
		player_nickname = nickname_input.text.strip_edges()
		nickname_input.text = player_nickname
	nickname_input.release_focus()
	validation_label.text = ""
	save_label.text = ""
	result_recorded = false
	has_started = true
	session.start(Time.get_ticks_usec())
	_render(Time.get_ticks_usec())

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	session.advance(now)
	_finish_if_needed()
	_render(now)

func _on_mold_clicked(index: int) -> void:
	var now := Time.get_ticks_usec()
	session.click_mold(index, now)
	_finish_if_needed()
	_render(now)

func _render(now: int) -> void:
	# Display only: a positive remainder must never round down to 00.0.
	var remaining_usec: int = session.remaining_usec(now) if has_started else Session.DURATION_USEC
	var remaining: float = ceili(remaining_usec / 100_000.0) / 10.0
	status_label.text = "남은 시간 %04.1f초    |    점수 %d점" % [remaining, session.score]
	status_label.visible = has_started
	var ended: bool = has_started and not session.running
	var display_time: int = mini(now, session.started_at + Session.DURATION_USEC) if ended else now
	for index in mold_views.size():
		mold_views[index].render(session.molds[index], index, display_time, session.running)
	result_label.text = "%s 님\n시간 종료! 최종 점수 %d점 · 이 PC 최고 점수 %d점" % [player_nickname, session.score, maxi(session.score, ranking.best_score())] if ended else "60초 동안 세 틀을 동시에 관리하세요."
	action_button.visible = not session.running
	action_button.text = "다시 하기" if ended else "게임 시작"
	nickname_row.visible = not has_started
	validation_label.visible = not has_started and not validation_label.text.is_empty()
	mold_row.visible = session.running
	leaderboard_panel.visible = not session.running
	save_label.visible = not session.running and not save_label.text.is_empty()
	back_button.visible = ended

func _finish_if_needed() -> void:
	if not has_started or session.running or result_recorded:
		return
	# Set before I/O: repeated frames, input and result re-entry cannot retry or duplicate.
	result_recorded = true
	var saved: bool = ranking.add_result(player_nickname, session.score, int(Time.get_unix_time_from_system() * 1000))
	save_label.text = "기록 저장 완료 · TOP 10만 보관합니다." if saved else "저장 실패 · 이번 기록은 저장되지 않았습니다.\n" + ranking.last_error
	save_label.modulate = Color.WHITE if saved else Color("ffb4a0")
	_refresh_rankings()

func _show_start() -> void:
	if session.running:
		return
	has_started = false
	validation_label.text = ""
	_render(Time.get_ticks_usec())

func _refresh_rankings() -> void:
	for child in leaderboard_rows.get_children():
		leaderboard_rows.remove_child(child)
		child.queue_free()
	if ranking.records.is_empty():
		var empty := Label.new()
		empty.text = "아직 기록이 없습니다."
		leaderboard_rows.add_child(empty)
	for index in ranking.records.size():
		var record: Dictionary = ranking.records[index]
		var label := Label.new()
		var played := Time.get_datetime_string_from_unix_time(int(record.played_at / 1000.0)).replace("T", " ")
		label.text = "%2d.  %s  ·  %d점  ·  %s UTC" % [index + 1, record.nickname, record.score, played]
		label.add_theme_font_size_override("font_size", 16)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		leaderboard_rows.add_child(label)
