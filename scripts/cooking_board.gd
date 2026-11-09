extends RefCounted
## Six independent G001 molds; not connected to the existing three-mold UI.
## An action returns true only when its ingredient/flip was accepted.
## Time still advances on rejected actions, including invalid mold indexes.
const Mold = preload("res://scripts/cooking_mold.gd")
const MOLD_COUNT := 6
var molds: Array = []

func _init() -> void:
	reset()

func reset() -> void:
	molds.clear()
	for index in MOLD_COUNT:
		molds.append(Mold.new())

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
