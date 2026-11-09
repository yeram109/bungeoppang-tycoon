extends RefCounted
## One bag, holding snapshots of at most three cooked qualities (Notion 13.4-5).
const Mold = preload("res://scripts/cooking_mold.gd")
const CAPACITY := 3
var _items: Array[int] = []
var _id := 0
var id: int:
	get: return _id
var items: Array[int]:
	get: return _items.duplicate()

func reset() -> void:
	_items.clear()
	# Never reuse an ID on retry/end: delayed drops cannot sell a newer bag.
	_id += 1

func try_add(quality: int) -> bool:
	if _items.size() >= CAPACITY or quality not in [Mold.Quality.DELICIOUS, Mold.Quality.NORMAL, Mold.Quality.BURNT]:
		return false
	_items.append(quality)
	return true

static func price_for(qualities: Array) -> int:
	# -1 means invalid/incomplete; 0 is a valid sale of three burnt breads.
	if qualities.size() != CAPACITY:
		return -1
	var total := 0
	for quality in qualities:
		if not quality is int:
			return -1
		match quality:
			Mold.Quality.DELICIOUS: total += 2000
			Mold.Quality.NORMAL: total += 1000
			Mold.Quality.BURNT: pass
			_: return -1
	return 100 * floori(total / 300.0)

func sell(expected_id: int) -> Dictionary:
	var amount := price_for(_items)
	if expected_id != _id or amount < 0:
		return {"sold": false, "amount": 0}
	reset()
	return {"sold": true, "amount": amount}
