extends SceneTree

const Mold = preload("res://scripts/cooking_mold.gd")
const Board = preload("res://scripts/cooking_board.gd")
const S = Mold.State
const Q = Mold.SideQuality
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func prepared(start: int = 0):
	var mold = Mold.new()
	mold.add_batter(start)
	mold.add_filling(start + 1_000_000)
	mold.add_batter(start + 2_000_000)
	return mold

func run() -> void:
	test_quality_boundaries()
	test_ingredients()
	test_first_side()
	test_second_side()
	test_held_food()
	test_six_molds()
	print("G001 COOKING TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_quality_boundaries() -> void:
	for boundary in [[5_000_000, Q.COOKING, Q.PERFECT, Q.PERFECT],
		[7_000_000, Q.PERFECT, Q.PERFECT, Q.NORMAL],
		[9_000_000, Q.NORMAL, Q.NORMAL, Q.BURNT]]:
		for offset in [-1, 0, 1]:
			check(Mold.first_quality_at(boundary[0] + offset) == boundary[offset + 2], "first quality boundary %s/%s" % [boundary[0], offset])
	for boundary in [[3_000_000, Q.COOKING, Q.PERFECT, Q.PERFECT],
		[4_500_000, Q.PERFECT, Q.PERFECT, Q.NORMAL],
		[6_000_000, Q.NORMAL, Q.NORMAL, Q.BURNT]]:
		for offset in [-1, 0, 1]:
			check(Mold.second_quality_at(boundary[0] + offset) == boundary[offset + 2], "second quality boundary %s/%s" % [boundary[0], offset])

func test_ingredients() -> void:
	var start := 123_456_789
	var mold = Mold.new()
	check(not mold.add_filling(start) and not mold.flip(start), "empty rejects filling and flip")
	check(mold.state == S.EMPTY and mold.quality == Mold.Quality.NONE, "rejected empty actions do not create food")
	check(mold.add_batter(start) and mold.state == S.FIRST_BATTER, "first batter starts preparation")
	check(mold.side_started_at == start, "timer starts at first batter")
	check(not mold.add_batter(start + 1) and not mold.flip(start + 5_000_000), "first batter cannot be repeated or flipped")
	check(mold.add_filling(start + 5_100_000) and mold.state == S.FILLING_ADDED, "filling must follow first batter")
	check(not mold.add_filling(start + 5_200_000) and not mold.flip(start + 5_200_000), "filling cannot repeat and cannot skip topping")
	check(mold.add_batter(start + 5_300_000) and mold.state == S.SIDE_1, "second batter completes ingredients")
	check(mold.side_started_at == start and mold.elapsed_at(start + 5_300_000) == 5_300_000, "ingredients never restart timer")
	check(not mold.add_batter(start + 5_300_000) and not mold.add_filling(start + 5_300_000), "complete recipe rejects extra ingredients")
	check(mold.flip(start + 5_300_000) and mold.first_quality == Q.PERFECT, "ingredient time counts toward first-side quality")
	check(mold.state == S.SIDE_2 and mold.side_started_at == start + 5_300_000, "flip starts independent second-side timer")
	check(mold.elapsed_at(start + 5_300_000) == 0 and not mold.flip(start + 5_300_000), "duplicate flip cannot reset second-side clock")
	check(not mold.add_batter(start + 5_400_000) and not mold.add_filling(start + 5_400_000), "second side rejects ingredients")

func test_first_side() -> void:
	for time in [4_999_999, 5_000_000, 5_000_001, 6_999_999, 7_000_000, 7_000_001, 8_999_999, 9_000_000, 9_000_001]:
		var mold = prepared(1_000_000)
		var accepted: bool = mold.flip(1_000_000 + time)
		check(accepted == (time >= 5_000_000 and time <= 9_000_000), "flip boundary %d" % time)
		if accepted:
			check(mold.first_quality == Mold.first_quality_at(time) and mold.state == S.SIDE_2, "first-side judgment recorded at flip")
		else:
			check(mold.state == (S.BURNT if time > 9_000_000 else S.SIDE_1), "early flip ignored; overdue flip burns")
	for stage in [S.FIRST_BATTER, S.FILLING_ADDED, S.SIDE_1]:
		var mold = Mold.new()
		mold.add_batter(0)
		if stage != S.FIRST_BATTER:
			mold.add_filling(1_000_000)
		if stage == S.SIDE_1:
			mold.add_batter(2_000_000)
		mold.advance(9_000_000)
		check(mold.state == stage, "exactly nine seconds does not burn preparation")
		mold.advance(9_000_001)
		check(mold.state == S.BURNT and mold.quality == Mold.Quality.BURNT, "all preparation stages burn past deadline")
		check(not mold.add_batter(10_000_000) and not mold.add_filling(10_000_000) and not mold.flip(10_000_000), "burnt food blocks every cooking action")
		mold.advance(1_000_000_000)
		check(mold.state == S.BURNT and mold.first_quality == Q.BURNT, "burnt food persists without auto disposal")
	for action in ["add_filling", "add_batter", "flip"]:
		var mold = Mold.new()
		mold.add_batter(0)
		if action != "add_filling":
			mold.add_filling(1)
		if action == "flip":
			mold.add_batter(2)
		check(not mold.call(action, 9_000_001) and mold.state == S.BURNT, "late %s checks elapsed time before action" % action)

func test_second_side() -> void:
	for first_time in [5_000_000, 7_000_000, 7_000_001, 9_000_000]:
		for second_time in [2_999_999, 3_000_000, 3_000_001, 4_499_999, 4_500_000, 4_500_001, 5_999_999, 6_000_000, 6_000_001]:
			var mold = prepared(100_000_000)
			var flipped_at: int = 100_000_000 + first_time
			mold.flip(flipped_at)
			mold.advance(flipped_at + second_time)
			var expected_side: int = Mold.second_quality_at(second_time)
			check(mold.second_quality == expected_side, "second-side microsecond boundary %s/%s" % [first_time, second_time])
			check(mold.first_quality == Mold.first_quality_at(first_time), "second-side cooking preserves first-side judgment")
			var expected_state: int = S.BURNT if expected_side == Q.BURNT else (S.SIDE_2 if expected_side == Q.COOKING else S.READY)
			check(mold.state == expected_state, "second-side state matches elapsed time")
			var expected_quality: int = Mold.Quality.NONE
			if expected_side == Q.BURNT:
				expected_quality = Mold.Quality.BURNT
			elif expected_side != Q.COOKING:
				expected_quality = Mold.Quality.DELICIOUS if first_time <= 7_000_000 and second_time <= 4_500_000 else Mold.Quality.NORMAL
			check(mold.quality == expected_quality, "combined product quality matches both sides")
			mold.advance(flipped_at + second_time)
			check(mold.state == expected_state and mold.quality == expected_quality, "same timestamp advance is idempotent")

func test_held_food() -> void:
	var mold = prepared()
	mold.flip(5_000_000)
	mold.advance(8_000_000)
	check(mold.state == S.READY and mold.quality == Mold.Quality.DELICIOUS, "second side becomes ready at three seconds")
	check(not mold.add_batter(8_000_000) and not mold.add_filling(8_000_000) and not mold.flip(8_000_000), "ready food blocks new cooking actions")
	mold.advance(9_500_000)
	check(mold.state == S.READY and mold.quality == Mold.Quality.DELICIOUS, "held food stays perfect through 4.5 seconds")
	mold.advance(9_500_001)
	check(mold.state == S.READY and mold.quality == Mold.Quality.NORMAL, "held food keeps cooking past perfect window")
	mold.advance(11_000_000)
	check(mold.state == S.READY and mold.quality == Mold.Quality.NORMAL, "held normal food remains in mold through six seconds")
	mold.advance(11_000_001)
	check(mold.state == S.BURNT and mold.quality == Mold.Quality.BURNT, "held food burns after six seconds")
	mold.advance(1_000_000_000)
	check(mold.state == S.BURNT and mold.second_quality == Q.BURNT, "burnt second side never auto empties")
	check(not mold.add_batter(1_000_000_000) and not mold.add_filling(1_000_000_000) and not mold.flip(1_000_000_000), "burnt second side cannot restart cooking")
	# A stalled frame must jump straight to burnt, without requiring READY first.
	var jumped = prepared()
	jumped.flip(5_000_000)
	jumped.advance(11_000_001)
	check(jumped.state == mold.state and jumped.quality == mold.quality, "large time jump matches incremental cooking")
	for action in ["add_batter", "add_filling", "flip"]:
		var overdue = prepared()
		overdue.flip(5_000_000)
		check(not overdue.call(action, 11_000_001) and overdue.state == S.BURNT, "late second-side action processes burning first")

func test_six_molds() -> void:
	var board = Board.new()
	check(board.molds.size() == 6, "six molds created")
	for index in 6:
		check(board.add_batter(index, index * 1_000_000), "independent first batter %d" % index)
		for earlier in index:
			check(board.molds[index] != board.molds[earlier], "molds do not share state objects")
	board.add_filling(1, 5_100_000)
	board.add_filling(2, 5_200_000)
	board.add_batter(2, 5_300_000)
	board.add_filling(3, 5_400_000)
	board.add_batter(3, 5_500_000)
	check(board.flip(2, 7_000_000), "one mold flips independently")
	check(board.flip(3, 8_000_000), "another mold has separate second-side start")
	check(board.molds[0].state == S.FIRST_BATTER and board.molds[1].state == S.FILLING_ADDED, "other recipes remain independent")
	for index in [0, 1, 4, 5]:
		check(board.molds[index].side_started_at == index * 1_000_000, "per-mold first-side origin retained")
	check(board.molds[2].side_started_at == 7_000_000 and board.molds[3].side_started_at == 8_000_000, "per-mold second-side origin retained")
	for invalid in [-1, 6, 100]:
		check(not board.add_batter(invalid, 8_000_000) and not board.add_filling(invalid, 8_000_000) and not board.flip(invalid, 8_000_000), "invalid index rejected")
	board.advance(9_000_001)
	check(board.molds[0].state == S.BURNT and board.molds[1].state == S.FILLING_ADDED, "one mold burns without burning later mold")
	board.advance(10_000_000)
	check(board.molds[2].state == S.READY and board.molds[3].state == S.SIDE_2, "different second-side starts reach ready independently")
	board.advance(11_500_001)
	check(board.molds[2].quality == Mold.Quality.NORMAL and board.molds[3].quality == Mold.Quality.DELICIOUS, "ready molds have independent live quality")
	check(board.molds[4].state == S.FIRST_BATTER and board.molds[5].state == S.FIRST_BATTER, "later preparation remains independent of ready molds")
	board.add_batter(-1, 13_000_001)
	check(board.molds[2].state == S.BURNT and board.molds[3].state == S.READY, "invalid input still advances all timers; only overdue mold burns")
	check(board.molds[4].state == S.BURNT and board.molds[5].state == S.FIRST_BATTER, "preparation and second-side deadlines remain independent")
	var separate_board = Board.new()
	check(separate_board.molds[0].state == S.EMPTY, "separate boards do not share state")
	board.reset()
	check(board.molds.size() == 6, "reset keeps six molds")
	for mold in board.molds:
		check(mold.state == S.EMPTY and mold.side_started_at == 0 and mold.quality == Mold.Quality.NONE, "reset clears each mold")
