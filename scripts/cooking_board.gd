extends RefCounted
## Six independent molds, all using the round's fixed difficulty.
## An action returns true only when its ingredient/flip was accepted.
## Time still advances on rejected actions, including invalid mold indexes.
const Mold = preload("res://scripts/cooking_mold.gd")
const MOLD_COUNT := 6
var molds: Array = []

var _difficulty: Mold.Difficulty
var difficulty: Mold.Difficulty:
	get: return _difficulty

func _init(mode: Mold.Difficulty = Mold.Difficulty.NORMAL) -> void:
	_difficulty = mode
	reset()

func reset() -> void:
	molds.clear()
	for index in MOLD_COUNT:
		molds.append(Mold.new(difficulty))

func advance(now: int) -> void:
	for mold in molds:
		mold.advance(now)

func add_batter(index: int, now: int) -> bool:
	advance(now)
	return molds[index].add_batter(now) if _valid_index(index) else false

func add_filling(index: int, now: int) -> bool:
	advance(now)
	return molds[index].add_filling(now) if _valid_index(index) else false

func flip(index: int, now: int) -> bool:
	advance(now)
	return molds[index].flip(now) if _valid_index(index) else false

func _valid_index(index: int) -> bool:
	return index >= 0 and index < molds.size()
