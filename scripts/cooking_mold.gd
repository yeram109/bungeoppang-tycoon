extends RefCounted
## G001 model (Notion 13.1-13.3), intentionally separate from F001 Mold.
## Callers supply monotonic microseconds (Time.get_ticks_usec() in production).
## No input/tool selection, collection, bag, sale or round deadline logic here.
enum State { EMPTY, FIRST_BATTER, FILLING_ADDED, SIDE_1, SIDE_2, READY, BURNT }
enum SideQuality { COOKING, PERFECT, NORMAL, BURNT }
enum Quality { NONE, DELICIOUS, NORMAL, BURNT }

# Confirmed normal -> perfect -> burnt timing (Notion 13.3).
const FIRST_MIN_USEC := 5_000_000
const FIRST_NORMAL_END_USEC := 7_000_000
const FIRST_BURN_AFTER_USEC := 9_000_000
const SECOND_MIN_USEC := 3_000_000
const SECOND_NORMAL_END_USEC := 4_500_000
const SECOND_BURN_AFTER_USEC := 6_000_000

var state: State = State.EMPTY
var side_started_at: int = 0
# First-side quality is captured at flip/burn; the second side remains live
# until collection (future integration). READY is not a pause in cooking.
var first_quality: SideQuality = SideQuality.COOKING
var second_quality: SideQuality = SideQuality.COOKING
var quality: Quality = Quality.NONE

static func first_quality_at(elapsed_usec: int) -> SideQuality:
	return _quality_at(elapsed_usec, FIRST_MIN_USEC, FIRST_NORMAL_END_USEC, FIRST_BURN_AFTER_USEC)

static func second_quality_at(elapsed_usec: int) -> SideQuality:
	return _quality_at(elapsed_usec, SECOND_MIN_USEC, SECOND_NORMAL_END_USEC, SECOND_BURN_AFTER_USEC)

static func _quality_at(elapsed_usec: int, minimum: int, normal_end: int, burn_after: int) -> SideQuality:
	if elapsed_usec < minimum:
		return SideQuality.COOKING
	if elapsed_usec <= normal_end:
		return SideQuality.NORMAL
	if elapsed_usec <= burn_after:
		return SideQuality.PERFECT
	return SideQuality.BURNT

func elapsed_at(now: int) -> int:
	return maxi(0, now - side_started_at) if state != State.EMPTY else 0

func _on_first_side() -> bool:
	return state in [State.FIRST_BATTER, State.FILLING_ADDED, State.SIDE_1]

func advance(now: int) -> void:
	if _on_first_side() and first_quality_at(elapsed_at(now)) == SideQuality.BURNT:
		first_quality = SideQuality.BURNT
		state = State.BURNT
		quality = Quality.BURNT
	elif state in [State.SIDE_2, State.READY]:
		second_quality = second_quality_at(elapsed_at(now))
		if second_quality == SideQuality.BURNT:
			state = State.BURNT
			quality = Quality.BURNT
		elif second_quality != SideQuality.COOKING:
			state = State.READY
			quality = Quality.DELICIOUS if first_quality == SideQuality.PERFECT and second_quality == SideQuality.PERFECT else Quality.NORMAL

func add_batter(now: int) -> bool:
	advance(now)
	if state == State.EMPTY:
		state = State.FIRST_BATTER
		side_started_at = now
		return true
	if state == State.FILLING_ADDED:
		state = State.SIDE_1
		return true
	return false

func add_filling(now: int) -> bool:
	advance(now)
	if state != State.FIRST_BATTER:
		return false
	state = State.FILLING_ADDED
	return true

func flip(now: int) -> bool:
	advance(now)
	if state != State.SIDE_1:
		return false
	var judged := first_quality_at(elapsed_at(now))
	if judged == SideQuality.COOKING:
		return false
	first_quality = judged
	state = State.SIDE_2
	side_started_at = now
	return true
