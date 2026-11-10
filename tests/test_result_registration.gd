extends SceneTree
const Store = preload("res://scripts/ranking_store.gd")
var checks := 0
var failures := 0
var directory: String
func _initialize() -> void:
	directory = "res://.tools/test-data/registration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func finish(main, amount: int) -> void:
	main.session.advance(main.session.started_at)
	main.session.revenue = amount
	main.session.advance(main.session.started_at + main.Session.DURATION_USEC)
	main._finish_if_needed()
	main._render(Time.get_ticks_usec())
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = directory.path_join("normal.json")
	main.easy_ranking_path = directory.path_join("easy.json")
	root.add_child(main)
	main.set_process(false)
	for mode in [0, 1]:
		main.final_design.modes[1 - mode].pressed.emit()
		check(main.difficulty_select.get_selected_id() == mode and main.ranking == (main.normal_ranking if mode == 0 else main.easy_ranking), "visible difficulty button routes selection and ranking")
		main.difficulty_select.select(mode)
		main.difficulty_select.item_selected.emit(mode)
		var store = main.ranking
		var other = main.easy_ranking if mode == 0 else main.normal_ranking
		var other_order: int = other.next_order
		for amount in [0, 1600]:
			main.action_button.pressed.emit()
			check(main.session.preparing and main.nickname_input.text.is_empty() and main.player_nickname.is_empty(), "unnamed start and fresh name state")
			main.save_button.pressed.emit()
			check(not main.result_recorded, "preparation cannot save")
			finish(main, amount)
			var before: int = store.next_order
			for i in 3: main._process(0)
			check(store.next_order == before and main.save_label.text.begins_with("미저장"), "end and UI refresh do not save")
			await process_frame
			for control in [main.nickname_row, main.save_button, main.leaderboard_panel, main.save_label, main.result_label, main.action_button, main.back_button]:
				check(control.visible and main.get_global_rect().encloses(control.get_global_rect()), "result control visible within viewport")
			check(not main.nickname_row.get_global_rect().intersects(main.save_button.get_global_rect()) and not main.save_button.get_global_rect().intersects(main.leaderboard_panel.get_global_rect()), "registration controls do not overlap")
			for invalid in ["", "  ", "1234567890123"]:
				main._accept_nickname(invalid)
				main.save_button.pressed.emit()
				check(not main.result_recorded and store.next_order == before and main.validation_label.visible, "invalid name cannot save")
			main._accept_nickname("  가나다라마바123456  ")
			main._stage_nickname("다른이름")
			await process_frame
			main.save_button.pressed.emit()
			check(not main.result_recorded, "pending confirmation cannot save")
			main.nickname_confirmation.canceled.emit()
			check(main.nickname_input.text == "가나다라마바123456", "cancel preserves twelve character name")
			var achieved: int = main.result_played_at
			DirAccess.make_dir_absolute(store.path + ".tmp")
			main.save_button.pressed.emit()
			check(not main.result_recorded and main.save_label.text.begins_with("기록 저장 실패:") and not main.save_button.disabled, "failed save permits retry")
			check(main.session.revenue == amount and main.nickname_input.text == "가나다라마바123456" and store.next_order == before, "failure preserves result name and records")
			main._process(0)
			check(main.save_label.text.begins_with("기록 저장 실패:"), "refresh preserves failure message")
			DirAccess.remove_absolute(store.path + ".tmp")
			main.save_button.pressed.emit()
			check(main.result_recorded and main.save_button.disabled and main.save_label.text == "기록 저장 완료", "explicit retry succeeds")
			var saved: String = FileAccess.get_file_as_string(store.path)
			for i in 3: main.save_button.pressed.emit()
			main._accept_nickname("저장후변경")
			check(FileAccess.get_file_as_string(store.path) == saved and store.next_order == before + 1, "double clicks never duplicate saved round")
			var record = store.records.filter(func(r): return r.order == before)[0]
			check(record.nickname == "가나다라마바123456" and record.score == amount and record.played_at == achieved, "saved values match result with original achievement timestamp")
			check(other.next_order == other_order, "other mode untouched")
			# A completed but unregistered round can be abandoned by either exit.
			for exit_to_start in [false, true]:
				main.action_button.pressed.emit()
				check(not main.result_recorded and main.nickname_input.text.is_empty(), "retry clears registration state")
				finish(main, 2000)
				main._accept_nickname("저장안함")
				if exit_to_start: main.back_button.pressed.emit()
				else:
					main.action_button.pressed.emit()
					finish(main, 0)
					main.back_button.pressed.emit()
				main.save_button.pressed.emit()
				main._stage_nickname("늦은콜백")
				check(not main.nickname_pending and FileAccess.get_file_as_string(store.path) == saved, "discarded result and stale callbacks never save")
				check(not main.nickname_row.visible and not main.save_button.visible, "lobby hides registration")
			main.difficulty_select.select(mode)
			main.difficulty_select.item_selected.emit(mode)
		var reload_store = Store.new(store.path)
		reload_store.load_records()
		check(reload_store.records == store.records and reload_store.records.size() == 2, "separate zero and nonzero records survive reopening")
	main.queue_free()
	await process_frame
	print("RESULT REGISTRATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
