extends SceneTree
const Store = preload("res://scripts/ranking_store.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
const D = Mold.Difficulty
var checks := 0
var failures := 0
var directory: String
func _initialize() -> void:
	directory = "res://.tools/test-data/difficulty-rankings-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func path_for(name: String) -> String:
	return directory.path_join(name + ".json")
func write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
func make_main(normal: String, easy: String):
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = normal
	main.easy_ranking_path = easy
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "같은닉네임"
	return main
func select_mode(main, mode: int) -> void:
	main.difficulty_select.select(mode)
	main.difficulty_select.item_selected.emit(mode)
func finish(main, revenue: int = 0) -> void:
	main.session.advance(main.session.started_at)
	main.session.revenue = revenue
	main.session.advance(main.session.started_at + main.Session.DURATION_USEC)
	main._finish_if_needed()
	main._render(main.session.started_at + main.Session.DURATION_USEC)
func run() -> void:
	await test_sorting_and_views()
	await test_round_routing()
	for broken_mode in [D.NORMAL, D.EASY]:
		for problem in ["missing", "corrupt", "structure", "read", "write", "replace", "path"]:
			await test_isolation(broken_mode, problem)
	print("G005-B TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func test_sorting_and_views() -> void:
	var paths := [path_for("sort-normal"), path_for("sort-easy")]
	var stores := [Store.new(paths[0]), Store.new(paths[1])]
	for mode in [D.NORMAL, D.EASY]:
		var s = stores[mode]
		s.load_records()
		check(s.records.is_empty() and not FileAccess.file_exists(paths[mode]), "missing file starts empty without creating it")
		for sample in [[0, 1], [1000, 20], [1000, 10], [1000, 10]]:
			check(s.add_result("같은닉네임", sample[0], sample[1]), "same nickname individual results including zero")
		check(s.records.size() == 4 and s.records[3].score == 0, "zero round retained independently")
		check(s.records[0].order == 2 and s.records[1].order == 3 and s.records[2].order == 1, "ties use earlier time then stable order")
		for i in range(11):
			check(s.add_result("가나다라마바사아자차카타", 2000 + i * 100 + mode * 10000, 100 + i), "fill separate top tens")
		check(s.records.size() == 10 and s.best_score() == 3000 + mode * 10000, "each top ten and best independent")
		for i in range(9):
			check(s.records[i].score >= s.records[i + 1].score, "descending score")
	var bytes := [FileAccess.get_file_as_string(paths[0]), FileAccess.get_file_as_string(paths[1])]
	var main = make_main(paths[0], paths[1])
	await process_frame
	for mode in [D.NORMAL, D.EASY, D.NORMAL, D.EASY]:
		select_mode(main, mode)
		await process_frame
		check(main.ranking.records == stores[mode].records and main.leaderboard_rows.get_child_count() == 10, "selection shows only that mode's ten rows")
		check(main.ranking_title.text.begins_with(Mold.difficulty_name(mode)) and main.ranking_title.text.contains(str(3000 + mode * 10000)), "title includes selected mode and best")
		check(main.leaderboard_rows.get_child(0).text.contains(str(3000 + mode * 10000)), "top row uses selected score")
		check(main.get_global_rect().encloses(main.action_button.get_global_rect()), "ten long names fit start screen")
	check(FileAccess.get_file_as_string(paths[0]) == bytes[0] and FileAccess.get_file_as_string(paths[1]) == bytes[1], "loading and switching never rewrite either file")
	main.queue_free()
	await process_frame
func test_round_routing() -> void:
	var normal := path_for("round-normal")
	var easy := path_for("round-easy")
	var original = Store.new(normal)
	check(original.add_result("기존일반", 5200, 1), "seed unchanged normal data")
	var normal_bytes := FileAccess.get_file_as_string(normal)
	var main = make_main(normal, easy)
	for mode in [D.EASY, D.NORMAL]:
		select_mode(main, mode)
		main.action_button.pressed.emit()
		check(main.session.preparing and main.ranking == (main.easy_ranking if mode == D.EASY else main.normal_ranking), "start selects mode store during preparation")
		# Hidden selector manipulation must not redirect result or retry.
		select_mode(main, 1 - mode)
		finish(main, 4900 if mode == D.EASY else 5300)
		var s = main.easy_ranking if mode == D.EASY else main.normal_ranking
		var other = main.normal_ranking if mode == D.EASY else main.easy_ranking
		var current_bytes := FileAccess.get_file_as_string(s.path)
		var other_bytes := FileAccess.get_file_as_string(other.path)
		check(main.save_label.text == "기록 저장 완료" and main.ranking == s, "end stores fixed round mode regardless of selector")
		check(main.result_label.text.contains("최고 판매 금액 %d원" % s.best_score()) and main.ranking_title.text.begins_with(Mold.difficulty_name(mode)), "result best and top ten from correct store")
		if mode == D.EASY:
			check(FileAccess.get_file_as_string(normal) == normal_bytes, "first easy result leaves preexisting normal bytes unchanged")
		for i in 4:
			main._finish_if_needed()
			main._process(0)
		check(FileAccess.get_file_as_string(s.path) == current_bytes and FileAccess.get_file_as_string(other.path) == other_bytes, "duplicate finish writes neither file")
		main.action_button.pressed.emit()
		check(main.session.difficulty == mode and main.session.preparing, "retry preserves mode")
		finish(main)
		check(s.records[-1].score == 0 and s.records[-1].nickname == "같은닉네임", "retry zero saved separately in same mode")
		check(FileAccess.get_file_as_string(other.path) == other_bytes, "retry never alters other mode")
		main.back_button.pressed.emit()
		check(main.save_label.text.is_empty(), "lobby has no stale save success")
	var normal_records: Array = main.normal_ranking.records.duplicate(true)
	var easy_records: Array = main.easy_ranking.records.duplicate(true)
	check(normal_records.size() == 3 and easy_records.size() == 2, "independent record counts")
	check(normal_records[1] == original.records[0], "original normal record fields intact")
	main.queue_free()
	await process_frame
	main = make_main(normal, easy)
	check(main.normal_ranking.records == normal_records and main.easy_ranking.records == easy_records, "both stores restore exact records in fresh scene")
	main.queue_free()
	await process_frame
func test_isolation(broken_mode: int, problem: String) -> void:
	var paths := [path_for("%d-%s-normal" % [broken_mode, problem]), path_for("%d-%s-easy" % [broken_mode, problem])]
	var bad_path: String = paths[broken_mode]
	var good_path: String = paths[1 - broken_mode]
	var good = Store.new(good_path)
	good.add_result("정상", 1600, 1)
	var good_bytes := FileAccess.get_file_as_string(good_path)
	if problem in ["write", "replace"]:
		Store.new(bad_path).add_result("보호", 1000, 1)
		if problem == "write": DirAccess.make_dir_absolute(bad_path + ".tmp")
		else: FileAccess.set_read_only_attribute(bad_path, true)
	elif problem == "corrupt": write(bad_path, "{broken")
	elif problem == "structure": write(bad_path, '{"version":2,"records":"wrong"}')
	elif problem == "read": DirAccess.make_dir_absolute(bad_path)
	elif problem == "path":
		paths[broken_mode] = directory.path_join("absent-%d/sub/rankings.json" % broken_mode)
		bad_path = paths[broken_mode]
	var bad_bytes := FileAccess.get_file_as_string(bad_path) if FileAccess.file_exists(bad_path) else ""
	var main = make_main(paths[0], paths[1])
	select_mode(main, broken_mode)
	if problem in ["corrupt", "structure", "read"]:
		check(not main.save_label.text.is_empty(), "selected broken store reports its own load issue")
	main.action_button.pressed.emit()
	finish(main, 2000)
	var fails: bool = problem in ["read", "write", "replace", "path"]
	check(main.save_label.text.begins_with("기록 저장 실패:") if fails else main.save_label.text == "기록 저장 완료", "correct write/recovery outcome")
	check(main.result_label.text.contains("2000원"), "result remains available even on failure")
	check(FileAccess.get_file_as_string(good_path) == good_bytes, "bad/missing store round leaves healthy file untouched")
	if problem in ["write", "replace"]:
		check(FileAccess.get_file_as_string(bad_path) == bad_bytes, "failed write preserves destination bytes")
		if problem == "write": DirAccess.remove_absolute(bad_path + ".tmp")
		else: FileAccess.set_read_only_attribute(bad_path, false)
	elif problem in ["corrupt", "structure", "missing"]:
		check(JSON.parse_string(FileAccess.get_file_as_string(bad_path)).records[0].score == 2000, "missing/corrupt file recovered only in its own store")
	main.back_button.pressed.emit()
	select_mode(main, 1 - broken_mode)
	check(main.save_label.text.is_empty() and main.ranking.best_score() == 1600, "healthy selection has no other mode's error")
	main.action_button.pressed.emit()
	finish(main, 3000)
	check(main.save_label.text == "기록 저장 완료" and main.ranking.best_score() == 3000, "healthy mode can still save normally")
	if problem in ["write", "replace"]:
		main.back_button.pressed.emit()
		select_mode(main, broken_mode)
		main.action_button.pressed.emit()
		finish(main, 4000)
		check(main.save_label.text == "기록 저장 완료" and main.ranking.best_score() == 4000, "next round recovers after write problem removed")
	main.queue_free()
	await process_frame
