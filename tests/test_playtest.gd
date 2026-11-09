extends SceneTree
const Session = preload("res://scripts/cooking_session.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
const Store = preload("res://scripts/ranking_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func recipe(s, index: int, at: int) -> void:
	s.board.add_batter(index, at)
	s.board.add_filling(index, at + 1)
	s.board.add_batter(index, at + 2)
func sale(s, at: int, burnt: bool = false) -> void:
	for index in 3:
		recipe(s, index, at)
		if not burnt:
			s.board.flip(index, at + 5_000_000)
	for index in 3:
		s.collect(index, at + (10_000_000 if burnt else 8_000_000))
	var token: int = s.bag.id
	check(s.sell_bag(token, at + 10_000_000).sold, "sale fixture succeeds")
	check(not s.sell_bag(token, at + 10_000_001).sold, "duplicate sale rejected")
func run() -> void:
	for seconds in [60, 90]:
		var duration: int = seconds * 1_000_000
		for offset in [-1, 0, 1]:
			for action in ["advance", "click", "collect", "sell", "tool"]:
				var s = Session.new()
				s.start(0, seconds)
				s.bag.try_add(Mold.Quality.BURNT)
				s.bag.try_add(Mold.Quality.BURNT)
				s.bag.try_add(Mold.Quality.BURNT)
				s.board.add_batter(0, 0)
				var token: int = s.bag.id
				match action:
					"advance": s.advance(duration + offset)
					"click": s.click_mold(0, duration + offset)
					"collect": s.collect(0, duration + offset)
					"sell": s.sell_bag(token, duration + offset)
					"tool": s.select_tool(Session.Tool.BATTER, duration + offset)
				check(s.running == (offset < 0) and s.remaining_usec(duration + offset) == (1 if offset < 0 else 0), "exact duration boundary for " + action)
				if offset >= 0:
					check(s.end_bag_items == 3 and s.end_mold_items == 1 and s.sold_bags == 0, "snapshot before clear and before deadline input")
					check(s.bag.items.is_empty() and s.molds[0].state == Mold.State.EMPTY, "normal end cleanup unchanged")
		var s = Session.new()
		s.start(0, seconds)
		check(s.is_playtest and s.duration_usec == duration, "explicit test duration")
		sale(s, 0)
		sale(s, 12_000_000, true)
		check(s.revenue == 2000 and s.sold_bags == 2, "same price and zero sale counts as a successful bag")
		# Build one of every non-empty state plus a two-item unsold bag.
		s.bag.try_add(Mold.Quality.NORMAL)
		s.bag.try_add(Mold.Quality.BURNT)
		var at: int = duration - 1_000_000
		s.board.add_batter(0, at)
		s.board.add_batter(1, at)
		s.board.add_filling(1, at)
		recipe(s, 2, at)
		recipe(s, 3, duration - 7_000_000)
		s.board.flip(3, duration - 2_000_000)
		recipe(s, 4, duration - 9_000_000)
		s.board.flip(4, duration - 4_000_000)
		s.board.add_batter(5, duration - 11_000_000)
		s.advance(duration - 1)
		check(s.molds.map(func(m): return m.state) == [Mold.State.FIRST_BATTER, Mold.State.FILLING_ADDED, Mold.State.SIDE_1, Mold.State.SIDE_2, Mold.State.READY, Mold.State.BURNT], "all leftover states fixture")
		s.advance(duration + 5_000_000)
		check(s.end_bag_items == 2 and s.end_mold_items == 6 and s.sold_bags == 2 and s.revenue == 2000, "late frame captures leftovers and completed revenue")
		s.advance(duration + 6_000_000)
		check(s.end_bag_items == 2 and s.end_mold_items == 6, "duplicate end preserves snapshot")
		s.start(duration, seconds)
		check(s.sold_bags == 0 and s.end_bag_items == 0 and s.end_mold_items == 0 and s.revenue == 0, "retry resets metrics")
		s.start(0)
		check(not s.is_playtest and s.duration_usec == 60_000_000, "default formal duration stays sixty")
	await test_ui()
	print("G004-A TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func test_ui() -> void:
	var directory := "res://.tools/test-data/playtest-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("rankings.json")
	var store = Store.new(path)
	store.add_result("정식기록", 5600, 1)
	var original := FileAccess.get_file_as_string(path)
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = path
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "테스트장인"
	check(main.mode_select.selected == 0, "formal mode selected by default")
	for selection in [1, 2]:
		var seconds: int = 60 if selection == 1 else 90
		main.mode_select.select(selection)
		main.action_button.pressed.emit()
		check(main.session.is_playtest and main.session.duration_usec == seconds * 1_000_000 and not main.mode_select.visible, "UI selected test duration fixed for round")
		main.session.start(0, seconds)
		sale(main.session, 0)
		main.session.bag.try_add(Mold.Quality.BURNT)
		main.session.board.add_batter(0, 20_000_000)
		main.session.advance(seconds * 1_000_000 - 1)
		main._render(seconds * 1_000_000 - 1)
		check(main.status_label.text.contains("00.1초") and main.status_label.text.contains("테스트"), "test countdown still rounds positive up")
		main.session.advance(seconds * 1_000_000)
		main._finish_if_needed()
		main._render(seconds * 1_000_000)
		check(main.result_label.text == main.playtest_report() and main.result_label.text.contains("%d초" % seconds), "actual result and copied report share duration")
		check(main.playtest_report().contains("봉투 1개") and main.playtest_report().contains("2000원") and main.playtest_report().contains("봉투 속 1개") and main.playtest_report().contains("붕어빵 1개"), "all requested metrics displayed")
		check(main.copy_result_button.visible and not main.leaderboard_panel.visible and main.save_label.text.contains("저장하지"), "result clearly separated from leaderboard")
		await process_frame
		check(main.get_global_rect().encloses(main.copy_result_button.get_global_rect()) and main.get_global_rect().encloses(main.back_button.get_global_rect()), "test result and controls fit")
		for repeat in 3:
			main._finish_if_needed()
		check(FileAccess.get_file_as_string(path) == original and main.ranking.records.size() == 1, "test never alters currency file")
		main.action_button.pressed.emit()
		check(main.session.is_playtest and main.session.duration_usec == seconds * 1_000_000 and main.session.sold_bags == 0, "retry keeps selected test duration and clears metrics")
		main.session.advance(main.session.started_at + main.session.duration_usec)
		main._finish_if_needed()
		main.back_button.pressed.emit()
		check(main.mode_select.visible, "return permits choosing comparison duration")
	main.mode_select.select(0)
	main.action_button.pressed.emit()
	check(not main.session.is_playtest and main.session.duration_usec == 60_000_000, "formal mode still starts sixty")
	main.session.advance(main.session.started_at + main.session.duration_usec)
	main._finish_if_needed()
	check(main.ranking.records.size() == 2 and main.save_label.text == "기록 저장 완료", "formal result still saved")
	main.queue_free()
	await process_frame
	# Test mode must not create even a missing ranking file.
	main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = directory.path_join("missing.json")
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "빈기록검사"
	main.mode_select.select(2)
	main.action_button.pressed.emit()
	main.session.bag.try_add(Mold.Quality.BURNT)
	main.session.bag.try_add(Mold.Quality.BURNT)
	main.session.bag.try_add(Mold.Quality.BURNT)
	main.begin_bag_drag(Time.get_ticks_usec())
	main.session.started_at = Time.get_ticks_usec() - main.session.duration_usec
	main._process(0)
	check(main.session.end_bag_items == 3 and not main.dragging and main.session.bag.items.is_empty(), "dragging full bag counted before end clear")
	check(not FileAccess.file_exists(main.ranking_path), "test creates no ranking file")
	main.queue_free()
	await process_frame
