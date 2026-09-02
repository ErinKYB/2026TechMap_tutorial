import Foundation
import simd

/// 하나의 목표 지점에 대한 "경계 진입(edge entry)" 판정만 담당하는 순수 로직:
/// ```swift
/// let isInside = distance(fingerPosition, targetPosition) <= hitRadius
/// let didEnter = isInside && !wasInsideTarget
/// wasInsideTarget = isInside
/// ```
/// RealityKit/ARKit에 의존하지 않으므로 XCTest에서 단독으로 검증할 수 있다.
struct BeatJudge: Equatable {
    private(set) var wasInsideTarget: Bool = false

    /// 목표 Beat가 바뀔 때 반드시 호출해, 새 목표 기준으로 `wasInsideTarget`을 다시 계산한다.
    mutating func resetForNewTarget(assumingInside: Bool = false) {
        wasInsideTarget = assumingInside
    }

    /// - Returns: 이번 평가에서 목표 반경에 새로 진입했으면 `true`.
    ///   추적되지 않는 프레임(`fingerPosition == nil`)에서는 항상 `false`를 반환하고
    ///   내부 상태를 "바깥"으로 되돌려, 추적 복구 시 이전 위치로 오판하지 않는다.
    @discardableResult
    mutating func evaluate(
        fingerPosition: SIMD3<Float>?,
        targetPosition: SIMD3<Float>,
        hitRadius: Float
    ) -> Bool {
        guard let fingerPosition else {
            wasInsideTarget = false
            return false
        }
        let distance = simd_distance(fingerPosition, targetPosition)
        let isInside = distance <= hitRadius
        let didEnter = isInside && !wasInsideTarget
        wasInsideTarget = isInside
        return didEnter
    }
}
