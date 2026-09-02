# Ddirori DocC Tutorial

Apple Vision Pro에서 검지 끝으로 네 개의 Beat Zone을 따라가며 4/4박자 지휘를 연습하는 **Ddirori**를 단계별로 구현하는 DocC 튜토리얼입니다.

## 다루는 내용

1. SwiftUI `WindowGroup`과 `ImmersiveSpace` 구성
2. `ARKitSession`과 `HandTrackingProvider`로 검지 끝 좌표 계산
3. RealityKit Beat Zone과 경계 진입 기반 순서 판정
4. 양손 선택, 추적 유실 복구, 3회 연속 성공 흐름

## 요구 사항

- macOS와 Xcode 26 이상
- visionOS 26 이상 SDK
- 실기기 손 추적 확인 시 Apple Vision Pro
- GitHub Pages 배포 시 Public GitHub Repository

## 로컬 정적 빌드

```sh
./Scripts/build-docs.sh
```

결과는 `.build/2026TechMap_tutorial`에 생성됩니다. GitHub Pages와 같은 base path 조건으로 확인하려면 다음 명령을 사용합니다.

```sh
cd .build
python3 -m http.server 8000
```

브라우저에서 `http://localhost:8000/2026TechMap_tutorial/tutorials/ddirori/`를 엽니다.

## DocC 미리보기

```sh
./Scripts/preview-docs.sh
```

## GitHub Pages

`main` 브랜치에 push하면 `.github/workflows/deploy-docs.yml`이 DocC 정적 사이트를 빌드하고 GitHub Pages에 배포합니다. 저장소의 **Settings → Pages → Source**는 **GitHub Actions**로 설정해야 합니다.

> 실제 Hand Tracking은 visionOS Simulator에서 제공되지 않습니다. UI 배치와 빌드는 Simulator에서 확인할 수 있지만, 손 선택과 Beat 판정은 Apple Vision Pro 실기기에서 확인합니다.
