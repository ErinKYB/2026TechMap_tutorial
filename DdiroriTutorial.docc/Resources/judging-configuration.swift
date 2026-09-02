import Foundation
import simd

/// MVP 판정/연출에 필요한 조정 가능 값을 한 곳에서 관리한다.
struct TutorialConfiguration: Sendable {

    // MARK: Beat Zone 배치

    /// 4개 Beat Zone 배치의 기준 중심점. 사용자 정면, 가슴~눈높이 사이, 팔을 크게 뻗지 않아도
    /// 닿는 거리에 둔다.
    var zoneCenter: SIMD3<Float> = SIMD3<Float>(0, 1.10, -0.55)

    /// 좌우 방향 Zone 간격 (미터)
    var zoneHorizontalSpread: Float = 0.16

    /// 상하 방향 Zone 간격 (미터)
    var zoneVerticalSpread: Float = 0.16

    /// Zone의 시각적 반지름 (미터). 판정 반경(hitRadius)보다 작게 두어
    /// "보이는 원보다 실제 판정 범위를 조금 더 크게" 둔다.
    var zoneVisualRadius: Float = 0.035

    /// 판정 반경 (미터). 시각 반경보다 크게 잡아 추적 흔들림/개인차를 흡수한다.
    var hitRadius: Float = 0.065

    // MARK: 판정 튜닝

    /// 성공 직후 입력 잠금 시간 (초). 같은 Zone에서 연속 중복 판정을 막는다.
    var inputLockDuration: TimeInterval = 0.25

    /// 손 추적이 이 시간 이상 끊기면 `trackingPaused`로 전환한다.
    var trackingLossPauseThreshold: TimeInterval = 0.4

    /// 손 추적이 이 시간 이상 끊기면 연속 성공 횟수를 초기화한다.
    var trackingLossResetThreshold: TimeInterval = 8.0

    /// 잘못된 Zone 진입만으로 연속 성공 횟수를 초기화할지 여부. 기본값은 초기화하지 않는다.
    var resetConsecutiveOnWrongZoneEntry: Bool = false

    // MARK: 학습 루프

    var requiredConsecutiveCycles: Int = 3

    /// 한 사이클 성공 연출을 유지하는 시간 (초). 이 동안은 판정을 중단한다.
    var cycleSuccessDisplayDuration: TimeInterval = 1.4

    // MARK: 손 선택

    /// 양손이 동시에 추적될 때 어느 손을 기준 손으로 삼을지. 두 손 모두 지원하며,
    /// 이 값은 그 중 어느 쪽을 우선할지에만 영향을 준다 (`HandTrackingService` 참고).
    var preferredHandedness: Handedness = .right

    // MARK: 검지 끝 표시

    var fingertipParticleRadius: Float = 0.012

    static let `default` = TutorialConfiguration()
}
