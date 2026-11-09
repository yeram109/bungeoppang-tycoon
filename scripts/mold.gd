extends RefCounted
## Pure state: monotonic microseconds are supplied by the caller.
enum State { EMPTY, SIDE_1, SIDE_2 }
enum Quality { COOKING, PERFECT, NORMAL, BURNT }
var state: State = State.EMPTY
var side_started_at: int = 0
var first_quality: Quality = Quality.COOKING
var feedback: String = "클릭하여 반죽 투입"

static func quality_at(elapsed_usec: int) -> Quality:
	if elapsed_usec < 3_000_000:
		return Quality.COOKING
	if elapsed_usec <= 4_500_000:
		return Quality.PERFECT
	if elapsed_usec <= 6_000_000:
		return Quality.NORMAL
	return Quality.BURNT

func elapsed_at(now: int) -> int:
	return maxi(0, now - side_started_at) if state != State.EMPTY else 0

func advance(now: int) -> bool:
	if state != State.EMPTY and quality_at(elapsed_at(now)) == Quality.BURNT:
		state = State.EMPTY
		first_quality = Quality.COOKING
		feedback = "탐 · 자동 폐기 (0점)\n클릭하여 다시 투입"
		return true
	return false

func click(now: int) -> int:
	if advance(now):
		return 0
	if state == State.EMPTY:
		state = State.SIDE_1
		side_started_at = now
		first_quality = Quality.COOKING
		feedback = "첫 면 조리 시작"
		return 0
	var quality := quality_at(elapsed_at(now))
	if quality == Quality.COOKING:
		feedback = "아직 조리 중 · 3초부터 클릭"
		return 0
	if state == State.SIDE_1:
		first_quality = quality
		state = State.SIDE_2
		side_started_at = now
		feedback = "첫 면 %s · 뒤집기 완료" % ("완벽" if quality == Quality.PERFECT else "일반")
		return 0
	var points := 100 if first_quality == Quality.PERFECT and quality == Quality.PERFECT else 60
	# Consume the sale before returning points; repeated clicks cannot resell it.
	state = State.EMPTY
	first_quality = Quality.COOKING
	feedback = "판매 완료 · +%d점" % points
	return points
