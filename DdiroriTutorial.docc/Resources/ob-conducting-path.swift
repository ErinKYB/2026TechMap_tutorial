import simd

/// 지휘 궤적의 정규화 좌표(-1...1)를 다루는 공용 데이터/함수 모음입니다.
///
/// SwiftUI 궤적 선(`BeatPathShape`)과 RealityKit 파티클 이미터
/// (`ConductingParticleTrailController`)가 모두 이 값을 원본으로 사용해,
/// "같은 경로"를 서로 다른 좌표계(포인트 / 미터)에 각자 투영합니다.
enum ConductingPath {
    /// 1 → 2 → 3 → 4 순서의 닫힌 경로 좌표. (4박 다음은 다시 1박으로 이어집니다)
    static let normalizedPoints: [SIMD2<Float>] = ConductingBeat.allCases.map(\.normalizedOffset)

    /// 0...1 진행률(t)에 해당하는 정규화 좌표를 선형 보간으로 계산합니다.
    /// t가 1을 넘어가거나 음수여도 자동으로 0...1 범위로 감싸져 반복 재생을 지원합니다.
    static func position(atProgress t: Float) -> SIMD2<Float> {
        let count = normalizedPoints.count
        guard count > 1 else { return normalizedPoints.first ?? .zero }

        // 0..<1 범위로 감싸서 무한 반복을 지원합니다.
        let wrapped = t - t.rounded(.down)
        let scaled = wrapped * Float(count)
        let index = min(Int(scaled), count - 1)
        let localT = scaled - Float(index)

        let start = normalizedPoints[index]
        let end = normalizedPoints[(index + 1) % count]
        return simd_mix(start, end, SIMD2(repeating: localT))
    }
}
