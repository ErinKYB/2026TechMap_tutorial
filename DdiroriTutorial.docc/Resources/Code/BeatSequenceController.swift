import Foundation
import simd

/// `practicing` 상태에서 한 번의 업데이트가 만들어낸 결과.
/// ViewModel은 이 값을 보고 연출(피드백, 상태 전이)만 트리거하면 된다.
enum BeatSequenceOutcome: Equatable {
    /// 아무 변화 없음 (판정 대기, 입력 잠금, 추적 없음 등)
    case noChange
    /// 목표가 아닌 Zone에 새로 진입함 (진행도는 변하지 않음, 선택적 오답 피드백용)
    case wrongZoneEntered
    /// Beat 1~3 성공: 다음 Beat로 이동
    case beatAdvanced(newBeat: Int)
    /// Beat 4 성공: 한 사이클 완료
    case cycleCompleted(consecutiveCycles: Int, totalCycles: Int)
}

/// PRD 8~9의 판정/상태 로직을 하나로 묶은 순수(pure) 컨트롤러.
///
/// - 순서 기반 판정 (F-07): `1 → 2 → 3 → 4` 외의 입력은 진행도를 올리지 않는다.
/// - 중복 방지: 목표 Zone 안에 머무는 동안 중복 성공이 발생하지 않는다.
/// - 입력 잠금(cooldown): 성공 직후 짧은 시간 추가 판정을 막는다.
/// - 한 사이클/연속 성공 판정 (F-08, F-09).
///
/// RealityKit, ARKit, SwiftUI에 의존하지 않아 XCTest에서 시나리오 단위로 검증할 수 있다.
/// (PRD 9.4: "판정 함수는 가능한 한 순수 로직으로 작성해 시뮬레이터 또는 단위 테스트에서
/// 검증할 수 있게 한다.")
struct BeatSequenceController {
    private(set) var progress = TutorialProgress()

    private var targetJudge = BeatJudge()
    private var wasInsideAnyWrongZone: Bool = false
    private var lastSuccessAt: Date?

    /// 새 세션/재시작 시 호출한다. (PRD F-09: "명시적 재시작" 시 연속 성공 초기화)
    mutating func reset() {
        progress.reset()
        targetJudge.resetForNewTarget()
        wasInsideAnyWrongZone = false
        lastSuccessAt = nil
    }

    /// 추적이 길게 끊겼을 때(설정 가능한 타임아웃) 연속 성공만 초기화하고 사이클은 유지한다.
    mutating func resetConsecutiveCyclesDueToTrackingLoss() {
        progress.consecutiveCycles = 0
    }

    /// `trackingPaused`에서 추적이 다시 잡혀 `practicing`으로 돌아갈 때 호출한다.
    /// 추적이 끊긴 동안 `handle`이 매 프레임 `wasInsideTarget`을 false로 되돌려 놨기 때문에,
    /// 손가락이 실제로는 목표 Zone 밖으로 나간 적이 없는데도(예: 잠깐의 추적 흔들림) 복구
    /// 시점에 "새로 진입"으로 오판해 성공이 잘못 중복 카운트될 수 있다. 복구 직후 현재
    /// 위치를 기준으로 다시 동기화해 이런 오판을 막는다.
    mutating func synchronizeAfterTrackingRecovery(position: SIMD3<Float>?, configuration: TutorialConfiguration) {
        guard let position else { return }
        let targetPosition = BeatZoneLayout.position(forBeat: progress.currentBeat, configuration: configuration)
        let isInside = simd_distance(position, targetPosition) <= configuration.hitRadius
        targetJudge.resetForNewTarget(assumingInside: isInside)
        progress.isInsideTarget = isInside
    }

    /// `practicing` 상태일 때 매 손 추적 업데이트마다 호출한다.
    mutating func handle(
        sample: FingerTrackingSample,
        configuration: TutorialConfiguration,
        now: Date
    ) -> BeatSequenceOutcome {
        guard sample.isTracked, let position = sample.position else {
            // 추적 유실 시 이전 좌표로 판정하지 않는다 (PRD F-02).
            targetJudge.resetForNewTarget()
            wasInsideAnyWrongZone = false
            return .noChange
        }

        if let lastSuccessAt, now.timeIntervalSince(lastSuccessAt) < configuration.inputLockDuration {
            return .noChange
        }

        let targetPosition = BeatZoneLayout.position(forBeat: progress.currentBeat, configuration: configuration)
        let enteredTarget = targetJudge.evaluate(
            fingerPosition: position,
            targetPosition: targetPosition,
            hitRadius: configuration.hitRadius
        )
        progress.isInsideTarget = targetJudge.wasInsideTarget

        if enteredTarget {
            lastSuccessAt = now
            progress.isInputLocked = true
            return advanceAfterSuccess(configuration: configuration)
        }

        if checkWrongZoneEdgeEntry(position: position, configuration: configuration) {
            if configuration.resetConsecutiveOnWrongZoneEntry {
                progress.consecutiveCycles = 0
            }
            return .wrongZoneEntered
        }

        progress.isInputLocked = false
        return .noChange
    }

    // MARK: - Private

    private mutating func advanceAfterSuccess(configuration: TutorialConfiguration) -> BeatSequenceOutcome {
        // 방금 성공한 Zone은 다음 프레임 기준으로 "목표가 아닌 Zone"이 되지만,
        // 손가락은 아직 그 자리에 있으므로 이를 새로운 오답 진입으로 오판하지 않도록
        // wasInsideAnyWrongZone을 true로 선반영한다.
        wasInsideAnyWrongZone = true

        if progress.isLastBeat {
            progress.totalCyclesCompleted += 1
            progress.consecutiveCycles += 1
            progress.currentBeat = 1
            targetJudge.resetForNewTarget()
            return .cycleCompleted(
                consecutiveCycles: progress.consecutiveCycles,
                totalCycles: progress.totalCyclesCompleted
            )
        } else {
            progress.advanceToNextBeat()
            targetJudge.resetForNewTarget()
            return .beatAdvanced(newBeat: progress.currentBeat)
        }
    }

    private mutating func checkWrongZoneEdgeEntry(
        position: SIMD3<Float>,
        configuration: TutorialConfiguration
    ) -> Bool {
        let isInsideAnyWrongZone = (1...4).contains { beat in
            guard beat != progress.currentBeat else { return false }
            let zonePosition = BeatZoneLayout.position(forBeat: beat, configuration: configuration)
            return simd_distance(position, zonePosition) <= configuration.hitRadius
        }
        let didEnter = isInsideAnyWrongZone && !wasInsideAnyWrongZone
        wasInsideAnyWrongZone = isInsideAnyWrongZone
        return didEnter
    }
}
