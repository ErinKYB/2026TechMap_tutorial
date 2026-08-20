import Foundation

/// 궤적 선 애니메이션(SwiftUI)과 파티클 이동(RealityKit)이 함께 참조하는
/// 타이밍 상수입니다. 두 애니메이션은 서로 다른 시스템에서 독립적으로 돌지만,
/// 이 값을 공유해 시작 시점과 한 바퀴 도는 주기를 맞춥니다.
enum ConductingAnimationTiming {
    /// 지휘 속도 (분당 박자 수)
    static let tempo: Double = 76

    /// 박자 하나가 진행되는 시간(초)
    static var beatInterval: TimeInterval { 60.0 / tempo }

    /// 궤적을 한 바퀴(1 → 2 → 3 → 4 → 1) 도는 데 걸리는 시간(초)
    static var loopDuration: TimeInterval {
        beatInterval * Double(ConductingBeat.allCases.count)
    }
}
