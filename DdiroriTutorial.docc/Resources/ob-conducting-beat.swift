import simd

/// 4/4박자 지휘 패턴의 각 박자를 나타냅니다.
/// 1박(아래) → 2박(왼쪽) → 3박(오른쪽) → 4박(위) 순서로 진행되며,
/// 4박 다음은 다시 1박으로 이어지는 닫힌 경로입니다.
enum ConductingBeat: Int, CaseIterable {
    case one = 1   // 아래로
    case two       // 왼쪽으로 (지휘자 기준 안쪽)
    case three     // 오른쪽으로 (지휘자 기준 바깥쪽)
    case four      // 위로

    /// 중심을 기준으로 한 정규화 좌표. x, y 모두 -1...1 범위입니다.
    /// (x: 오른쪽+, y: 아래+ — SwiftUI 좌표계 기준)
    var normalizedOffset: SIMD2<Float> {
        switch self {
        case .one:   return SIMD2(0,     1.0)
        case .two:   return SIMD2(-0.85, 0.35)
        case .three: return SIMD2(0.85,  0.35)
        case .four:  return SIMD2(0,    -1.0)
        }
    }
}
