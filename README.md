# 붕어빵 장인

짧은 게임 제작 이벤트를 위한 Windows 오프라인 2D 미니 타이쿤 프로젝트입니다. F001 핵심 플레이(60초, 독립된 틀 3개, 뒤집기·판매·자동 폐기, 점수)를 구현했습니다. 닉네임·랭킹·저장 및 최종 디자인은 후속 F002 범위입니다.

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
```

실패 시 종료 코드 1을 반환합니다. 테스트 스크립트는 Windows Export에서 제외합니다.

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
