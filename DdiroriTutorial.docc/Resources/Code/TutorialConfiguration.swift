import Foundation
#if canImport(simd)
import simd
#endif

/// MVP 판정/연출에 필요한 모든 조정 가능 값을 한 곳에서 관리한다.
///
/// PRD 18 "구현 전 확정하거나 실기기에서 튜닝할 항목":
/// 코드 곳곳에 값을 흩어 놓지 않고 이 구조체에서 관리하라는 권고를 그대로 따른다.
/// 실기기 테스트 후에는 이 파일의 기본값만 조정하면 된다.
struct TutorialConfiguration: Sendable {

    // MARK: Beat Zone 배치 (PRD F-04, 기획정리 v1 §Step 2)

    /// 4개 Beat Zone 배치의 기준 중심점. 사용자 정면, 가슴~눈높이 사이, 팔을 크게 뻗지 않아도
    /// 닿는 거리에 둔다. (PRD 12.3 "Zone은 팔을 과도하게 뻗거나 몸을 크게 이동하지 않아도 닿는 범위")
    /// 좌표계는 Immersive Space 원점 기준이며, ImmersiveView에서 사용자 정면 앵커에 상대적으로 배치한다.
    var zoneCenter: SIMD3<Float> = SIMD3<Float>(0, 1.10, -0.55)

    /// 좌우 방향 Zone 간격 (미터)
    var zoneHorizontalSpread: Float = 0.16

    /// 상하 방향 Zone 간격 (미터)
    var zoneVerticalSpread: Float = 0.16

    /// Zone의 시각적 반지름 (미터). 판정 반경(hitRadius)보다 작게 두어
    /// "보이는 원보다 실제 판정 범위를 조금 더 크게" 둔다는 기획을 따른다.
    var zoneVisualRadius: Float = 0.035

    /// 판정 반경 (미터). 시각 반경보다 크게 잡아 추적 흔들림/개인차를 흡수한다.
    var hitRadius: Float = 0.065

    // MARK: 판정 튜닝 (PRD 8.5, 8.6 / 기획정리 v1 §7)

    /// 성공 직후 입력 잠금 시간 (초). 같은 Zone에서 연속 중복 판정을 막는다.
    var inputLockDuration: TimeInterval = 0.25

    /// 추적 흔들림에 의한 경계 반복 진입/이탈을 흡수하기 위한 최소 유지 시간 (초).
    /// 이 시간보다 짧게 Zone 안에 머문 경우 진입으로 카운트하지 않는다.
    var minimumDwellTime: TimeInterval = 0.03

    /// 손 추적이 이 시간 이상 끊기면 `trackingPaused`로 전환한다.
    var trackingLossPauseThreshold: TimeInterval = 0.4

    /// 손 추적이 이 시간 이상 끊기면 연속 성공 횟수를 초기화한다 (선택적 타임아웃).
    /// PRD F-09: "명시적 재시작·추적 장기 유실·선택적 타임아웃 발생 시 초기화".
    var trackingLossResetThreshold: TimeInterval = 8.0

    /// 잘못된 Zone 진입만으로 연속 성공 횟수를 초기화할지 여부.
    /// PRD F-09 기본값: 초기화하지 않는다 (보수적 적용, 사용자 테스트 전까지).
    var resetConsecutiveOnWrongZoneEntry: Bool = false

    // MARK: 학습 루프 (PRD F-08, F-09)

    var requiredConsecutiveCycles: Int = 3

    /// 한 사이클 성공 연출을 유지하는 시간 (초). 이 동안은 판정을 중단한다.
    /// PRD 17: "Beat 4 성공 연출 중 Beat 1 위치에 손이 있어도 다음 사이클이 자동 성공하지 않는다."
    var cycleSuccessDisplayDuration: TimeInterval = 1.4

    /// 완료(축하) 연출 최소 표시 시간 (초)
    var completionDisplayDuration: TimeInterval = 2.0

    // MARK: 가이드 시범 (PRD F-06)

    /// 가이드가 한 Beat에서 다음 Beat로 이동하는 데 걸리는 시간 (초)
    var guideStepDuration: TimeInterval = 0.85

    /// 가이드가 각 Beat 지점에서 멈춰 강조하는 시간 (초)
    var guideHoldAtBeatDuration: TimeInterval = 0.35

    // MARK: 손 선택 (PRD F-02, 12.6)

    var preferredHandedness: Handedness = .right
    var allowFallbackHand: Bool = true

    // MARK: 파티클/시각 (PRD F-03)

    var fingertipParticleRadius: Float = 0.012
    var fingertipParticleBrightnessNear: Float = 1.6
    var fingertipParticleBrightnessDefault: Float = 1.0

    // MARK: 시뮬레이터 모드

    /// Hand Tracking을 사용할 수 없는 환경(visionOS Simulator 등)에서
    /// 드래그 제스처로 검지 끝 위치를 대신 입력하는 모드의 이동 감도.
    /// 화면(포인트) 드래그량 1pt 당 이동시킬 실제 공간 거리(미터).
    var simulatorDragSensitivity: Float = 0.0016

    static let `default` = TutorialConfiguration()
}
