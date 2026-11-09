extends SceneTree
const Session = preload("res://scripts/cooking_session.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func run() -> void:
	test_tools()
	test_tool_flip()
	test_deadline()
	await test_ui()
	print("G001-B TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func recipe(session, index: int, at: int) -> void:
	session.select_tool(Session.Tool.BATTER, at)
	session.click_mold(index, at)
	session.select_tool(Session.Tool.FILLING, at + 1)
	session.click_mold(index, at + 1)
	session.select_tool(Session.Tool.BATTER, at + 2)
	session.click_mold(index, at + 2)

func test_tools() -> void:
	var s = Session.new()
	s.select_tool(Session.Tool.BATTER, 0)
	check(s.selected_tool == Session.Tool.NONE and not s.click_mold(0, 0), "pre-start input blocked")
	s.start(0)
	s.select_tool(Session.Tool.BATTER, 0)
	check(s.selected_tool == Session.Tool.BATTER, "select batter")
	s.select_tool(Session.Tool.BATTER, 0)
	check(s.selected_tool == Session.Tool.NONE, "same tool deselects")
	s.select_tool(Session.Tool.BATTER, 0)
	s.select_tool(Session.Tool.FILLING, 0)
	check(s.selected_tool == Session.Tool.FILLING, "different tool switches")
	check(not s.click_mold(0, 0) and s.selected_tool == Session.Tool.FILLING, "wrong ingredient keeps tool")
	check(s.molds[0].state == Mold.State.EMPTY and not s.feedback[0].is_empty(), "wrong ingredient reports error without modifying recipe")
	s.cancel_tool(0)
	check(s.selected_tool == Session.Tool.NONE, "right-click command clears tool")
	check(not s.click_mold(0, 0), "empty mold without tool cannot insert batter")
	for index in 6:
		recipe(s, index, index * 10)
		check(s.selected_tool == Session.Tool.NONE and s.molds[index].state == Mold.State.SIDE_1, "one use auto-clears and routes to independent mold")
	check(not s.click_mold(0, 4_999_999), "early flip ignored")
	s.select_tool(Session.Tool.BATTER, 5_000_000)
	check(s.click_mold(0, 5_000_000) and s.molds[0].state == Mold.State.SIDE_2 and s.selected_tool == Session.Tool.BATTER, "held tool flips first side and remains selected")
	s.cancel_tool(5_000_000)
	check(not s.click_mold(0, 5_000_000) and s.molds[0].state == Mold.State.SIDE_2, "repeat click cannot flip second side")
	s.advance(8_000_000)
	check(s.molds[0].state == Mold.State.READY and s.molds[0].quality == Mold.Quality.NORMAL, "ready still in mold")
	check(not s.click_mold(0, 8_000_000) and s.molds[0].state == Mold.State.READY, "ready click cannot collect")
	s.advance(9_500_001)
	check(s.molds[0].quality == Mold.Quality.NORMAL, "first normal side keeps final quality normal")
	s.advance(11_000_001)
	check(s.molds[0].state == Mold.State.BURNT, "ready becomes burnt")
	check(not s.click_mold(0, 11_000_001) and s.molds[0].state == Mold.State.BURNT, "burnt cannot collect or auto clear")
	check(not s.click_mold(-1, 11_000_001) and not s.click_mold(6, 11_000_001), "invalid indices safely rejected")

func test_tool_flip() -> void:
	for tool in [Session.Tool.NONE, Session.Tool.BATTER, Session.Tool.FILLING]:
		for at in [4_999_999, 5_000_000, 7_000_001, 9_000_000, 9_000_001]:
			var s = Session.new()
			s.start(0)
			recipe(s, 0, 0)
			if tool != Session.Tool.NONE:
				s.select_tool(tool, 3)
			var expected: bool = at >= 5_000_000 and at <= 9_000_000
			check(s.click_mold(0, at) == expected, "flip time boundary with each tool")
			check(s.selected_tool == tool, "flip success/early/burnt retains tool")
			check(s.molds[0].state == (Mold.State.SIDE_2 if expected else (Mold.State.BURNT if at > 9_000_000 else Mold.State.SIDE_1)), "flip keeps time rules")
			check(s.bag.items.is_empty(), "flip or burnt tool input never collects")
			if at < 5_000_000:
				check(s.feedback[0].contains("5초"), "early click gives timing guidance with tool")
			if expected:
				check(s.feedback[0].contains("뒤집기 완료"), "flip feedback is not ingredient feedback")
				check(not s.click_mold(0, at + 1) and s.selected_tool == tool, "second click cannot flip twice or consume tool")

func test_deadline() -> void:
	for offset in [-1, 0, 1]:
		for action in ["advance", "select", "cancel", "click"]:
			var s = Session.new()
			s.start(1_000_000)
			recipe(s, 0, 86_000_000)
			s.select_tool(Session.Tool.BATTER, 86_000_003)
			var now: int = 91_000_000 + offset
			match action:
				"advance": s.advance(now)
				"select": s.select_tool(Session.Tool.FILLING, now)
				"cancel": s.cancel_tool(now)
				"click": s.click_mold(1, now)
			check(s.running == (offset < 0), "deadline wins for " + action)
			if offset >= 0:
				check(s.selected_tool == Session.Tool.NONE, "deadline clears selected tool")
				for mold in s.molds:
					check(mold.state == Mold.State.EMPTY, "deadline removes remaining food")
				s.select_tool(Session.Tool.BATTER, now + 100)
				check(not s.click_mold(0, now + 100) and s.selected_tool == Session.Tool.NONE, "all post-end input blocked")
				s.start(now + 200)
				check(s.running and s.remaining_usec(now + 200) == 90_000_000 and s.feedback[0].is_empty(), "retry resets time and feedback")
	# End also removes READY and BURNT, not only preparation states.
	var s = Session.new()
	s.start(0)
	s.select_tool(Session.Tool.BATTER, 0)
	s.click_mold(1, 0)
	recipe(s, 0, 81_000_000)
	s.click_mold(0, 86_000_000)
	s.advance(89_999_999)
	check(s.molds[0].state == Mold.State.READY and s.molds[1].state == Mold.State.BURNT, "deadline fixture includes ready and burnt")
	s.advance(90_000_000)
	check(s.molds[0].state == Mold.State.EMPTY and s.molds[1].state == Mold.State.EMPTY, "deadline removes ready and burnt")

func test_ui() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var directory := "res://.tools/test-data/ui-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	main.ranking_path = directory.path_join("rankings.json")
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "도구검사"
	main.action_button.pressed.emit()
	complete_preparation(main)
	check(main.mold_row.columns == 3 and main.mold_views.size() == 6, "actual UI has 3 by 2 grid")
	main.batter_button.pressed.emit()
	check(main.tool_cursor.visible and main.batter_button.button_pressed and main.tool_cursor.text.contains("반죽"), "tool signal updates selection and cursor")
	main.mold_views[5].cook_button.pressed.emit()
	check(main.session.molds[5].state == Mold.State.FIRST_BATTER and not main.tool_cursor.visible, "sixth button routes ingredient and hides used tool")
	main.filling_button.pressed.emit()
	main.mold_views[0].cook_button.pressed.emit()
	check(main.tool_cursor.visible and main.mold_views[0].feedback_label.text.contains("순서"), "invalid UI action retains tool and shows feedback")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	main._input(right)
	check(main.session.selected_tool == Session.Tool.NONE and not main.tool_cursor.visible, "actual right-click handler clears cursor")
	for tool in [Session.Tool.NONE, Session.Tool.BATTER, Session.Tool.FILLING]:
		var now := Time.get_ticks_usec()
		main.session.start(now - 6_000_000)
		recipe(main.session, 0, now - 6_000_000)
		if tool != Session.Tool.NONE:
			main.session.select_tool(tool, now)
		main.mold_views[0].cook_button.pressed.emit()
		check(main.session.molds[0].state == Mold.State.SIDE_2 and main.session.selected_tool == tool, "actual mold button flips and preserves tool")
		check(main.tool_cursor.visible == (tool != Session.Tool.NONE), "actual tool cursor survives flip")
		check(main.batter_button.button_pressed == (tool == Session.Tool.BATTER) and main.filling_button.button_pressed == (tool == Session.Tool.FILLING), "actual selected button survives flip")
	# Render the real view using model state at every boundary, never rounded text.
	var cases := [[4_999_999, "조리 중", Color("8c806b")], [5_000_000, "일반", Color("825135")], [5_000_001, "일반", Color("825135")], [6_999_999, "일반", Color("825135")], [7_000_000, "일반", Color("825135")], [7_000_001, "완벽", Color("b88428")], [8_999_999, "완벽", Color("b88428")], [9_000_000, "완벽", Color("b88428")], [9_000_001, "탐", Color("292523")]]
	for side in [1, 2]:
		if side == 2:
			cases = [[2_999_999, "조리 중", Color("8c806b")], [3_000_000, "일반", Color("825135")], [3_000_001, "일반", Color("825135")], [4_499_999, "일반", Color("825135")], [4_500_000, "일반", Color("825135")], [4_500_001, "완벽", Color("b88428")], [5_999_999, "완벽", Color("b88428")], [6_000_000, "완벽", Color("b88428")], [6_000_001, "탐", Color("292523")]]
		for sample in cases:
			main.session.start(0)
			recipe(main.session, 0, 0)
			var origin := 0
			if side == 2:
				origin = 5_000_000
				main.session.click_mold(0, origin)
			main.session.advance(origin + sample[0])
			main._render(origin + sample[0])
			var view = main.mold_views[0]
			check(view.cook_button.text.begins_with("%d면 · %s" % [side, sample[1]]), "actual quality label matches boundary")
			check(view.button_style.bg_color == sample[2], "actual color matches quality")
			check(view.progress.get_theme_stylebox("fill").bg_color == sample[2], "live gauge color matches quality boundary")
			check(is_equal_approx(view.progress.max_value, 9.0 if side == 1 else 6.0), "per-side gauge maximum")
			check(is_equal_approx(view.progress.value, minf(sample[0] / 1_000_000.0, view.progress.max_value)), "gauge reflects elapsed time")
	for sample in [[89_999_999, "00.1", true], [90_000_000, "00.0", false], [90_000_001, "00.0", false]]:
		main.session.start(0)
		main.session.advance(sample[0])
		main._render(sample[0])
		check(main.status_label.text == "남은 시간 %s초" % sample[1], "countdown ceil boundary")
		check(main.session.running == sample[2] and main.mold_views[0].cook_button.disabled == not sample[2], "deadline label and input agree")
	main.session.start(Time.get_ticks_usec())
	main._render(Time.get_ticks_usec())
	await process_frame
	for view in main.mold_views:
		check(main.get_global_rect().encloses(view.get_global_rect()), "six molds fit viewport")
	check(main.mold_views[3].position.y > main.mold_views[0].position.y, "second row is below first")
	main.session.started_at = Time.get_ticks_usec() - Session.DURATION_USEC
	main._process(0.0)
	check(not main.tool_cursor.visible and not main.tool_row.visible and main.back_button.visible, "result hides tools and shows return")
	check(FileAccess.file_exists(main.ranking_path), "actual end creates currency ranking")
	main.queue_free()
	await process_frame

func complete_preparation(main) -> void:
	if main.session.preparing:
		main.session.advance(main.session.started_at)
		main.session.started_at = Time.get_ticks_usec()
		main._render(Time.get_ticks_usec())
