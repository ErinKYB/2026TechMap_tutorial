import RealityKit
import UIKit

/// Beat Zone 하나를 표현하는 Entity의 생성/갱신을 담당한다.
enum BeatZoneEntity {

    static func namePrefix(_ beat: Int) -> String { "BeatZone-\(beat)" }

    static func make(beat: Int, configuration: TutorialConfiguration) -> ModelEntity {
        let mesh = MeshResource.generateSphere(radius: configuration.zoneVisualRadius)
        let material = UnlitMaterial(color: BeatZoneVisualState.idle.color)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = namePrefix(beat)
        entity.addChild(makeLabel(beat: beat, configuration: configuration))
        return entity
    }

    /// 현재 상태에 맞춰 색상과 크기를 함께 갱신한다.
    static func update(_ entity: ModelEntity, state: BeatZoneVisualState) {
        if var model = entity.model {
            model.materials = [UnlitMaterial(color: state.color)]
            entity.model = model
        }
        entity.transform.scale = SIMD3<Float>(repeating: state.scale)
    }

    private static func makeLabel(beat: Int, configuration: TutorialConfiguration) -> Entity {
        let mesh = MeshResource.generateText(
            "\(beat)",
            extrusionDepth: 0.0015,
            font: .systemFont(ofSize: 0.045, weight: .semibold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let material = UnlitMaterial(color: .white)
        let textEntity = ModelEntity(mesh: mesh, materials: [material])
        // Zone 위쪽에 살짝 띄워 숫자가 겹치지 않게 배치한다.
        textEntity.position = SIMD3<Float>(-0.012, configuration.zoneVisualRadius + 0.025, 0)
        textEntity.name = "BeatZoneLabel-\(beat)"
        return textEntity
    }
}
