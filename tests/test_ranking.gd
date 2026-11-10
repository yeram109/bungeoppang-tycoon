extends SceneTree

const Store = preload("res://scripts/ranking_store.gd")
const Session = preload("res://scripts/cooking_session.gd")
var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = "res://.tools/test-data/ranking-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func path_for(name: String) -> String:
	return directory.path_join(name + ".json")

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func run() -> void:
	test_names()
	test_ranking()
	test_corruption()
	test_io_failures()
	await test_ui()
	await test_nickname_cancel()
	print("F002 TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_names() -> void:
	for name in ["", " ", "\t\n", "가나다라마바사아자차카타파", "1234567890123", "ab\ncd"]:
		check(not Store.nickname_error(name).is_empty(), "reject invalid nickname")
	for name in ["한글", "ABC", "123", "한글ABC123", "  장인  ", "가나다라마바사아자차카타", "123456789012", "a"]:
		check(Store.nickname_error(name).is_empty(), "accept valid nickname " + name)

func test_nickname_cancel() -> void:
	var main = make_main(path_for("nickname-cancel"))
	main._stage_nickname("붕어빵장인")
	await process_frame
	check(main.nickname_confirmation.visible and main.nickname_input.text.is_empty(), "draft does not change empty nickname")
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(not main.session.running, "cannot start while confirmation pending")
	main.nickname_confirmation.canceled.emit()
	check(main.nickname_input.text.is_empty() and not main.nickname_pending and not main.nickname_confirmation.visible, "cancel returns to empty start screen")
	main._stage_nickname("  붕어빵장인  ")
	await process_frame
	main.nickname_confirmation.confirmed.emit()
	check(main.nickname_input.text == "붕어빵장인" and not main.nickname_pending, "confirm after cancel applies trimmed Korean name")
	for draft in ["겨울장인", "", "   ", "가나다라마바사아자차카타파"]:
		main._stage_nickname(draft)
		await process_frame
		main.nickname_confirmation.canceled.emit()
		check(main.nickname_input.text == "붕어빵장인" and main.validation_label.text.is_empty(), "cancel changed draft preserves nickname and validation")
	main.nickname_confirmation.confirmed.emit()
	check(main.nickname_input.text == "붕어빵장인", "stale confirmation after cancel cannot apply draft")
	for invalid in ["", "   ", "가나다라마바사아자차카타파"]:
		main._stage_nickname(invalid)
		await process_frame
		main.nickname_confirmation.confirmed.emit()
		main.action_button.pressed.emit()
		complete_preparation(main)
		check(not main.session.running and not main.validation_label.text.is_empty(), "confirmed invalid draft still blocks start")
	main._stage_nickname("겨울장인")
	await process_frame
	main.nickname_confirmation.confirmed.emit()
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.session.running and main.player_nickname == "겨울장인", "confirmed change becomes session name")
	main._stage_nickname("늦은입력")
	check(not main.nickname_pending and main.player_nickname == "겨울장인", "running session rejects late draft")
	end_round(main)
	check(main.result_label.text.contains("겨울장인") and main.ranking.records[0].nickname == "겨울장인", "confirmed name reaches saved currency record")
	main.queue_free()
	await process_frame

func test_ranking() -> void:
	var path := path_for("sorting")
	var store = Store.new(path)
	store.load_records()
	check(store.records.is_empty() and store.load_message.is_empty(), "missing file starts empty")
	check(store.add_result("  장인  ", 0, 1000), "zero score saves")
	check(store.records[0].nickname == "장인", "stored name is trimmed")
	check(store.add_result("장인", 100, 3000), "same nickname separate play")
	check(store.add_result("영문ABC", 100, 2000), "different nickname and earlier time")
	check(store.add_result("동시1", 100, 2000) and store.add_result("동시2", 100, 2000), "same timestamp plays save")
	check(store.records.map(func(r): return r.nickname) == ["영문ABC", "동시1", "동시2", "장인", "장인"], "score/time/order sorting")
	var reloaded = Store.new(path)
	reloaded.load_records()
	check(reloaded.records == store.records and reloaded.next_order == store.next_order, "fresh store restores exact records and sequence")
	check(reloaded.add_result("동시3", 100, 2000), "same timestamp after reload")
	check(reloaded.records[3].nickname == "동시3", "tie sequence survives reload")
	for index in 12:
		check(reloaded.add_result("플레이%d" % index, 200 + index, 4000 + index), "more than ten plays")
	check(reloaded.records.size() == 10, "only top ten kept")
	check(reloaded.records[0].score == 211 and reloaded.records[9].score == 202, "correct top ten descending")
	check(reloaded.best_score() == 211, "PC high score")
	var final_store = Store.new(path)
	final_store.load_records()
	check(final_store.records == reloaded.records, "top ten persisted")
	check(not FileAccess.file_exists(path + ".tmp"), "successful replace consumes staging file")

func test_corruption() -> void:
	var invalid := ["not json", "", "null", "[]", "{}", '{"version":3,"records":[],"next_order":0}']
	var valid_record := {"nickname": "정상", "score": 60, "played_at": 1000, "order": 0}
	for field in ["nickname", "score", "played_at", "order"]:
		var record := valid_record.duplicate()
		record[field] = null
		invalid.append(JSON.stringify({"version": Store.VERSION, "next_order": 1, "records": [record]}))
	for score in [-1, 0.5, "100"]:
		var record := valid_record.duplicate()
		record.score = score
		invalid.append(JSON.stringify({"version": Store.VERSION, "next_order": 1, "records": [record]}))
	invalid.append(JSON.stringify({"version": Store.VERSION, "next_order": 0, "records": [valid_record]}))
	invalid.append(JSON.stringify({"version": Store.VERSION, "next_order": 1, "records": [valid_record, valid_record]}))
	for index in invalid.size():
		var path := path_for("corrupt%d" % index)
		write_text(path, invalid[index])
		var store = Store.new(path)
		store.load_records()
		check(store.records.is_empty() and not store.load_message.is_empty(), "invalid JSON/schema recovers empty")
		check(FileAccess.get_file_as_string(path) == invalid[index], "load does not destroy corrupt input")
		check(store.add_result("복구", 0, 100), "new result repairs corrupt file safely")
		var reload_store = Store.new(path)
		reload_store.load_records()
		check(reload_store.records.size() == 1 and reload_store.load_message.is_empty(), "repaired JSON readable")

func test_io_failures() -> void:
	var read_path := path_for("unreadable-directory")
	DirAccess.make_dir_absolute(read_path)
	var unreadable = Store.new(read_path)
	unreadable.load_records()
	check(unreadable.records.is_empty() and not unreadable.load_message.is_empty(), "read failure handled")
	check(not unreadable.add_result("읽기실패", 0, 0), "read failure cannot overwrite unknown data")
	var unavailable = Store.new(directory.path_join("missing-parent/rankings.json"))
	unavailable.load_records()
	check(not unavailable.add_result("경로실패", 60, 0) and not unavailable.last_error.is_empty(), "unavailable path fails safely")
	var path := path_for("preserve")
	var store = Store.new(path)
	store.load_records()
	check(store.add_result("기존", 60, 1000), "baseline normal save")
	var before := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	check(not store.add_result("실패", 100, 2000), "staging write failure reported")
	check(FileAccess.get_file_as_string(path) == before and store.records.size() == 1, "failed write preserves disk and memory")
	DirAccess.remove_absolute(path + ".tmp")
	check(store.add_result("재개", 100, 3000), "next play saves after write failure fixed")
	if OS.get_name() == "Windows":
		before = FileAccess.get_file_as_string(path)
		check(FileAccess.set_read_only_attribute(path, true) == OK, "protect test-only existing file")
		check(not store.add_result("읽기전용", 200, 4000), "read-only destination refuses replacement")
		check(FileAccess.get_file_as_string(path) == before and store.records.size() == 2, "replacement failure preserves valid existing data")
		FileAccess.set_read_only_attribute(path, false)
		check(store.add_result("권한복구", 200, 5000), "saving resumes after permission restored")
	var replacement = Store.new(path_for("replace-failure"))
	replacement.load_records()
	DirAccess.make_dir_absolute(replacement.path)
	check(not replacement.add_result("교체실패", 60, 1000) and replacement.records.is_empty(), "replacement failure is not reported as success")

func make_main(path: String) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = path
	root.add_child(main)
	main.set_process(false)
	return main

func end_round(main: Node) -> void:
	main.session.started_at = Time.get_ticks_usec() - Session.DURATION_USEC
	main._process(0.0)

func test_ui() -> void:
	var path := path_for("ui")
	var main = make_main(path)
	main._accept_nickname("  ")
	check(main.nickname_input.text.is_empty() and not main.validation_label.text.is_empty(), "native dialog empty callback validates")
	main._accept_nickname("가나다라마바사아자차카타파")
	check(not main.validation_label.text.is_empty(), "native dialog long nickname rejected")
	main._accept_nickname("  한글장인  ")
	check(main.nickname_input.text == "한글장인" and main.validation_label.text.is_empty(), "native dialog Korean callback trims without losing syllables")
	main.nickname_input.text = ""
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(not main.session.running and not main.validation_label.text.is_empty(), "AC01 empty name blocked")
	main.nickname_input.text = "   "
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(not main.session.running, "whitespace name blocked by UI")
	main.nickname_input.text = "가나다라마바사아자차카타파"
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(not main.session.running, "long UI input rejected")
	main.nickname_input.text = "  한글장인12  "
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.session.running and main.player_nickname == "한글장인12", "AC02 Korean name starts and trims")
	main._accept_nickname("다른이름")
	check(main.nickname_input.text == "한글장인12", "late dialog callback cannot change running session")
	check(main.nickname_input.text == main.player_nickname and not main.leaderboard_panel.visible, "nickname fixed for session")
	end_round(main)
	check(main.result_label.text.contains("한글장인12") and main.result_label.text.contains("시간 종료!"), "result keeps session nickname")
	check(main.save_label.text == "기록 저장 완료" and main.ranking.records.size() == 1 and main.ranking.records[0].score == 0, "zero currency round saves once")
	for repeat in 5:
		main._process(0.0)
		main._finish_if_needed()
		main._on_mold_clicked(0)
	check(main.ranking.records.size() == 1 and main.ranking.next_order == 1, "repeat finish/frame/input cannot duplicate record")
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.session.running and main.player_nickname == "한글장인12", "retry keeps nickname")
	end_round(main)
	main.back_button.pressed.emit()
	check(not main.has_started and main.nickname_row.visible and main.leaderboard_panel.visible, "return to start and existing leaderboard")
	main.queue_free()
	await process_frame
	# Seed an isolated TOP 10 fixture and verify currency saves through the real UI.
	var fixture = Store.new(path)
	for index in 12:
		fixture.add_result("가나다라마바사아자차카타", 200 + index, index)
	var before := FileAccess.get_file_as_string(path)
	main = make_main(path)
	check(main.ranking.records.size() == 10 and main.leaderboard_rows.get_child_count() == 10, "currency top ten restored")
	await process_frame
	check(main.get_global_rect().encloses(main.action_button.get_global_rect()), "start controls fit with ten long names")
	main.nickname_input.text = "한글장인"
	for repeat in 3:
		main.action_button.pressed.emit()
		complete_preparation(main)
		end_round(main)
		main.back_button.pressed.emit()
	check(FileAccess.get_file_as_string(path) != before and main.ranking.records.size() == 10 and main.ranking.next_order == 15, "multiple rounds save separately and retain top ten")
	main.action_button.pressed.emit()
	complete_preparation(main)
	end_round(main)
	await process_frame
	check(main.get_global_rect().encloses(main.back_button.get_global_rect()), "result controls fit with ten long names")
	var scroll = main.leaderboard_rows.get_parent()
	var last_row = main.leaderboard_rows.get_child(9)
	check(scroll.get_global_rect().encloses(last_row.get_global_rect()) or scroll.get_v_scroll_bar().max_value > scroll.size.y, "all ten rows fit or remain accessible by scrolling")
	main.queue_free()
	await process_frame
	var corrupt_path := path_for("ui-corrupt")
	write_text(corrupt_path, "broken JSON")
	main = make_main(corrupt_path)
	check(not main.save_label.text.is_empty(), "load failure still informs user")
	main.nickname_input.text = "복구검사"
	main.action_button.pressed.emit()
	complete_preparation(main)
	end_round(main)
	check(JSON.parse_string(FileAccess.get_file_as_string(corrupt_path)).version == Store.VERSION and main.ranking.records.size() == 1, "completed round repairs corrupt file")
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.session.running, "load failure does not prevent retry")
	main.queue_free()
	await process_frame

func complete_preparation(main) -> void:
	if main.session.preparing:
		main.session.advance(main.session.started_at)
		main.session.started_at = Time.get_ticks_usec()
		main._render(Time.get_ticks_usec())
