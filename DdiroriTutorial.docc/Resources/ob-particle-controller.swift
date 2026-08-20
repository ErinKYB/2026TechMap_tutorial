import SwiftUI
import RealityKit
import Foundation
import RealityKitContent
// ⚠️ 위 `RealityKitContent`는 Xcode visionOS App 템플릿이 기본으로 만들어주는
// Reality Composer Pro 패키지 이름을 가정한 것입니다. 프로젝트 내비게이터에서
// 이 패키지 이름이 다르게 되어 있다면(예: 프로젝트 이름을 따라 자동으로 바뀐 경우),
// 위 import 문을 실제 이름으로 바꿔주세요.

/// Reality Composer Pro에서 만든 파티클 이미터("2meter")를 불러와,
/// 매 프레임 지휘 경로를 따라 위치를 갱신하는 컨트롤러입니다.
///
/// `ConductingParticleTrailView`의 `RealityView` `make` 클로저에서
/// `start(in:)`을 한 번 호출해 사용하세요.
@MainActor
final class ConductingParticleTrailController {
    private let emitterEntityName: String
    private let worldScale: Float
    private let loopDuration: TimeInterval

    private var emitterEntity: Entity?
    private var elapsedTime: TimeInterval = 0
    // content.subscribe(to:_:)는 Combine의 Cancellable이 아니라
    // RealityKit 자체의 EventSubscription을 반환합니다.
    private var updateSubscription: EventSubscription?

    init(
        emitterEntityName: String = "2meter",
        worldScale: Float = ConductingWorldMapping.defaultWorldScale,
        loopDuration: TimeInterval = ConductingAnimationTiming.loopDuration
    ) {
        self.emitterEntityName = emitterEntityName
        self.worldScale = worldScale
        self.loopDuration = loopDuration
    }

    /// 이미터를 씬에 불러와 추가하고, 매 프레임 위치 갱신 구독을 시작합니다.
    func start(in content: RealityViewContent) async {
        await loadEmitterIfNeeded(into: content)
        subscribeToUpdates(content: content)
    }

    /// 뷰가 사라질 때 호출해 프레임 구독을 정리합니다.
    /// EventSubscription은 참조가 사라지면(deinit) 자동으로 구독이 해제되므로
    /// nil을 대입하는 것만으로 정리됩니다.
    func stop() {
        updateSubscription = nil
    }

    private func loadEmitterIfNeeded(into content: RealityViewContent) async {
        guard emitterEntity == nil else { return }

        do {
            // "2meter"는 Reality Composer Pro에서 만든 파티클 이미터 엔티티 이름입니다.
            let emitter = try await Entity(named: emitterEntityName, in: realityKitContentBundle)
            emitter.position = ConductingWorldMapping.worldPosition(atProgress: 0, scale: worldScale)
            content.add(emitter)
            emitterEntity = emitter
        } catch {
            print("파티클 이미터(\(emitterEntityName)) 로드 실패: \(error)")
        }
    }

    private func subscribeToUpdates(content: RealityViewContent) {
        guard updateSubscription == nil else { return }
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.advance(deltaTime: event.deltaTime)
        }
    }

    private func advance(deltaTime: TimeInterval) {
        guard let emitterEntity else { return }
        elapsedTime += deltaTime

        let progress = Float(elapsedTime / loopDuration)
        emitterEntity.position = ConductingWorldMapping.worldPosition(atProgress: progress, scale: worldScale)
    }
}
