# 나짜 새싹 노트 아이콘

2026-10-11 사용자가 첨부한 새싹 노트·샐러드·하트 이미지를 앱 아이콘으로 사용합니다.
원본 파일은 `naazza-icon-sprout-note.png`이며 첨부 이미지의 구도와 흰 여백을 유지합니다.

## 플랫폼 리소스 재생성

Python과 Pillow가 설치된 환경에서 실행합니다.

```powershell
python tool/generate_launcher_icons.py
```

Android의 기존 PNG 및 적응형 아이콘, iOS·macOS AppIcon, Windows ICO,
웹 아이콘과 파비콘을 동일한 원본에서 생성합니다.