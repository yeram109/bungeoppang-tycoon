# 붕어빵 장인

짧은 게임 제작 이벤트를 위한 Windows 오프라인 2D 미니 타이쿤 프로젝트입니다. 현재는 개발 환경 확인 화면만 있으며, 게임 기능은 아직 구현하지 않았습니다.

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
