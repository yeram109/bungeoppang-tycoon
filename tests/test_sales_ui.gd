extends SceneTree
const Mold = preload("res://scripts/cooking_mold.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func cook(main, index: int, quality: int, now: int) -> void:
	var s = main.session
	if quality == Mold.Quality.BURNT:
		s.board.add_batter(index, now - 10_000_000)
	else:
		s.board.add_batter(index, now - (8_000_000 if quality == Mold.Quality.DELICIOUS else 10_000_000))
		s.board.add_filling(index, now - (8_000_000 if quality == Mold.Quality.DELICIOUS else 10_000_000))
		s.board.add_batter(index, now - (8_000_000 if quality == Mold.Quality.DELICIOUS else 10_000_000))
		s.board.flip(index, now - (3_000_000 if quality == Mold.Quality.DELICIOUS else 5_000_000))
	s.advance(now)
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.ranking_path = "res://.tools/test-data/bag-ui-%d.json" % Time.get_ticks_usec()
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "봉투검사"
	main.action_button.pressed.emit()
	main.session.start(0)
	main._render(0)
	await process_frame
	await process_frame
	check(main.get_global_rect().encloses(main.sales_row.get_global_rect()), "bag and sale zone fit 960x540")
	for view in main.mold_views:
		check(main.get_global_rect().encloses(view.get_global_rect()), "all molds fit")
	var inside: Vector2 = main.sale_zone.get_global_rect().get_center()
	var outside := Vector2(-1, -1)
	for count in 3:
		main.begin_bag_drag(10_000_000)
		check(not main.dragging, "incomplete bag cannot drag")
		cook(main, count, Mold.Quality.BURNT, 10_000_000)
		main.click_mold_at(count, 10_000_000)
		check(main.session.bag.items.size() == count + 1, "UI collects burnt")
		check(main.session.molds[count].state == Mold.State.EMPTY, "successful collection empties mold")
	check(main.bag_button.text.contains("탄 · 탄 · 탄"), "quality snapshots displayed")
	cook(main, 3, Mold.Quality.BURNT, 10_000_000)
	main.click_mold_at(3, 10_000_000)
	check(main.session.molds[3].state == Mold.State.BURNT and main.session.bag.items.size() == 3, "full bag preserves rejected mold")
	check(main.mold_views[3].feedback_label.text.contains("가득"), "full bag guidance")
	main.begin_bag_drag(10_000_000)
	check(main.dragging and main.drag_preview.visible, "full bag starts drag preview")
	main.drop_bag_at(outside, 10_000_000)
	check(not main.dragging and main.session.bag.items.size() == 3 and main.session.revenue == 0, "outside drop preserves contents")
	for cancel in ["escape", "right", "focus"]:
		main.begin_bag_drag(10_000_000)
		if cancel == "focus":
			main.get_window().focus_exited.emit()
		elif cancel == "escape":
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.pressed = true
			main._input(event)
		else:
			# Real-time input handler; align the fixture clock before invoking it.
			main.session.started_at = Time.get_ticks_usec()
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_RIGHT
			event.pressed = true
			main._input(event)
		check(not main.dragging and main.session.bag.items.size() == 3, "cancel preserves bag: " + cancel)
	main.session.started_at = 0
	var token: int = main.session.bag.id
	main.begin_bag_drag(10_000_000)
	main.drop_bag_at(inside, 10_000_000)
	check(main.session.bag.id != token and main.session.bag.items.is_empty() and main.session.revenue == 0, "zero sale replaces bag")
	check(main.bag_hint.text.contains("판매 완료"), "zero sold acknowledged")
	main.drop_bag_at(inside, 10_000_000)
	check(main.session.bag.id == token + 1, "duplicate drop ignored")
	for quality in [Mold.Quality.DELICIOUS, Mold.Quality.NORMAL, Mold.Quality.BURNT]:
		main.session.start(0)
		for index in 3:
			cook(main, index, quality, 10_000_000)
			main.click_mold_at(index, 10_000_000)
		check(main.session.bag.items == [quality, quality, quality], "UI preserves collected quality")
		main.begin_bag_drag(10_000_000)
		main.drop_bag_at(inside, 10_000_000)
		var expected: int = {Mold.Quality.DELICIOUS: 2000, Mold.Quality.NORMAL: 1000, Mold.Quality.BURNT: 0}[quality]
		check(main.session.revenue == expected and main.revenue_label.text == "수익 %d원" % expected, "sale updates revenue label")
	# Collection refreshes READY quality at the actual click, not the last frame.
	for elapsed in [4_500_000, 4_500_001, 6_000_000, 6_000_001]:
		main.session.start(0)
		cook(main, 0, Mold.Quality.DELICIOUS, 10_000_000)
		main.click_mold_at(0, 7_000_000 + elapsed)
		var expected: int = Mold.Quality.DELICIOUS if elapsed <= 4_500_000 else (Mold.Quality.NORMAL if elapsed <= 6_000_000 else Mold.Quality.BURNT)
		check(main.session.bag.items == [expected], "click refreshes quality boundary")
	main.session.start(0)
	cook(main, 0, Mold.Quality.DELICIOUS, 10_000_000)
	main.session.select_tool(main.Session.Tool.BATTER, 10_000_000)
	main.click_mold_at(0, 10_000_000)
	check(main.session.bag.items.is_empty() and main.session.molds[0].state == Mold.State.READY, "held tool cannot collect through UI")
	check(main.session.selected_tool == main.Session.Tool.BATTER and main.mold_views[0].feedback_label.text.contains("해제"), "held tool stays selected with guidance")
	main.session.cancel_tool(10_000_000)
	main.click_mold_at(0, 10_000_000)
	check(main.session.bag.items == [Mold.Quality.DELICIOUS], "deselect permits collection")
	# Consecutive sales accumulate once; an old drag token cannot sell a refilled bag.
	main.session.start(0)
	for sale_index in 2:
		for index in 3:
			cook(main, index, Mold.Quality.DELICIOUS, 10_000_000)
			main.click_mold_at(index, 10_000_000)
		main.begin_bag_drag(10_000_000)
		main.drop_bag_at(inside, 10_000_000)
		check(main.session.revenue == (sale_index + 1) * 2000, "consecutive revenue accumulates once")
	for index in 3:
		cook(main, index, Mold.Quality.DELICIOUS, 10_000_000)
		main.click_mold_at(index, 10_000_000)
	main.begin_bag_drag(10_000_000)
	main.dragged_bag_id -= 1
	main.drop_bag_at(inside, 10_000_000)
	check(main.session.bag.items.size() == 3 and main.session.revenue == 4000, "stale drag cannot consume newer bag")
	check(main.bag_hint.text.contains("없는"), "failed sale feedback")
	for offset in [-1, 0, 1]:
		main.session.start(0)
		main.result_recorded = false
		for index in 3:
			cook(main, index, Mold.Quality.DELICIOUS, 10_000_000)
			main.click_mold_at(index, 10_000_000)
		main.begin_bag_drag(59_999_998)
		main.drop_bag_at(inside, 60_000_000 + offset)
		check(main.session.revenue == (2000 if offset < 0 else 0), "deadline drop boundary")
		check(not main.dragging and main.session.bag.items.is_empty(), "drop or end clears drag and bag")
		if offset >= 0:
			check(not main.sales_row.visible and not main.drag_preview.visible, "end hides bag and preview")
			check(main.result_label.text.contains("0원"), "result shows actual revenue")
	main.action_button.pressed.emit()
	check(main.session.running and main.session.revenue == 0 and main.session.bag.items.is_empty() and not main.dragging, "retry resets")
	# Real button signals collect and gui_input starts drag.
	var now := Time.get_ticks_usec()
	for index in 3:
		cook(main, index, Mold.Quality.BURNT, now)
		main.mold_views[index].cook_button.pressed.emit()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	main.bag_button.gui_input.emit(press)
	check(main.dragging and main.session.bag.items.size() == 3, "actual button and bag signals wired")
	main.session.started_at = Time.get_ticks_usec() - main.Session.DURATION_USEC
	main._process(0)
	check(not main.dragging and not main.drag_preview.visible and main.session.bag.items.is_empty(), "process expiry cancels active drag")
	check(not FileAccess.file_exists(main.ranking_path), "no legacy ranking write")
	main.queue_free()
	await process_frame
	print("G002-B TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

