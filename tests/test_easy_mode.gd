extends SceneTree
const Mold = preload("res://scripts/cooking_mold.gd")
const Session = preload("res://scripts/cooking_session.gd")
const Store = preload("res://scripts/ranking_store.gd")
const D = Mold.Difficulty
const Q = Mold.SideQuality
const P = Mold.Quality
var checks := 0
var failures := 0
var directory: String
func _initialize() -> void:
	directory = "res://.tools/test-data/easy-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func recipe(m, at: int) -> void:
	m.add_batter(at)
	m.add_filling(at + 1)
	m.add_batter(at + 2)
func run() -> void:
	var view = load("res://scenes/cooking_mold.tscn").instantiate()
	root.add_child(view)
	for mode in [D.NORMAL, D.EASY]:
		var limits: Array = [[5_000_000, 7_000_000, 9_000_000], [3_000_000, 4_500_000, 6_000_000]] if mode == D.NORMAL else [[5_000_000, 8_000_000, 12_000_000], [3_000_000, 5_000_000, 8_000_000]]
		for side in [0, 1]:
			for boundary in 3:
				for offset in [-1, 0, 1]:
					var expected: int = [[Q.COOKING, Q.NORMAL, Q.NORMAL], [Q.NORMAL, Q.NORMAL, Q.PERFECT], [Q.PERFECT, Q.PERFECT, Q.BURNT]][boundary][offset + 1]
					var elapsed: int = limits[side][boundary] + offset
					var m = Mold.new(mode)
					recipe(m, 0)
					var origin: int = 0
					if side == 1:
						origin = limits[0][1] + 1
						m.flip(origin)
					m.advance(origin + elapsed)
					view.render(m, 0, origin + elapsed, true)
					check(m.difficulty == mode, "mold carries selected difficulty")
					check(view.cook_button.text.begins_with("%d면 · %s" % [side + 1, ["조리 중", "완벽", "일반", "탐"][expected]]), "actual UI matches mode boundary")
					check(is_equal_approx(view.progress.max_value, limits[side][2] / 1_000_000.0) and is_equal_approx(view.progress.value, minf(elapsed / 1_000_000.0, view.progress.max_value)), "gauge uses mode's burn threshold and actual time")
					check(view.progress.get_theme_stylebox("fill").bg_color == [Color("8c806b"), Color("b88428"), Color("825135"), Color("292523")][expected], "gauge boundary color")
					check((m.state == Mold.State.BURNT) == (expected == Q.BURNT), "burn only strictly above boundary")
					if side == 0:
						check(m.flip(elapsed) == (expected in [Q.NORMAL, Q.PERFECT]), "flip uses selected mode and minimum")
						if expected in [Q.NORMAL, Q.PERFECT]:
							check(m.first_quality == expected and m.state == Mold.State.SIDE_2, "flip captures side quality")
					else:
						check(m.second_quality == expected, "second side live quality")
						check(m.quality == [P.NONE, P.DELICIOUS, P.NORMAL, P.BURNT][expected], "perfect first combines with each second quality")
		for stage in 3:
			var m = Mold.new(mode)
			m.add_batter(0)
			if stage >= 1: m.add_filling(1)
			if stage >= 2: m.add_batter(2)
			m.advance(limits[0][2] + 1)
			check(m.state == Mold.State.BURNT and not m.add_filling(limits[0][2] + 1) and not m.flip(limits[0][2] + 1), "incomplete ingredients burn at mode threshold")
		for first in [limits[0][0], limits[0][1] + 1]:
			for second in [limits[1][0], limits[1][1] + 1, limits[1][2] + 1]:
				var s = Session.new()
				s.start(0, mode)
				for index in 3:
					recipe(s.molds[index], 0)
					s.molds[index].flip(first)
				var expected: int = P.BURNT if second > limits[1][2] else (P.DELICIOUS if first > limits[0][1] and second > limits[1][1] else P.NORMAL)
				for index in 3:
					check(s.collect(index, first + second) and s.bag.items[index] == expected, "each side combination collected with exact final quality")
				var result: Dictionary = s.sell_bag(s.bag.id, first + second)
				check(result.sold and result.amount == {P.BURNT: 0, P.NORMAL: 1000, P.DELICIOUS: 2000}[expected], "mode does not change price or zero sale")
		test_session(mode, limits)
		await test_ui(mode)
	view.queue_free()
	await process_frame
	print("G005-A TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func test_session(mode: int, limits: Array) -> void:
	var s = Session.new()
	s.prepare(0, mode)
	for at in [0, 999_999, 1_000_000, 1_999_999, 2_000_000, 2_999_999]:
		s.select_tool(Session.Tool.BATTER, at)
		check(s.preparing and not s.running and s.remaining_usec(at) == 90_000_000 and not s.click_mold(0, at), "both modes keep 3 second input-free preparation")
	s.advance(3_000_000)
	check(s.running and s.remaining_usec(3_000_000) == 90_000_000, "both modes start full 90 seconds")
	for index in 6:
		s.board.add_batter(index, 3_000_000 + index * 100_000)
	for index in 6:
		check(s.molds[index].difficulty == mode and s.molds[index].elapsed_at(4_000_000) == 1_000_000 - index * 100_000, "six mode-consistent independent timers")
	s.start(0)
	recipe(s.molds[0], 0)
	var flip_at: int = limits[0][1] + 1
	var collect_at: int = flip_at + limits[1][1] + 1
	s.molds[0].flip(flip_at)
	var old = s.molds[0]
	check(s.collect(0, collect_at) and s.bag.items == [P.DELICIOUS], "collect perfect food")
	check(s.molds[0] != old and s.molds[0].difficulty == mode and s.molds[0].state == Mold.State.EMPTY, "replacement mold retains difficulty")
	recipe(s.molds[0], collect_at)
	s.molds[0].flip(collect_at + flip_at)
	check(s.collect(0, collect_at * 2) and s.bag.items == [P.DELICIOUS, P.DELICIOUS], "replacement mold cooks using same timing")
	for at in [89_999_999, 90_000_000, 90_000_001]:
		s.advance(at)
		check(s.running == (at < 90_000_000) and s.difficulty == mode, "same exact deadline and retained mode")
	s.prepare(100_000_000)
	check(s.preparing and s.difficulty == mode and s.bag.items.is_empty() and s.revenue == 0, "retry keeps difficulty but resets state")
	for m in s.molds:
		check(m.difficulty == mode and m.state == Mold.State.EMPTY, "retry recreates six matching molds")
func test_ui(mode: int) -> void:
	var path := directory.path_join("ui-%d.json" % mode)
	var store = Store.new(path)
	check(store.add_result("기존기록", 1600, 1), "seed currency fixture")
	var original := FileAccess.get_file_as_string(path)
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = path
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "난이도검증"
	main.difficulty_select.select(mode)
	main.difficulty_select.item_selected.emit(mode)
	await process_frame
	check(main.help.text.contains("[이지]" if mode == D.EASY else "[일반]") and main.help.text.contains("5~8초" if mode == D.EASY else "5~7초"), "selection updates actual timing guide")
	check(main.final_design.ranking_button.visible and main.ranking_title.text.begins_with(Mold.difficulty_name(mode)), "both modes display their own ranking")
	main.action_button.pressed.emit()
	var started: int = main.session.started_at
	check(main.session.difficulty == mode and main.session.preparing and not main.difficulty_select.visible, "round captures choice and hides selector")
	# Even a synthetic hidden-selector event cannot change the current round.
	main.difficulty_select.select(1 - mode)
	main.difficulty_select.item_selected.emit(1 - mode)
	check(main.session.difficulty == mode and main.help.text.contains("[이지]" if mode == D.EASY else "[일반]"), "preparation selection changes cannot alter fixed round")
	main.session.advance(started)
	main.session.started_at = Time.get_ticks_usec()
	main._render(Time.get_ticks_usec())
	main.difficulty_select.item_selected.emit(1 - mode)
	check(main.session.difficulty == mode and not main.difficulty_select.visible, "active round fixed")
	# Complete a real cooking/sale path, with explicit monotonic fixture times.
	var now := Time.get_ticks_usec()
	var first: int = 9_000_000 if mode == D.EASY else 8_000_000
	var second: int = 6_000_000 if mode == D.EASY else 5_000_000
	main.session.start(now - first - second, mode)
	for index in 3:
		recipe(main.session.molds[index], now - first - second)
		main.session.molds[index].flip(now - second)
		main.click_mold_at(index, now)
	main.begin_bag_drag(now)
	main.drop_bag_at(main.sale_zone.get_global_rect().get_center(), now)
	check(main.session.revenue == 2000 and main.sales_feedback.text.contains("2,000원"), "both modes route real cooking through UI sale")
	main.session.started_at = Time.get_ticks_usec() - Session.DURATION_USEC
	main._process(0)
	check(not main.result_recorded, "end waits for manual registration")
	main._accept_nickname("난이도검증")
	main.save_button.pressed.emit()
	check(main.result_label.text.contains("2000원") and main.action_button.visible, "both modes show actual final revenue")
	if mode == D.EASY:
		check(main.save_label.text == "기록 저장 완료" and main.leaderboard_panel.visible and main.ranking.records[0].score == 2000, "easy result saved to its own ranking")
		check(FileAccess.get_file_as_string(path) == original and main.normal_ranking.next_order == 1 and not FileAccess.file_exists(path + ".tmp"), "easy leaves normal ranking bytes and memory unchanged")
	else:
		check(main.save_label.text == "기록 저장 완료" and main.ranking.next_order == 2 and main.ranking.records[0].score == 2000, "normal still stores earned revenue")
	var saved := FileAccess.get_file_as_string(path)
	for repeat in 3:
		main._finish_if_needed()
		main._process(0)
	check(FileAccess.get_file_as_string(path) == saved, "duplicate finish never writes")
	main.action_button.pressed.emit()
	check(main.session.difficulty == mode and main.session.preparing and main.player_nickname.is_empty(), "retry preserves mode but resets name")
	main.session.advance(main.session.started_at + Session.DURATION_USEC)
	main._finish_if_needed()
	main._accept_nickname("난이도검증")
	main.save_button.pressed.emit()
	if mode == D.EASY:
		check(FileAccess.get_file_as_string(path) == original, "easy repeat zero result never changes normal ranking")
	main.back_button.pressed.emit()
	check(main.save_label.text.is_empty(), "lobby clears prior round save status before changing mode")
	main.difficulty_select.select(1 - mode)
	main.difficulty_select.item_selected.emit(1 - mode)
	main.action_button.pressed.emit()
	check(main.session.difficulty == 1 - mode and main.session.preparing, "returning to lobby allows new difficulty")
	main.queue_free()
	await process_frame
	# Missing normal ranking file must not be created by an easy round.
	if mode == D.EASY:
		path = directory.path_join("missing.json")
		main = load("res://scenes/main.tscn").instantiate()
		main.ranking_path = path
		root.add_child(main)
		main.set_process(false)
		main.nickname_input.text = "이지최초"
		main.difficulty_select.select(D.EASY)
		main.action_button.pressed.emit()
		main.session.advance(main.session.started_at + Session.DURATION_USEC)
		main._finish_if_needed()
		main._accept_nickname("이지최초")
		main.save_button.pressed.emit()
		check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".tmp"), "first easy game creates no normal ranking file")
		main.queue_free()
		await process_frame
