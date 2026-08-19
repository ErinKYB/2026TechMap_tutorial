# Ddirori: 공간에서 익히는 4/4박자

검지 끝을 추적하고 네 개의 Beat Zone을 순서대로 통과하며 visionOS 공간 튜토리얼을 완성합니다.

## Overview

Ddirori는 SwiftUI, ARKit, RealityKit을 연결해 사용자의 검지 움직임을 4/4박자 학습 경험으로 바꾸는 visionOS 앱입니다. 이 튜토리얼에서는 실제 Hand Tracking과 시뮬레이터 커서 입력이 하나의 판정 파이프라인을 공유하도록 설계합니다.

완성하는 흐름은 다음과 같습니다.

- `WindowGroup`에서 입력 방식을 선택하고 `ImmersiveSpace`를 엽니다.
- `HandTrackingProvider`가 제공하는 손 Anchor와 검지 끝 Joint의 변환을 결합합니다.
- RealityKit 공간에 `1 → 2 → 3 → 4` Beat Zone을 배치합니다.
- 거리와 Zone 경계 진입을 이용해 중복 없이 순서를 판정합니다.
- 추적 유실을 처리하고 세 사이클 연속 성공 시 튜토리얼을 완료합니다.

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

> Important: visionOS Simulator에서는 ARKit Hand Tracking 입력을 받을 수 없습니다. 네 번째 챕터의 커서 시뮬레이션으로 같은 판정 로직을 테스트하세요.
