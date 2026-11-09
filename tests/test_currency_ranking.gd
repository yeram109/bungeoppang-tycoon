extends SceneTree
const Store = preload("res://scripts/ranking_store.gd")
const Session = preload("res://scripts/cooking_session.gd")
var checks := 0
var failures := 0
var directory: String
func _initialize() -> void:
	directory = "res://.tools/test-data/currency-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
func legacy() -> String:
	return JSON.stringify({"version": 1, "next_order": 2, "records": [{"nickname": "옛점수", "score": 100, "played_at": 1, "order": 0}, {"nickname": "옛점수", "score": 60, "played_at": 2, "order": 1}]})
func run() -> void:
	for failure in ["none", "staging", "replace"]:
		var path := directory.path_join(failure + ".json")
		write(path, legacy())
		if failure == "staging":
			DirAccess.make_dir_absolute(path + ".tmp")
		if failure == "replace":
			FileAccess.set_read_only_attribute(path, true)
		var s = Store.new(path)
		s.load_records()
		check(s.records.is_empty() and s.next_order == 0 and s.best_score() == 0, "legacy never leaks into currency")
		if failure == "none":
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			check(data.version == 2 and data.records.is_empty() and data.next_order == 0, "startup replaces legacy with empty version 2")
			check(s.load_message.contains("전환했습니다"), "migration success reported")
		else:
			check(FileAccess.get_file_as_string(path) == legacy(), "failed migration leaves legacy bytes intact")
			check(s.load_message.contains("실패") and not s.load_message.contains("전환했습니다"), "no false migration success")
			check(not s.add_result("새기록", 2000, 10), "result save still reports failure")
			check(FileAccess.get_file_as_string(path) == legacy() and s.records.is_empty(), "failed result cannot mix or corrupt legacy")
			if failure == "staging":
				DirAccess.remove_absolute(path + ".tmp")
			else:
				FileAccess.set_read_only_attribute(path, false)
		check(s.add_result("새기록", 1600, 10), "migration or retry saves currency result")
		var reloaded = Store.new(path)
		reloaded.load_records()
		check(reloaded.records.size() == 1 and reloaded.records[0].score == 1600 and reloaded.records[0].nickname == "새기록", "reload only currency")
		check(reloaded.load_message.is_empty() and reloaded.next_order == 1, "version 2 not migrated again")
		check(reloaded.add_result("새기록", 0, 11), "same nickname zero currency is distinct")
		check(reloaded.records.size() == 2 and reloaded.records[1].score == 0, "zero retained")
	await test_ui()
	print("G003-A TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func make_main(path: String):
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = path
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "원화장인"
	return main
func sell(main) -> void:
	# Prepare using actual cooking APIs, sell through the same UI drop path.
	var now := Time.get_ticks_usec()
	main.session.start(now - 14_000_000)
	for index in 3:
		main.session.board.add_batter(index, now - 13_000_000)
		main.session.board.add_filling(index, now - 13_000_000)
		main.session.board.add_batter(index, now - 13_000_000)
		main.session.board.flip(index, now - 5_000_000)
		main.click_mold_at(index, now)
	main.begin_bag_drag(now)
	main.drop_bag_at(main.sale_zone.get_global_rect().get_center(), now)
func finish(main) -> void:
	main.session.started_at = Time.get_ticks_usec() - Session.DURATION_USEC
	main._process(0)
func test_ui() -> void:
	var path := directory.path_join("ui.json")
	write(path, legacy())
	var main = make_main(path)
	check(main.ranking.records.is_empty() and main.save_label.text.contains("전환"), "UI migrates without legacy display")
	main.action_button.pressed.emit()
	complete_preparation(main)
	await process_frame
	sell(main)
	check(main.session.revenue == 2000 and main.ranking.records.is_empty(), "sale revenue not saved before end")
	finish(main)
	check(main.ranking.records.size() == 1 and main.ranking.records[0].score == 2000, "end saves actual sale revenue")
	check(main.result_label.text.contains("총 판매 금액 2000원") and main.result_label.text.contains("최고 판매 금액 2000원"), "result and best use currency")
	check(main.leaderboard_rows.get_child(0).text.contains("2000원") and main.save_label.text == "기록 저장 완료", "ranking and success visible")
	var bytes := FileAccess.get_file_as_string(path)
	for index in 5:
		main._finish_if_needed()
		main._process(0)
		main._on_mold_clicked(0)
		main.drop_bag_at(Vector2.ZERO, Time.get_ticks_usec())
	check(FileAccess.get_file_as_string(path) == bytes and main.ranking.next_order == 1, "duplicate events do not save")
	main.back_button.pressed.emit()
	check(FileAccess.get_file_as_string(path) == bytes, "return to start does not save")
	main.queue_free()
	await process_frame
	main = make_main(path)
	check(main.ranking.records.size() == 1 and main.ranking.best_score() == 2000, "new scene restores exact sale")
	main.action_button.pressed.emit()
	complete_preparation(main)
	finish(main)
	check(main.ranking.records.size() == 2 and main.ranking.records[1].score == 0, "new session zero saves once")
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.session.revenue == 0 and not main.result_recorded, "retry resets revenue and save guard")
	DirAccess.make_dir_absolute(path + ".tmp")
	bytes = FileAccess.get_file_as_string(path)
	sell(main)
	finish(main)
	check(main.save_label.text.begins_with("기록 저장 실패:") and main.result_label.text.contains("2000원"), "save failure preserves playable result")
	check(FileAccess.get_file_as_string(path) == bytes and main.ranking.next_order == 2, "failed round preserves disk and memory")
	DirAccess.remove_absolute(path + ".tmp")
	main._finish_if_needed()
	check(FileAccess.get_file_as_string(path) == bytes, "failed round is not retried by UI refresh")
	main.action_button.pressed.emit()
	complete_preparation(main)
	finish(main)
	check(main.save_label.text == "기록 저장 완료" and main.ranking.next_order == 3, "next round can save after failure")
	main.queue_free()
	await process_frame

func complete_preparation(main) -> void:
	if main.session.preparing:
		main.session.advance(main.session.started_at)
		main.session.started_at = Time.get_ticks_usec()
		main._render(Time.get_ticks_usec())
