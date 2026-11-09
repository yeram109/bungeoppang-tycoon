extends SceneTree
const Mold = preload("res://scripts/cooking_mold.gd")
const Q = Mold.Quality
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fill(main, qualities: Array) -> void:
	for quality in qualities:
		check(main.session.bag.try_add(quality), "fixture adds bag quality")
func reset(main) -> void:
	main.session.start(0)
	main.result_recorded = false
	main._clear_sales_feedback()
	main._render(0)
func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	var directory := "res://.tools/test-data/feedback-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	main.ranking_path = directory.path_join("rankings.json")
	root.add_child(main)
	main.set_process(false)
	main.nickname_input.text = "반응검사"
	main.action_button.pressed.emit()
	await process_frame
	await process_frame
	var inside: Vector2 = main.sale_zone.get_global_rect().get_center()
	var outside := Vector2(-1, -1)
	var cases := [
		[[Q.DELICIOUS,Q.DELICIOUS,Q.DELICIOUS],2000,"+2,000원\n최고야!"],
		[[Q.DELICIOUS,Q.DELICIOUS,Q.NORMAL],1600,"+1,600원\n맛있다!"],
		[[Q.DELICIOUS,Q.DELICIOUS,Q.BURNT],1300,"+1,300원\n좀 탔는데?"],
		[[Q.DELICIOUS,Q.NORMAL,Q.NORMAL],1300,"+1,300원\n맛있다!"],
		[[Q.DELICIOUS,Q.NORMAL,Q.BURNT],1000,"+1,000원\n좀 탔는데?"],
		[[Q.DELICIOUS,Q.BURNT,Q.BURNT],600,"+600원\n맛없어!"],
		[[Q.NORMAL,Q.NORMAL,Q.NORMAL],1000,"+1,000원\n맛있다!"],
		[[Q.NORMAL,Q.NORMAL,Q.BURNT],600,"+600원\n좀 탔는데?"],
		[[Q.NORMAL,Q.BURNT,Q.BURNT],300,"+300원\n맛없어!"],
		[[Q.BURNT,Q.BURNT,Q.BURNT],0,"+0원\n맛없어!"]]
	for sample in cases:
		reset(main)
		fill(main, sample[0])
		main.begin_bag_drag(1_000_000)
		main.drop_bag_at(inside, 1_000_000)
		check(main.sales_feedback.visible and main.sales_feedback.text == sample[2], "actual UI amount and reaction for each composition")
		check(main.session.revenue == sample[1] and main.session.bag.items.is_empty(), "popup matches successful sale including zero")
		check(not main.bag_hint.visible, "feedback replaces hint without overlapping")
		await process_frame
		check(main.get_global_rect().encloses(main.sales_feedback.get_global_rect()) and main.get_global_rect().encloses(main.sale_zone.get_global_rect()), "popup and sale zone fit viewport")
		main._render(2_299_999)
		check(main.sales_feedback.visible, "visible just before 1.3 seconds")
		main._render(2_300_000)
		check(not main.sales_feedback.visible and main.sales_feedback.text.is_empty() and main.bag_hint.visible, "expires exactly at 1.3 seconds")
		main._render(2_300_001)
		check(main.sales_feedback_until == 0, "expired state stays cleared")
	reset(main)
	fill(main, cases[0][0])
	main.begin_bag_drag(1_000_000)
	main.drop_bag_at(inside, 1_000_000)
	fill(main, cases[9][0])
	main.begin_bag_drag(2_000_000)
	main.drop_bag_at(inside, 2_000_000)
	check(main.sales_feedback.text == cases[9][2] and main.sales_feedback_until == 3_300_000, "consecutive zero sale replaces amount reaction and expiry")
	main._render(2_300_000)
	check(main.sales_feedback.visible, "previous expiry cannot hide new sale")
	main.drop_bag_at(inside, 2_400_000)
	check(main.sales_feedback_until == 3_300_000 and main.session.revenue == 2000, "duplicate drop cannot refresh or score twice")
	for action in ["outside", "cancel", "stale", "incomplete"]:
		reset(main)
		fill(main, [Q.NORMAL] if action == "incomplete" else cases[0][0])
		main.begin_bag_drag(1_000_000)
		if action == "cancel":
			main._cancel_bag_drag()
		if action == "stale":
			main.dragged_bag_id -= 1
		main.drop_bag_at(outside if action == "outside" else inside, 1_000_000)
		check(not main.sales_feedback.visible and main.sales_feedback.text.is_empty() and main.sales_feedback_until == 0, "failed or cancelled drop creates no success: " + action)
		check(main.session.revenue == 0 and main.session.bag.items.size() == (1 if action == "incomplete" else 3), "failed drop preserves contents")
	# A failed drop while previous success is visible must not renew that success.
	reset(main)
	fill(main, cases[0][0])
	main.begin_bag_drag(1_000_000)
	main.drop_bag_at(inside, 1_000_000)
	fill(main, cases[9][0])
	main.begin_bag_drag(1_500_000)
	main.drop_bag_at(outside, 1_500_000)
	check(main.sales_feedback.text == cases[0][2] and main.sales_feedback_until == 2_300_000, "outside drop cannot create or refresh feedback")
	for offset in [-1, 0, 1]:
		reset(main)
		fill(main, cases[0][0])
		main.begin_bag_drag(59_000_000)
		main.drop_bag_at(inside, 60_000_000 + offset)
		check(main.sales_feedback.visible == (offset < 0) and main.session.revenue == (2000 if offset < 0 else 0), "deadline wins before feedback")
		main.session.advance(60_000_000)
		main._render(60_000_000)
		check(main.sales_feedback_until == 0 and main.sales_feedback.text.is_empty() and not main.sales_feedback.visible, "end clears active feedback")
		main.action_button.pressed.emit()
		check(main.session.running and main.sales_feedback_until == 0 and not main.sales_feedback.visible, "retry never shows old feedback")
	main.queue_free()
	await process_frame
	print("G003-B TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
