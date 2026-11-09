# 붕어빵 장인

짧은 게임 제작 이벤트를 위한 Windows 오프라인 2D 미니 타이쿤 프로젝트입니다. 현재 G002-B는 60초 동안 독립된 틀 6개를 도구로 조작합니다. F002 닉네임 입력을 유지하며 기존 점수 TOP 10은 읽기 전용으로 표시합니다. 붕어빵을 수거해 3개 봉투를 드래그 판매하며, 새 원화 랭킹 저장은 G003에서 연결합니다. 최종 디자인과 제출물 구성은 포함하지 않습니다.

- 기획 기준: [Notion MVP 기획 v0.1](https://app.notion.com/p/41387148aa578117907afd28937e1b5f)
- 엔진: **Godot 4.7.2 stable**, 일반 GDScript 에디터 (x86_64, Compatibility 렌더러)
- 공식 다운로드: https://godotengine.org/download/archive/4.7.2-stable/
- 한글 폰트: [Noto Sans KR](https://github.com/google/fonts/tree/main/ofl/notosanskr), 동봉한 `assets/fonts/OFL.txt` 라이선스 적용

## 로컬 실행

Godot에서 저장소 루트의 `project.godot`를 열고 **F6**(현재 메인 씬) 또는 **F5**(프로젝트)를 누릅니다.

이번 Windows 환경의 포터블 에디터 경로는 `C:\Users\kyj57\Documents\bungeoppang-tycoon\.tools\godot\Godot_v4.7.2-stable_win64.exe`입니다. `.tools`는 Git에 포함하지 않습니다. 다른 PC에서는 공식 에디터를 준비하고 아래 경로를 변경합니다.

저장소 루트에서 PowerShell로 실행:

```powershell
$godot = '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --editor --import
& $godot --path . --editor
& $godot --path .
```

## 핵심 플레이 및 테스트

양은주전자 선택 → 틀에 첫 반죽 → 주걱 선택 → 팥 → 주전자 선택 → 두 번째 반죽 → 재료 준비가 끝난 틀 클릭으로 뒤집습니다. 뒤집기는 도구 선택 여부와 관계없이 우선 시도하며, 성공·실패 시 선택한 도구를 유지합니다. 유효한 재료 투입은 도구를 자동 해제하며, 같은 도구 재클릭 또는 우클릭으로도 해제합니다. 잘못된 재료 입력은 도구 선택을 유지합니다.

첫 면은 첫 반죽부터 5~7초 완벽, 7초 초과~9초 일반, 9초 초과 탐입니다. 두 번째 면은 뒤집은 시점부터 3~4.5초 완벽, 4.5초 초과~6초 일반, 6초 초과 탐입니다. 완성 후에도 계속 조리되며 탄 빵은 틀에 남습니다. 도구 없이 완성·탄 빵을 클릭하면 품질을 보존해 봉투에 수거합니다. 봉투는 최대 3개이며, 가득 차면 먼저 판매해야 합니다. 3개 봉투를 판매 영역에 드롭하면 수익(원)을 합산하고 새 빈 봉투를 준비합니다. 탄 빵 3개의 0원 판매도 성공입니다. 영역 밖 드롭, Esc·우클릭·창 포커스 이탈은 내용물을 유지하고 드래그를 취소합니다. 60초 종료 시 틀·도구·미판매 봉투·드래그를 비우고, 다시 하기는 같은 닉네임으로 초기화합니다. 기존 F001 모델과 테스트는 별도로 유지합니다.

시간 판정은 `Time.get_ticks_usec()`의 단조 증가 시각을 사용합니다. 로직 테스트는 같은 코드에 시각을 직접 전달하여 실제 대기 없이 경계값을 확인합니다.

```powershell
& $godot --headless --path . --script res://tests/test_core.gd
& $godot --headless --path . --script res://tests/test_ranking.gd
& $godot --headless --path . --script res://tests/test_cooking.gd
& $godot --headless --path . --script res://tests/test_cooking_ui.gd
& $godot --headless --path . --script res://tests/test_sales.gd
& $godot --headless --path . --script res://tests/test_sales_ui.gd
```

실패 시 종료 코드 1을 반환합니다. 테스트 스크립트는 Windows Export에서 제외합니다.

닉네임은 앞뒤 공백을 제거한 1~12자입니다. 기존 `user://rankings.json`은 읽기만 하며 종료·다시 하기·손상 파일 로드 시에도 생성·수정·삭제하지 않습니다. 이번 버전의 판매 수익은 기존 점수 랭킹에 추가하지 않습니다.

Windows에서는 **입력·변경** 버튼으로 기본 입력창을 엽니다. 이 PC의 Godot 4.7.2 기본 LineEdit에서 재현된 한글 연속 조합 손실을 피하기 위해 엔진이 제공하는 Windows 네이티브 입력창을 사용합니다.

입력창의 **OK**는 임시 입력만 마칩니다. 다음 확인창에서 **적용**을 눌러야 이름이 바뀌며, **취소**(또는 확인창의 Esc/X)는 기존 이름을 유지합니다. 이름이 없는 상태에서도 취소할 수 있습니다. 네이티브 입력창 자체는 Esc/Alt+F4/X를 지원하지 않아, 취소하려면 먼저 OK로 다음 확인창으로 이동해야 합니다.

기존 Windows 기록 위치는 `%APPDATA%/Godot/app_userdata/붕어빵 장인/rankings.json`입니다. 기존 저장 모듈의 정렬·복구·중복 방지 검사는 유지하며, 자동 테스트는 `.tools/test-data/`의 별도 경로만 사용합니다.

## Windows Export

에디터와 동일한 **4.7.2 stable Export Templates**가 필요합니다. 일반 설치는 에디터의 **Editor > Manage Export Templates**에서 설치합니다. 이번 포터블 구성은 `_sc_` 파일로 자체 데이터 폴더를 사용하며, Windows x86_64 debug/release 템플릿은 `.tools/godot/editor_data/export_templates/4.7.2.stable/`에 준비되어 있습니다.

**Project > Export > Windows Desktop > Export Project**에서 Release로 내보내거나, 저장소 루트에서 다음을 실행합니다.

```powershell
$godot = '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force build/windows | Out-Null
& $godot --headless --path . --editor --import
& $godot --headless --path . --export-release 'Windows Desktop'
& '.\build\windows\bungeoppang-tycoon.exe'
```

`build/windows/bungeoppang-tycoon.exe`와 같은 이름의 `.pck`를 항상 함께 배포합니다. 폰트와 폰트 라이선스는 `.pck`에 포함됩니다. 캐시, 도구 및 빌드 결과는 Git에서 제외합니다.
