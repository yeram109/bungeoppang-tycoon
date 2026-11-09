extends RefCounted
## Round deadline and score, independent of the scene tree and rendering.
const Mold = preload("res://scripts/mold.gd")
const DURATION_USEC: int = 60_000_000
const MOLD_COUNT: int = 3
var molds: Array = []
var running: bool = false
var started_at: int = 0
var score: int = 0

func _init() -> void:
	_reset_molds()

func _reset_molds() -> void:
	molds.clear()
	for index in MOLD_COUNT:
		molds.append(Mold.new())

func start(now: int) -> void:
	_reset_molds()
	score = 0
	started_at = now
	running = true

func remaining_usec(now: int) -> int:
	return clampi(DURATION_USEC - (now - started_at), 0, DURATION_USEC)

func advance(now: int) -> Array[int]:
	var discarded: Array[int] = []
	if not running:
		return discarded
	# The deadline wins over cooking/input, including after a stalled frame.
	if now - started_at >= DURATION_USEC:
		running = false
		return discarded
	for index in molds.size():
		if molds[index].advance(now):
			discarded.append(index)
	return discarded

func click_mold(index: int, now: int) -> int:
	var discarded := advance(now)
	if not running or index < 0 or index >= molds.size() or index in discarded:
		return 0
	var points: int = molds[index].click(now)
	score += points
	return points
