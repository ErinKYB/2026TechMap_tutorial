import SwiftUI
import RealityKit

/// "2meter" 파티클 이미터가 지휘 경로를 따라 움직이는 RealityView 레이어입니다.
/// `ConductingPathTraceView`와 같은 프레임에 겹쳐서 사용하세요(`ConductorOnboardingView` 참고).
///
/// `WindowGroup`(볼륨/몰입형이 아닌 평범한 창) 안에 놓여도, RealityKit 콘텐츠는
/// 실제 스테레오 깊이감으로 렌더링됩니다.
struct ConductingParticleTrailView: View {
    var emitterEntityName: String = "2meter"
    var worldScale: Float = ConductingWorldMapping.defaultWorldScale

    @State private var controller: ConductingParticleTrailController

    init(
        emitterEntityName: String = "2meter",
        worldScale: Float = ConductingWorldMapping.defaultWorldScale
    ) {
        self.emitterEntityName = emitterEntityName
        self.worldScale = worldScale
        _controller = State(initialValue: ConductingParticleTrailController(
            emitterEntityName: emitterEntityName,
            worldScale: worldScale
        ))
    }

    var body: some View {
        RealityView { content in
            await controller.start(in: content)
        }
        .onDisappear {
            controller.stop()
        }
    }
}
