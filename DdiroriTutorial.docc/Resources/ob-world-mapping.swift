import simd

/// 정규화 좌표(-1...1)를 RealityKit 월드 좌표(미터)로 변환합니다.
///
/// SwiftUI 쪽(`BeatPathShape`)은 같은 정규화 좌표를 포인트 단위로 투영하고,
/// 이 파일은 파티클 쪽에서 미터 단위로 투영하는 역할을 맡습니다 — 즉 하나의
/// 경로 데이터(`ConductingPath`)를 두 좌표계로 나눠 쓰는 지점입니다.
enum ConductingWorldMapping {
    /// 정규화 좌표 1.0이 몇 미터에 대응하는지를 나타내는 값입니다.
    /// WindowGroup 안 RealityView의 실제 크기에 맞춰 조정하세요.
    static let defaultWorldScale: Float = 0.08

    /// 진행률(t)에 해당하는 파티클 이미터의 월드 좌표(x, y, z=0)를 계산합니다.
    static func worldPosition(atProgress t: Float, scale: Float = defaultWorldScale) -> SIMD3<Float> {
        let normalized = ConductingPath.position(atProgress: t)
        // RealityKit은 +y가 위쪽입니다. "아래+"로 정의한 SwiftUI 정규화 좌표의
        // y 부호를 뒤집어야 궤적 선과 파티클이 같은 방향으로 움직입니다.
        return SIMD3(normalized.x * scale, -normalized.y * scale, 0)
    }
}
