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
func run() -> void:
	for sample in [[0, 3], [999_999, 3], [1_000_000, 2], [1_999_999, 2], [2_000_000, 1], [2_999_999, 1]]:
		var s = Session.new()
		s.prepare(0)
		var at: int = sample[0]
		s.advance(at)
		check(s.preparing and not s.running and s.preparation_number(at) == sample[1], "preparation boundary")
		check(s.remaining_usec(at) == 90_000_000, "preparation never consumes play time")
		s.select_tool(Session.Tool.BATTER, at)
		check(s.selected_tool == Session.Tool.NONE and not s.click_mold(0, at), "preparation blocks material input")
		check(not s.collect(0, at) and not s.sell_bag(s.bag.id, at).sold, "preparation blocks collection and sale")
		check(s.molds[0].state == Mold.State.EMPTY and s.bag.items.is_empty() and s.revenue == 0, "preparation input leaves state intact")
	for late in [0, 1, 123_456]:
		var s = Session.new()
		s.prepare(100)
		s.advance(3_000_100 + late)
		check(s.running and not s.preparing and s.preparation_number(3_000_100 + late) == 0, "preparation ends at exact scheduled instant")
		check(s.started_at == 3_000_100 and s.remaining_usec(3_000_100 + late) == 90_000_000 - late, "late frames cannot extend game")
	for offset in [-1, 0, 1]:
		for action in ["advance", "click", "collect", "sell", "tool"]:
			var s = Session.new()
			s.prepare(0)
			s.advance(3_000_000)
			for index in 3:
				s.bag.try_add(Mold.Quality.NORMAL)
			s.board.add_batter(0, 4_000_000)
			var at: int = 93_000_000 + offset
			match action:
				"advance": s.advance(at)
				"click": s.click_mold(0, at)
				"collect": s.collect(0, at)
				"sell": s.sell_bag(s.bag.id, at)
				"tool": s.select_tool(Session.Tool.BATTER, at)
			check(s.running == (offset < 0) and s.remaining_usec(at) == (1 if offset < 0 else 0), "90 second deadline before " + action)
			check(s.revenue == (1000 if action == "sell" and offset < 0 else 0), "only predeadline sale earns revenue")
			if offset >= 0:
				check(s.bag.items.is_empty() and s.molds[0].state == Mold.State.EMPTY and s.selected_tool == Session.Tool.NONE, "end clears unsold items and tool")
			s.prepare(at + 1)
			check(s.preparing and not s.running and s.revenue == 0 and s.bag.items.is_empty(), "retry resets state and prepares again")
	await test_ui()
	print("G004-B TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func test_ui() -> void:
	var directory := "res://.tools/test-data/balance-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("rankings.json")
	var store = Store.new(path)
	check(store.add_result("기존60초", 1600, 1), "seed existing currency record")
	var original := FileAccess.get_file_as_string(path)
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = path
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "새90초"
	await process_frame
	main.action_button.pressed.emit()
	var origin: int = main.session.started_at
	check(main.session.preparing and not main.session.running, "start enters preparation")
	check(main.preparation_label.visible and main.preparation_label.text == "3", "live UI starts with 3")
	check(main.mold_row.visible and main.tool_row.visible and main.sales_row.visible, "preparation shows cooking screen")
	check(not main.action_button.visible and not main.back_button.visible and not main.result_label.visible, "no results or retry during preparation")
	main.action_button.pressed.emit()
	main._show_start()
	check(main.session.started_at == origin and main.has_started, "repeated start/back cannot alter preparation")
	main.batter_button.pressed.emit()
	for index in 6:
		main.mold_views[index].cook_button.pressed.emit()
		check(main.mold_views[index].cook_button.disabled and main.session.molds[index].state == Mold.State.EMPTY, "disabled mold and signal cannot bypass preparation")
	main.begin_bag_drag(Time.get_ticks_usec())
	main.drop_bag_at(main.sale_zone.get_global_rect().get_center(), Time.get_ticks_usec())
	check(not main.dragging and main.session.selected_tool == Session.Tool.NONE and main.session.revenue == 0, "tool and drag blocked")
	for sample in [[0, "3"], [999_999, "3"], [1_000_000, "2"], [1_999_999, "2"], [2_000_000, "1"], [2_999_999, "1"]]:
		var at: int = origin - Session.PREPARATION_USEC + sample[0]
		main.session.advance(at)
		main._finish_if_needed()
		main._render(at)
		check(main.preparation_label.text == sample[1] and main.preparation_label.visible, "actual UI countdown boundary")
		check(main.status_label.text == "90.0초" and main.batter_button.disabled and main.filling_button.disabled, "actual timer frozen and tools disabled")
		check(FileAccess.get_file_as_string(path) == original and not main.result_recorded, "preparation never saves or resets old currency data")
	main.session.advance(origin)
	main._render(origin)
	check(main.session.running and not main.preparation_label.visible and main.status_label.text == "90.0초", "exact UI transition to full 90 seconds")
	check(not main.batter_button.disabled and not main.mold_views[0].cook_button.disabled, "input enabled at start")
	main.session.advance(origin + 89_999_999)
	main._finish_if_needed()
	main._render(origin + 89_999_999)
	check(main.status_label.text == "00.1초" and not main.result_recorded, "last microsecond remains playable unsaved")
	main.session.advance(origin + 90_000_000)
	main._finish_if_needed()
	main._render(origin + 90_000_000)
	check(not main.result_recorded and FileAccess.get_file_as_string(path) == original, "exact end does not automatically save")
	main._accept_nickname("새90초")
	main.save_button.pressed.emit()
	main._render(origin + 90_000_000)
	check(main.status_label.text == "00.0초" and main.final_design.amount.visible and main.save_label.text == "기록 저장 완료", "exact end shows and saves result")
	check(main.ranking.records.size() == 2 and main.ranking.records[0].nickname == "기존60초" and main.ranking.records[0].score == 1600, "90 second result preserves existing 60 second currency record")
	var saved := FileAccess.get_file_as_string(path)
	main._finish_if_needed()
	main.session.advance(origin + 90_000_001)
	main._finish_if_needed()
	check(FileAccess.get_file_as_string(path) == saved, "postdeadline cannot save twice")
	main.action_button.pressed.emit()
	check(main.session.preparing and main.preparation_label.text == "3" and main.player_nickname.is_empty(), "retry clears nickname and repeats 3")
	check(main.session.revenue == 0 and not main.result_recorded and not main.dragging, "retry clears state")
	main._finish_if_needed()
	check(FileAccess.get_file_as_string(path) == saved, "retry preparation does not create record")
	var reloaded = Store.new(path)
	reloaded.load_records()
	check(reloaded.records == main.ranking.records and reloaded.next_order == 2, "old and new currency records survive reload")
	main.queue_free()
	await process_frame
