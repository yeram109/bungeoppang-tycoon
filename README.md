# 붕어빵 장인

짧은 게임 제작 이벤트를 위한 Windows 오프라인 2D 미니 타이쿤 프로젝트입니다. F001 핵심 플레이(60초, 독립된 틀 3개, 뒤집기·판매·자동 폐기, 점수)와 F002 닉네임·결과 화면·로컬 TOP 10 저장을 구현했습니다. 최종 디자인과 제출물 구성은 포함하지 않습니다.

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

게임 시작 후 각 틀을 클릭하여 반죽 투입 → 뒤집기 → 판매합니다. 각 면은 3초 미만 입력 무시, 3~4.5초 완벽, 4.5초 초과~6초 일반, 6초 초과 자동 폐기입니다. 양면 완벽이면 100점, 그 외 정상 판매는 60점입니다. 60초 종료 시 미완성 조리는 판매되지 않으며, 결과 화면에서 다시 시작할 수 있습니다.

시간 판정은 `Time.get_ticks_usec()`의 단조 증가 시각을 사용합니다. 로직 테스트는 같은 코드에 시각을 직접 전달하여 실제 대기 없이 경계값을 확인합니다.

```powershell
& $godot --headless --path . --script res://tests/test_core.gd
& $godot --headless --path . --script res://tests/test_ranking.gd
```

실패 시 종료 코드 1을 반환합니다. 테스트 스크립트는 Windows Export에서 제외합니다.

닉네임은 앞뒤 공백을 제거한 1~12자입니다. 매 판 종료 시 닉네임·점수·UTC 플레이 시각을 `user://rankings.json`에 저장합니다. 같은 이름도 개별 기록이며, 점수 내림차순 → 시각 오름차순 → 동일 시각 저장 순서로 TOP 10만 유지합니다. 결과 화면의 최고 점수는 이 PC 기준입니다. 다시 하기는 같은 이름을 유지하고, 시작 화면으로 돌아가면 이름을 바꿀 수 있습니다.

Windows에서는 **입력·변경** 버튼으로 기본 입력창을 엽니다. 이 PC의 Godot 4.7.2 기본 LineEdit에서 재현된 한글 연속 조합 손실을 피하기 위해 엔진이 제공하는 Windows 네이티브 입력창을 사용합니다.

입력창의 **OK**는 임시 입력만 마칩니다. 다음 확인창에서 **적용**을 눌러야 이름이 바뀌며, **취소**(또는 확인창의 Esc/X)는 기존 이름을 유지합니다. 이름이 없는 상태에서도 취소할 수 있습니다. 네이티브 입력창 자체는 Esc/Alt+F4/X를 지원하지 않아, 취소하려면 먼저 OK로 다음 확인창으로 이동해야 합니다.

Windows 기본 저장 위치는 `%APPDATA%/Godot/app_userdata/붕어빵 장인/rankings.json`입니다. 손상된 데이터는 빈 랭킹으로 시작하고 다음 정상 저장으로 복구합니다. 읽기 실패 시 기존 데이터 보호를 위해 저장을 막고, 쓰기·교체 실패 시 결과 화면에 실패를 안내합니다. 임시 파일 기록·확인 후 원본을 교체합니다. 자동 테스트는 `.tools/test-data/`의 별도 경로만 사용합니다.

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
