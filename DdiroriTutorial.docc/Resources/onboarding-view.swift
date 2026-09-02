import SwiftUI

/// 지휘 연습 온보딩 화면 전체를 구성하는 최상위 뷰입니다.
///
/// 아래 두 레이어를 겹쳐 보여줍니다.
/// 1. `ConductingPathTraceView` — 반복 재생되는 지휘 궤적 선
/// 2. `OnboardingPromptOverlay` — 안내 문구 + "시작하기" 버튼
///
/// `ImmersiveView`가 이 뷰를 RealityView attachment로 감싸 Immersive Space 안,
/// 실제 연습 Zone과 같은 위치에 3D로 배치합니다 (`ConductingLayout` 참고).
struct ConductorOnboardingView: View {
    var onStart: () -> Void = {}

    var body: some View {
        ZStack {
            ConductingPathTraceView()
            OnboardingPromptOverlay(onStart: onStart)
        }
        .frame(width: ConductingLayout.windowSize.width, height: ConductingLayout.windowSize.height)
    }
}

#Preview {
    ConductorOnboardingView()
}
