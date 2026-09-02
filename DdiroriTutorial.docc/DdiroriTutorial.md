# Ddirori: 공간에서 익히는 4/4박자

검지 끝을 추적하고 네 개의 Beat Zone을 순서대로 통과하며 visionOS 공간 튜토리얼을 완성합니다.

## Overview

Ddirori는 SwiftUI, ARKit, RealityKit을 연결해 사용자의 검지 움직임을 4/4박자 학습 경험으로 바꾸는 visionOS 앱입니다. 이 튜토리얼은 `scylla/real-device-cleanup`이 반영된 최종 앱과 같이 Apple Vision Pro의 실제 Hand Tracking에 집중합니다.

완성하는 흐름은 다음과 같습니다.

- `WindowGroup`에서 `ImmersiveSpace`를 열고 시작 창을 닫습니다.
- 온보딩을 실제 Beat Zone과 같은 위치의 RealityView attachment로 배치합니다.
- `HandTrackingProvider`가 제공하는 양손 Anchor 중 사용 중인 손을 안정적으로 선택하고 검지 끝 Joint의 변환을 결합합니다.
- RealityKit 공간에 `1 → 2 → 3 → 4` Beat Zone을 배치합니다.
- 거리와 Zone 경계 진입을 이용해 중복 없이 순서를 판정합니다.
- 추적 유실과 복구를 처리하고 세 사이클 연속 성공 시 튜토리얼을 완료합니다.

## Topics

### Tutorials

- <doc:Ddirori>
- <doc:01-ProjectSetup>
- <doc:02-HandTracking>
- <doc:03-BeatJudging>
- <doc:04-TutorialExperience>

### Requirements

- Xcode 26 이상
- visionOS 26 이상
- 실제 손 추적 확인을 위한 Apple Vision Pro

> Important: visionOS Simulator에서는 ARKit Hand Tracking 입력을 받을 수 없습니다. UI 배치와 빌드는 Simulator에서 확인할 수 있지만, 손 선택·좌표 정렬·Beat 판정은 Apple Vision Pro 실기기에서 검증하세요.
