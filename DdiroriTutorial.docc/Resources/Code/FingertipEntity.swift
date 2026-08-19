import RealityKit
import UIKit

/// 검지 끝 위치를 나타내는 Entity. (F-03)
///
/// 실기기 모드에서는 ARKit이 준 위치를 그대로 따라가는 순수 표시용 Entity이고,
/// 시뮬레이터 모드에서는 동일한 Entity가 사용자가 드래그로 직접 움직이는 "가상 검지 끝" 역할을 겸한다
/// (`isDraggableHandle: true`) — 그래야 판정 로직(BeatSequenceController)이 두 모드에서 동일하게 동작한다.
///
/// 항상 파티클 이미터를 함께 붙이되(F-03 "파티클"), 파티클 컴포넌트의 정확한 프로퍼티 이름은
/// RealityKit 버전에 따라 조금씩 달라질 수 있으므로, 파티클과 무관하게 항상 보이는 단순한
/// 발광 구체를 기본 표현으로 사용한다 (PRD F-03: "파티클 또는 이에 준하는 경량 효과").
enum FingertipEntity {
    static let entityName = "Fingertip"

    static func make(configuration: TutorialConfiguration, isDraggableHandle: Bool) -> ModelEntity {
        // 시뮬레이터에서는 드래그로 붙잡기 쉽도록 조금 더 크게 표시한다.
        let radius = isDraggableHandle
            ? configuration.fingertipParticleRadius * 3.0
            : configuration.fingertipParticleRadius

        let mesh = MeshResource.generateSphere(radius: radius)
        // 시뮬레이터의 드래그 핸들은 배경(패스스루/가상 환경)에 묻히지 않도록 채도 높은 색을 쓴다.
        // 실기기 모드의 순수 표시용 구체는 기존과 동일하게 흰색을 유지한다.
        let color: UIColor = isDraggableHandle
            ? UIColor(red: 0.15, green: 0.85, blue: 1.0, alpha: 1.0)
            : UIColor(white: 1.0, alpha: 0.95)
        let material = UnlitMaterial(color: color)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = entityName

        entity.components.set(makeParticleComponent(radius: radius))

        if isDraggableHandle {
            entity.components.set(InputTargetComponent())
            entity.components.set(
                CollisionComponent(shapes: [.generateSphere(radius: radius * 3.0)])
            )
            entity.components.set(HoverEffectComponent())
        }

        return entity
    }

    static func setVisible(_ entity: Entity, visible: Bool) {
        entity.isEnabled = visible
    }

    /// 목표 Zone 접근 시 살짝 밝아지도록 한다. (기획정리 v1 §11 "목표 지점 접근: 밝기가 조금 증가")
    static func setEmphasis(_ entity: ModelEntity, isNearTarget: Bool) {
        guard var model = entity.model else { return }
        let alpha: CGFloat = isNearTarget ? 1.0 : 0.85
        model.materials = [UnlitMaterial(color: UIColor(white: 1.0, alpha: alpha))]
        entity.model = model
    }

    /// 경량 파티클 트레일. 정확한 API 표면은 Xcode의 RealityKit 버전에 맞춰 자동완성으로
    /// 미세 조정할 수 있다 (본 파일에서 파티클이 핵심 판정 로직에 영향을 주지는 않는다).
    private static func makeParticleComponent(radius: Float) -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .sphere
        emitter.emitterShapeSize = SIMD3<Float>(repeating: radius * 1.4)
        emitter.mainEmitter.birthRate = 90
        emitter.mainEmitter.lifeSpan = 0.3
        emitter.mainEmitter.lifeSpanVariation = 0.1
        emitter.mainEmitter.size = radius * 2.2
        emitter.mainEmitter.sizeVariation = radius * 0.6
        emitter.mainEmitter.color = .constant(.single(.white))
        emitter.speed = 0.015
        emitter.isEmitting = true
        return emitter
    }
}
