extends RefCounted
## A small local TOP 10 store. A failed write never replaces the in-memory ranking.
const LIMIT := 10
const MAX_INTEGER := 9_007_199_254_740_990
var path: String
var records: Array = []
var next_order := 0
var load_message := ""
var last_error := ""
var _read_blocked := false

func _init(save_path: String = "user://rankings.json") -> void:
	path = save_path

static func nickname_error(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return "닉네임을 입력해 주세요."
	if trimmed.length() > 12:
		return "닉네임은 1~12자로 입력해 주세요."
	for index in trimmed.length():
		if trimmed.unicode_at(index) < 32 or trimmed.unicode_at(index) == 127:
			return "닉네임에는 줄바꿈이나 제어 문자를 사용할 수 없습니다."
	return ""

static func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= MAX_INTEGER and floor(value) == value

static func _earlier(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	if a.played_at != b.played_at:
		return a.played_at < b.played_at
	return a.order < b.order

func load_records() -> void:
	records = []
	next_order = 0
	load_message = ""
	_read_blocked = false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND and not DirAccess.dir_exists_absolute(path):
			return
		_read_blocked = true
		load_message = "랭킹을 읽을 수 없습니다. 기존 파일 보호를 위해 저장하지 않습니다."
		return
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		_read_blocked = true
		load_message = "랭킹 읽기 실패. 기존 파일 보호를 위해 저장하지 않습니다."
		return
	var json := JSON.new()
	if json.parse(text) != OK or not _valid_document(json.data):
		load_message = "랭킹 파일이 손상되어 빈 랭킹으로 시작합니다. 다음 결과부터 새로 저장합니다."
		return
	records = json.data.records.duplicate(true)
	for record in records:
		record.score = int(record.score)
		record.played_at = int(record.played_at)
		record.order = int(record.order)
	next_order = int(json.data.next_order)
	records.sort_custom(_earlier)
	if records.size() > LIMIT:
		records.resize(LIMIT)

func _valid_document(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("records") is Array or not _whole_number(data.get("next_order")):
		return false
	var orders := {}
	for record in data.records:
		if not record is Dictionary or not record.get("nickname") is String:
			return false
		if not nickname_error(record.nickname).is_empty() or record.nickname != record.nickname.strip_edges():
			return false
		if not _whole_number(record.get("score")) or not _whole_number(record.get("played_at")) or not _whole_number(record.get("order")):
			return false
		if record.order >= data.next_order or orders.has(record.order):
			return false
		orders[record.order] = true
	return true

func best_score() -> int:
	return int(records[0].score) if not records.is_empty() else 0

func add_result(nickname: String, score: int, played_at: int) -> bool:
	last_error = ""
	if _read_blocked:
		last_error = load_message
		return false
	if not nickname_error(nickname).is_empty() or not _whole_number(score) or not _whole_number(played_at) or next_order >= MAX_INTEGER:
		last_error = "기록 데이터가 올바르지 않습니다."
		return false
	var candidate := records.duplicate(true)
	candidate.append({"nickname": nickname.strip_edges(), "score": score, "played_at": played_at, "order": next_order})
	candidate.sort_custom(_earlier)
	if candidate.size() > LIMIT:
		candidate.resize(LIMIT)
	var document := {"version": 1, "next_order": next_order + 1, "records": candidate}
	if not _write_document(JSON.stringify(document, "\t")):
		return false
	records = candidate
	next_order += 1
	load_message = ""
	return true

func _write_document(text: String) -> bool:
	# Same-directory staging + replace: never truncate the existing destination.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "임시 파일을 만들 수 없습니다. 저장 경로와 쓰기 권한을 확인해 주세요."
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_string(temporary) != text:
		last_error = "파일 쓰기를 완료하지 못했습니다. 기존 랭킹은 유지됩니다."
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		last_error = "랭킹 파일을 교체할 수 없습니다. 기존 랭킹은 유지됩니다."
		return false
	return true
