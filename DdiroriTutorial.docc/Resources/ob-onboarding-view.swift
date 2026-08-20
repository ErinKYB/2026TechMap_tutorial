import SwiftUI

/// 지휘 연습 온보딩 화면 전체를 구성하는 최상위 뷰입니다.
///
/// 아래 세 레이어를 하나의 `WindowGroup` 화면 안에 겹쳐 보여줍니다.
/// 1. `ConductingPathTraceView` — 반복 재생되는 지휘 궤적 선
/// 2. `ConductingParticleTrailView` — 그 경로를 따라 움직이는 "2meter" 파티클 (RealityView)
/// 3. `OnboardingPromptOverlay` — 안내 문구 + "시작하기" 버튼
///
/// 사용 예:
/// ```swift
/// WindowGroup {
///     ConductorOnboardingView {
///         // "시작하기"를 눌렀을 때 다음 화면/모드로 전환
///     }
/// }
/// ```
struct ConductorOnboardingView: View {
    var onStart: () -> Void = {}

    var body: some View {
        ZStack {
            ConductingPathTraceView()
                .padding(60)

            ConductingParticleTrailView()

            OnboardingPromptOverlay(onStart: onStart)
        }
        .frame(width: 500, height: 500)
    }
}

#Preview {
    ConductorOnboardingView()
}
