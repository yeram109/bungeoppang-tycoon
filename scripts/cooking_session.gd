extends RefCounted
## Cooking, tools and deadline, with explicit collection/sale APIs for G002-B.
## Collection is routed by the UI; SIDE_1 flipping takes priority over tools.
const Board = preload("res://scripts/cooking_board.gd")
const Mold = preload("res://scripts/cooking_mold.gd")
const Bag = preload("res://scripts/sales_bag.gd")
const DURATION_USEC := 60_000_000
const MOLD_COUNT := Board.MOLD_COUNT
enum Tool { NONE, BATTER, FILLING }
var board = Board.new()
var bag = Bag.new()
var revenue := 0
var molds: Array:
	get: return board.molds
var running := false
var started_at := 0
var selected_tool: Tool = Tool.NONE
var feedback: Array[String] = []
var feedback_at: Array[int] = []

func _init() -> void:
	_clear()

func _clear() -> void:
	board.reset()
	bag.reset()
	selected_tool = Tool.NONE
	feedback.assign(["", "", "", "", "", ""])
	feedback_at.assign([0, 0, 0, 0, 0, 0])

func start(now: int) -> void:
	_clear()
	revenue = 0
	started_at = now
	running = true

func remaining_usec(now: int) -> int:
	return clampi(DURATION_USEC - (now - started_at), 0, DURATION_USEC)

func advance(now: int) -> void:
	if not running:
		return
	# Deadline wins over tool changes, ingredients, flipping and cooking.
	if now - started_at >= DURATION_USEC:
		running = false
		_clear()
		return
	board.advance(now)

func select_tool(tool: Tool, now: int) -> void:
	advance(now)
	if running and tool in [Tool.BATTER, Tool.FILLING]:
		selected_tool = Tool.NONE if selected_tool == tool else tool

func cancel_tool(now: int) -> void:
	advance(now)
	if running:
		selected_tool = Tool.NONE

func collect(index: int, now: int) -> bool:
	# Time/expiry can change food quality even if collection is rejected.
	advance(now)
	if not running or selected_tool != Tool.NONE or index < 0 or index >= MOLD_COUNT:
		return false
	var mold = molds[index]
	if mold.state not in [Mold.State.READY, Mold.State.BURNT]:
		return false
	if not bag.try_add(mold.quality):
		return false
	# Consume only after the bag accepted the immutable quality value.
	board.molds[index] = Mold.new()
	feedback[index] = ""
	feedback_at[index] = 0
	return true

func sell_bag(expected_bag_id: int, now: int) -> Dictionary:
	# G002-B should call only for a valid sale-zone drop, with its captured ID.
	advance(now)
	if not running:
		return {"sold": false, "amount": 0}
	var result: Dictionary = bag.sell(expected_bag_id)
	if result.sold:
		revenue += result.amount
	return result

func click_mold(index: int, now: int) -> bool:
	advance(now)
	if not running or index < 0 or index >= MOLD_COUNT:
		return false
	# Advance above must run first: an expired first side is BURNT, not flippable.
	if molds[index].state == Mold.State.SIDE_1:
		var flipped: bool = board.flip(index, now)
		feedback_at[index] = now
		feedback[index] = "뒤집기 완료 · 선택 도구 유지" if flipped else "첫 면 5초부터 뒤집을 수 있습니다"
		return flipped
	var accepted := false
	match selected_tool:
		Tool.BATTER: accepted = board.add_batter(index, now)
		Tool.FILLING: accepted = board.add_filling(index, now)
		Tool.NONE: accepted = board.flip(index, now)
	feedback_at[index] = now
	if accepted:
		feedback[index] = "뒤집기 완료" if selected_tool == Tool.NONE else "재료 투입 완료"
		selected_tool = Tool.NONE
	else:
		if molds[index].state in [Mold.State.READY, Mold.State.BURNT]:
			feedback[index] = "수거는 아직 지원하지 않습니다"
		elif selected_tool != Tool.NONE:
			feedback[index] = "재료 순서를 확인하세요 · 도구 유지"
		elif molds[index].state == Mold.State.SIDE_1:
			feedback[index] = "첫 면 5초부터 뒤집을 수 있습니다"
		else:
			feedback[index] = "필요한 재료와 조리 상태를 확인하세요"
	return accepted
