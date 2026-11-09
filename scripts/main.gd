extends Control
const Session = preload("res://scripts/cooking_session.gd")
const MoldScene = preload("res://scenes/cooking_mold.tscn")
const RankingStore = preload("res://scripts/ranking_store.gd")
var ranking_path := "user://rankings.json"
var ranking: RefCounted
var player_nickname := ""
var result_recorded := false
var nickname_input: LineEdit
var nickname_row: HBoxContainer
var nickname_confirmation: ConfirmationDialog
var pending_nickname := ""
var nickname_pending := false
var validation_label: Label
var save_label: Label
var back_button: Button
var mold_row: GridContainer
var tool_row: HBoxContainer
var batter_button: Button
var filling_button: Button
var tool_status: Label
var tool_cursor: Label
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
	help.text = "주전자 반죽 → 주걱 팥 → 주전자 반죽 → 도구 없이 뒤집기\n첫 면 5~7초 완벽 / 9초 초과 탐 · 두 번째 면 3~4.5초 완벽 / 6초 초과 탐"
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
	nickname_confirmation = ConfirmationDialog.new()
	nickname_confirmation.title = "닉네임 적용 확인"
	nickname_confirmation.ok_button_text = "적용"
	nickname_confirmation.cancel_button_text = "취소"
	nickname_confirmation.confirmed.connect(_confirm_nickname)
	nickname_confirmation.canceled.connect(_cancel_nickname)
	add_child(nickname_confirmation)
	tool_row = HBoxContainer.new()
	column.add_child(tool_row)
	batter_button = Button.new()
	batter_button.text = "▰ 양은주전자 · 반죽"
	filling_button = Button.new()
	filling_button.text = "▱ 주걱 · 팥"
	for button in [batter_button, filling_button]:
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 36
		tool_row.add_child(button)
	batter_button.pressed.connect(_on_tool_pressed.bind(Session.Tool.BATTER))
	filling_button.pressed.connect(_on_tool_pressed.bind(Session.Tool.FILLING))
	tool_status = Label.new()
	tool_status.add_theme_font_size_override("font_size", 14)
	tool_row.add_child(tool_status)
	tool_cursor = Label.new()
	tool_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_cursor.z_index = 100
	tool_cursor.add_theme_color_override("font_color", Color("ffe2a5"))
	tool_cursor.add_theme_color_override("font_outline_color", Color.BLACK)
	tool_cursor.add_theme_constant_override("outline_size", 6)
	add_child(tool_cursor)
	var row := GridContainer.new()
	row.columns = 3
	mold_row = row
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
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
	ranking_title.text = "기존 점수 TOP 10 (읽기 전용)"
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
	save_label.text = "기존 랭킹을 읽지 못해 빈 목록으로 표시합니다. 파일은 변경하지 않습니다." if not ranking.load_message.is_empty() else ""
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
	if has_started or nickname_pending:
		return
	var error := DisplayServer.dialog_input_text("닉네임 입력", "한글·영문·숫자 1~12자\nOK를 누른 뒤 적용 또는 취소를 선택하세요.", nickname_input.text, _stage_nickname)
	if error != OK:
		validation_label.text = "닉네임 입력창을 열 수 없습니다. 다시 시도해 주세요."

func _stage_nickname(value: String) -> void:
	if has_started or nickname_pending:
		return
	pending_nickname = value
	nickname_pending = true
	var preview := value.strip_edges().left(24)
	nickname_confirmation.dialog_text = "입력한 닉네임: %s\n적용하시겠습니까? 취소하면 기존 이름을 유지합니다." % (preview if not preview.is_empty() else "(빈 값)")
	# The native callback runs before its modal dialog closes.
	_show_nickname_confirmation.call_deferred()

func _show_nickname_confirmation() -> void:
	if nickname_pending and not has_started:
		nickname_confirmation.popup_centered(Vector2i(540, 160))

func _cancel_nickname() -> void:
	pending_nickname = ""
	nickname_pending = false
	nickname_confirmation.hide()

func _confirm_nickname() -> void:
	if not nickname_pending:
		return
	var value := pending_nickname
	_cancel_nickname()
	_accept_nickname(value)

func _accept_nickname(value: String) -> void:
	if has_started:
		return
	nickname_input.text = value.strip_edges()
	validation_label.text = RankingStore.nickname_error(value)

func _start_round() -> void:
	if session.running or nickname_pending:
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

func _on_tool_pressed(tool: Session.Tool) -> void:
	var now := Time.get_ticks_usec()
	session.select_tool(tool, now)
	_finish_if_needed()
	_render(now)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var now := Time.get_ticks_usec()
		session.cancel_tool(now)
		_finish_if_needed()
		_render(now)

func _render(now: int) -> void:
	# Display only: a positive remainder must never round down to 00.0.
	var remaining_usec: int = session.remaining_usec(now) if has_started else Session.DURATION_USEC
	var remaining: float = ceili(remaining_usec / 100_000.0) / 10.0
	status_label.text = "남은 시간 %04.1f초" % remaining
	status_label.visible = has_started
	var ended: bool = has_started and not session.running
	var display_time: int = mini(now, session.started_at + Session.DURATION_USEC) if ended else now
	for index in mold_views.size():
		var message: String = session.feedback[index] if now - session.feedback_at[index] < 1_200_000 else ""
		mold_views[index].render(session.molds[index], index, display_time, session.running, message)
	result_label.text = "%s 님 · 시간 종료!\n조리 연습 완료 · 판매 및 기록 저장은 지원하지 않습니다." % player_nickname if ended else "60초 조리 연습 · 수거·판매 없이 굽기만 진행합니다."
	result_label.visible = not session.running
	tool_row.visible = session.running
	batter_button.set_pressed_no_signal(session.selected_tool == Session.Tool.BATTER)
	filling_button.set_pressed_no_signal(session.selected_tool == Session.Tool.FILLING)
	batter_button.disabled = not session.running
	filling_button.disabled = not session.running
	tool_status.text = "도구 없음 · 뒤집기 가능" if session.selected_tool == Session.Tool.NONE else "같은 도구 / 우클릭으로 해제"
	tool_cursor.text = "▰ 주전자 · 반죽" if session.selected_tool == Session.Tool.BATTER else "▱ 주걱 · 팥"
	tool_cursor.visible = session.running and session.selected_tool != Session.Tool.NONE
	tool_cursor.position = (get_local_mouse_position() + Vector2(18, 18)).clamp(Vector2.ZERO, (size - tool_cursor.size).max(Vector2.ZERO))
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
	# G001-B has no sales. Never append a zero score or rewrite legacy rankings.
	result_recorded = true
	save_label.text = "이번 연습은 랭킹에 저장하지 않습니다. 기존 기록은 유지됩니다."

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
