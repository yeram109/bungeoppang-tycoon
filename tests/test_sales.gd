extends SceneTree
const Session = preload("res://scripts/cooking_session.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
const Bag = preload("res://scripts/sales_bag.gd")
const Q = Mold.Quality
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
	test_prices()
	test_bag()
	test_collection()
	test_failures()
	test_sales()
	test_deadlines()
	print("G002-A TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# Real cooking inputs, supplied in monotonic order; no forced READY states.
func batch(s, start: int, count: int = 6) -> void:
	for index in count:
		s.board.add_batter(index, start)
	for index in count:
		s.board.add_filling(index, start + 1)
	for index in count:
		s.board.add_batter(index, start + 2)
	for index in count:
		s.board.flip(index, start + 5_000_000)

func mold_snapshot(mold) -> Array:
	return [mold.state, mold.side_started_at, mold.first_quality, mold.second_quality, mold.quality]

func test_prices() -> void:
	# All ten rows of the Notion table, then every ordered quality triple.
	var prices := {"3/0/0": 2000, "2/1/0": 1600, "2/0/1": 1300,
		"1/2/0": 1300, "1/1/1": 1000, "1/0/2": 600,
		"0/3/0": 1000, "0/2/1": 600, "0/1/2": 300, "0/0/3": 0}
	var visited := {}
	for a in [Q.DELICIOUS, Q.NORMAL, Q.BURNT]:
		for b in [Q.DELICIOUS, Q.NORMAL, Q.BURNT]:
			for c in [Q.DELICIOUS, Q.NORMAL, Q.BURNT]:
				var values := [a, b, c]
				var key := "%d/%d/%d" % [values.count(Q.DELICIOUS), values.count(Q.NORMAL), values.count(Q.BURNT)]
				visited[key] = true
				check(Bag.price_for(values) == prices[key], "Notion price and order independence " + key)
	check(visited.size() == 10, "all ten table rows covered")
	for invalid in [[], [Q.NORMAL], [Q.NORMAL, Q.NORMAL], [Q.NORMAL, Q.NORMAL, Q.NORMAL, Q.NORMAL], [Q.NONE, Q.NORMAL, Q.NORMAL], [-1, Q.NORMAL, Q.NORMAL], ["1", Q.NORMAL, Q.NORMAL]]:
		check(Bag.price_for(invalid) == -1, "incomplete/invalid price is distinct from zero")

func test_bag() -> void:
	var bag = Bag.new()
	check(not bag.try_add(Q.NONE) and bag.items.is_empty(), "reject uncooked quality")
	for count in 3:
		var before: Array = bag.items
		var id: int = bag.id
		check(not bag.sell(id).sold and bag.items == before and bag.id == id, "0-2 items cannot sell or consume bag")
		check(bag.try_add(Q.BURNT) and bag.items.size() == count + 1, "capacity increment 0-3")
	var snapshot: Array = bag.items
	check(not bag.try_add(Q.DELICIOUS) and bag.items == snapshot, "fourth item rejected without loss")
	var exposed: Array = bag.items
	exposed.clear()
	check(bag.items.size() == 3, "UI snapshot cannot mutate actual contents")
	var id: int = bag.id
	check(not bag.sell(id + 1).sold and bag.items == snapshot and bag.id == id, "wrong bag token preserves full bag")
	var result: Dictionary = bag.sell(id)
	check(result.sold and result.amount == 0 and bag.items.is_empty() and bag.id != id, "zero won is successful sale and new empty bag")
	check(not bag.sell(id).sold, "duplicate zero sale rejected")
	for i in 3:
		bag.try_add(Q.DELICIOUS)
	check(not bag.sell(id).sold and bag.items.size() == 3, "delayed previous sale cannot consume refilled bag")
	result = bag.sell(bag.id)
	check(result.sold and result.amount == 2000 and bag.items.is_empty(), "new bag sells normally")

func test_collection() -> void:
	for sample in [[7_999_999, false, Q.NONE], [8_000_000, true, Q.DELICIOUS], [9_500_000, true, Q.DELICIOUS], [9_500_001, true, Q.NORMAL], [11_000_000, true, Q.NORMAL], [11_000_001, true, Q.BURNT]]:
		var s = Session.new()
		s.start(0)
		batch(s, 0)
		check(s.collect(0, sample[0]) == sample[1], "collection refreshes quality at boundary %d" % sample[0])
		if sample[1]:
			check(s.bag.items == [sample[2]], "collected quality matches current elapsed time")
			check(mold_snapshot(s.molds[0]) == [Mold.State.EMPTY, 0, Mold.SideQuality.COOKING, Mold.SideQuality.COOKING, Q.NONE], "successful collection resets all mold state")
			check(not s.collect(0, sample[0]) and s.bag.items.size() == 1, "same bread cannot be collected twice")
			s.advance(20_000_000)
			check(s.bag.items == [sample[2]], "bag quality no longer cooks")
		else:
			check(s.molds[0].state == Mold.State.SIDE_2 and s.bag.items.is_empty(), "early collection leaves food in mold")
	var s = Session.new()
	s.start(0)
	s.board.add_batter(0, 0)
	check(s.collect(0, 9_000_001) and s.bag.items == [Q.BURNT], "burnt incomplete recipe can be collected")
	check(s.board.add_batter(0, 9_000_002), "collected mold reusable")
	var mixed = Session.new()
	mixed.start(0)
	batch(mixed, 0)
	mixed.collect(0, 8_000_000)
	mixed.collect(1, 9_500_001)
	mixed.collect(2, 11_000_001)
	check(mixed.bag.items == [Q.DELICIOUS, Q.NORMAL, Q.BURNT] and mixed.revenue == 0, "mixed qualities retained without collection revenue")
	check(mixed.molds[3].state == Mold.State.BURNT, "other molds continue cooking independently")

func test_failures() -> void:
	var s = Session.new()
	check(not s.collect(0, 0) and not s.sell_bag(s.bag.id, 0).sold, "pre-start collection and sale blocked")
	s.start(0)
	batch(s, 0)
	s.advance(8_000_000)
	for index in [-1, 6, 99]:
		check(not s.collect(index, 8_000_000) and s.bag.items.is_empty(), "invalid mold index rejected")
	var before := mold_snapshot(s.molds[0])
	s.select_tool(Session.Tool.BATTER, 8_000_000)
	check(not s.collect(0, 8_000_000) and s.selected_tool == Session.Tool.BATTER, "held tool prevents collection and stays selected")
	check(mold_snapshot(s.molds[0]) == before and s.bag.items.is_empty(), "held-tool failure preserves mold and bag")
	s.cancel_tool(8_000_000)
	for index in 3:
		check(s.collect(index, 8_000_000), "collect until capacity")
	var id: int = s.bag.id
	var items: Array = s.bag.items
	before = mold_snapshot(s.molds[3])
	var original = s.molds[3]
	check(not s.collect(3, 8_000_000), "full bag refuses fourth bread")
	check(s.molds[3] == original and mold_snapshot(s.molds[3]) == before and s.bag.items == items and s.bag.id == id, "failed transfer changes neither container")
	check(not s.collect(3, 11_000_001) and s.molds[3].state == Mold.State.BURNT, "full bag still refreshes cooking time")
	check(s.bag.items == items and s.molds[3] == original, "time update does not consume blocked bread")
	for count in [0, 1, 2]:
		var unfinished = Session.new()
		unfinished.start(0)
		if count >= 1: unfinished.board.add_batter(0, 0)
		if count >= 2: unfinished.board.add_filling(0, 1)
		before = mold_snapshot(unfinished.molds[0])
		check(not unfinished.collect(0, 2) and mold_snapshot(unfinished.molds[0]) == before and unfinished.bag.items.is_empty(), "unready recipe cannot be collected")

func test_sales() -> void:
	var s = Session.new()
	s.start(0)
	batch(s, 0)
	for index in 3:
		s.collect(index, 8_000_000)
	var old_id: int = s.bag.id
	var result: Dictionary = s.sell_bag(old_id, 8_000_000)
	check(result.sold and result.amount == 2000 and s.revenue == 2000 and s.bag.items.is_empty(), "successful sale credits once and empties bag")
	check(not s.sell_bag(old_id, 8_000_000).sold and s.revenue == 2000, "duplicate sale does not credit twice")
	for index in range(3, 6):
		s.collect(index, 11_000_001)
	check(not s.sell_bag(old_id, 11_000_001).sold and s.bag.items.size() == 3 and s.revenue == 2000, "stale sale cannot consume another set")
	result = s.sell_bag(s.bag.id, 11_000_001)
	check(result.sold and result.amount == 0 and s.revenue == 2000 and s.bag.items.is_empty(), "zero sale accepted without changing prior earnings")
	batch(s, 12_000_000, 3)
	for index in 3:
		s.collect(index, 21_500_001)
	result = s.sell_bag(s.bag.id, 21_500_001)
	check(result.sold and result.amount == 1000 and s.revenue == 3000, "multiple successful sets accumulate earnings")
	var previous: int = s.bag.id
	s.start(30_000_000)
	batch(s, 30_000_000, 3)
	for index in 3:
		s.collect(index, 38_000_000)
	check(s.revenue == 0 and not s.sell_bag(previous, 38_000_000).sold and s.bag.items.size() == 3, "retry clears earnings and invalidates old bag token")

func test_deadlines() -> void:
	for count in range(4):
		for offset in [-1, 0, 1]:
			var s = Session.new()
			s.start(0)
			batch(s, 51_000_000)
			for index in count:
				s.collect(index, 59_000_000)
			var id: int = s.bag.id
			var accepted: bool = s.collect(5, 60_000_000 + offset)
			check(accepted == (offset < 0 and count < 3), "collection at deadline / capacity boundary")
			check(s.bag.items.size() == (mini(count + 1, 3) if offset < 0 else 0), "deadline drops partial and full unsold bags")
			if offset >= 0:
				check(not s.running and s.bag.id != id and s.revenue == 0, "deadline invalidates bag without settlement")
				for mold in s.molds:
					check(mold.state == Mold.State.EMPTY, "deadline removes all uncollected bread")
			var sale = Session.new()
			sale.start(0)
			batch(sale, 0)
			for index in count:
				sale.collect(index, 8_000_000)
			var result: Dictionary = sale.sell_bag(sale.bag.id, 60_000_000 + offset)
			check(result.sold == (offset < 0 and count == 3), "only full bag strictly before deadline sells")
			check(sale.revenue == (2000 if offset < 0 and count == 3 else 0), "exact/late sale cannot earn")
			sale.advance(60_000_001)
			var earned: int = sale.revenue
			check(not sale.sell_bag(sale.bag.id, 60_000_002).sold and not sale.collect(0, 60_000_002), "post-end sale and collection blocked")
			check(sale.revenue == earned and sale.bag.items.is_empty(), "end preserves earned revenue only")
