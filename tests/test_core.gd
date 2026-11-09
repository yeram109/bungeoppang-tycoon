extends SceneTree

const Mold = preload("res://scripts/mold.gd")
const Session = preload("res://scripts/game_session.gd")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_boundaries()
	test_sales()
	test_burning()
	test_independence()
	test_deadline()
	await test_scene()
	print("CORE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_boundaries() -> void:
	for sample in [[0, Mold.Quality.COOKING], [2_999_999, Mold.Quality.COOKING],
		[3_000_000, Mold.Quality.PERFECT], [4_500_000, Mold.Quality.PERFECT],
		[4_500_001, Mold.Quality.NORMAL], [6_000_000, Mold.Quality.NORMAL],
		[6_000_001, Mold.Quality.BURNT]]:
		check(Mold.quality_at(sample[0]) == sample[1], "quality boundary %d" % sample[0])
	var mold = Mold.new()
	mold.click(100)
	for now in [100, 200, 3_000_099]:
		check(mold.click(now) == 0 and mold.state == Mold.State.SIDE_1, "early click ignored")
		check(mold.side_started_at == 100, "early input must not restart timer")
	mold.click(3_000_100)
	check(mold.state == Mold.State.SIDE_2 and mold.elapsed_at(3_000_100) == 0, "flip resets second side clock")
	mold.click(3_000_100)
	check(mold.state == Mold.State.SIDE_2, "double flip cannot sell")
	check(mold.click(6_000_099) == 0 and mold.state == Mold.State.SIDE_2, "second side early click ignored")
	check(mold.side_started_at == 3_000_100, "second side early input preserves clock")

func test_sales() -> void:
	# Exercise both sides at every accepted boundary and all quality combinations.
	for first in [3_000_000, 4_500_000, 4_500_001, 6_000_000]:
		for second in [3_000_000, 4_500_000, 4_500_001, 6_000_000]:
			var game = Session.new()
			game.start(0)
			game.click_mold(0, 0)
			check(game.click_mold(0, first) == 0 and game.score == 0, "no score on flip")
			var expected := 100 if first <= 4_500_000 and second <= 4_500_000 else 60
			check(game.click_mold(0, first + second) == expected, "sale quality combination")
			check(game.score == expected and game.molds[0].state == Mold.State.EMPTY, "one sale consumes mold")
			for repeat in 5:
				game.click_mold(0, first + second)
			check(game.score == expected, "repeated input cannot duplicate score")

func test_burning() -> void:
	for side in [1, 2]:
		var game = Session.new()
		game.start(0)
		game.click_mold(0, 0)
		var side_start := 0
		if side == 2:
			game.click_mold(0, 3_000_000)
			side_start = 3_000_000
		game.advance(side_start + 6_000_000)
		check(game.molds[0].state != Mold.State.EMPTY, "exactly six seconds not burnt")
		game.advance(side_start + 6_000_001)
		check(game.molds[0].state == Mold.State.EMPTY and game.score == 0, "automatic discard on each side")
		game.click_mold(0, side_start + 7_000_000)
		check(game.molds[0].state == Mold.State.SIDE_1, "burnt mold reusable")
	var delayed = Session.new()
	delayed.start(0)
	delayed.click_mold(0, 0)
	delayed.click_mold(0, 6_000_001)
	check(delayed.molds[0].state == Mold.State.EMPTY and delayed.score == 0, "late click resolves burn before input")
	delayed.click_mold(1, 7_000_000)
	delayed.advance(25_000_000)
	check(delayed.molds[1].state == Mold.State.EMPTY, "long frame discards without delta accumulation")

func test_independence() -> void:
	var game = Session.new()
	check(game.molds.size() == 3, "exactly three molds")
	check(game.click_mold(0, 0) == 0 and game.molds[0].state == Mold.State.EMPTY, "input blocked before start")
	game.start(0)
	game.click_mold(0, 0)
	game.click_mold(1, 1_000_000)
	game.click_mold(2, 2_000_000)
	game.click_mold(0, 3_000_000)
	check(game.molds[0].state == Mold.State.SIDE_2 and game.molds[1].state == Mold.State.SIDE_1, "independent states")
	check(game.molds[1].elapsed_at(3_000_000) == 2_000_000 and game.molds[2].elapsed_at(3_000_000) == 1_000_000, "independent clocks")
	game.click_mold(0, 6_000_000)
	game.advance(7_000_001)
	check(game.score == 100 and game.molds[1].state == Mold.State.EMPTY and game.molds[2].state == Mold.State.SIDE_1, "one sale and one burn do not affect third mold")
	game.click_mold(2, 7_500_000)
	game.click_mold(2, 10_500_000)
	check(game.score == 160, "scores from different molds accumulate")
	game.start(100_000_000)
	check(game.running and game.score == 0 and game.remaining_usec(100_000_000) == 60_000_000, "restart resets score and deadline")
	for mold in game.molds:
		check(mold.state == Mold.State.EMPTY and mold.first_quality == Mold.Quality.COOKING, "restart resets each mold")

func test_deadline() -> void:
	for sale_time in [59_999_999, 60_000_000, 60_000_001, 80_000_000]:
		var game = Session.new()
		game.start(0)
		game.click_mold(0, 53_999_999)
		game.click_mold(0, 56_999_999)
		game.click_mold(0, sale_time)
		check(game.score == (100 if sale_time < 60_000_000 else 0), "deadline vs sale %d" % sale_time)
		game.advance(60_000_000)
		check(not game.running and game.remaining_usec(80_000_000) == 0, "timer ends at sixty and clamps")
		var frozen_state: int = game.molds[0].state
		var frozen_score: int = game.score
		for index in 3:
			game.click_mold(index, 90_000_000)
		game.advance(100_000_000)
		check(game.score == frozen_score and game.molds[0].state == frozen_state, "post-end input and cooking blocked")

func test_scene() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.mold_views.size() == 3 and main.action_button.visible, "scene shows three molds and start")
	for view in main.mold_views:
		check(view.cook_button.disabled, "UI blocks pre-start input")
	main.action_button.pressed.emit()
	check(main.session.running and not main.action_button.visible, "start signal wired")
	main.mold_views[1].cook_button.pressed.emit()
	check(main.session.molds[1].state == Mold.State.SIDE_1, "mold signal routes correct index")
	main.session.started_at = Time.get_ticks_usec() - Session.DURATION_USEC
	main._process(0.0)
	check(main.result_label.text.contains("최종 점수 0점") and main.action_button.visible, "result screen appears at deadline")
	for view in main.mold_views:
		check(view.cook_button.disabled, "UI blocks post-end input")
	main.action_button.pressed.emit()
	check(main.session.running and main.session.molds[1].state == Mold.State.EMPTY, "restart signal resets state")
	await process_frame
	for view in main.mold_views:
		check(main.get_global_rect().encloses(view.get_global_rect()), "mold fits viewport")
	main.queue_free()
	await process_frame
