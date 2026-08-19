import XCTest
import simd
@testable import ddirori

/// PRD 17 "테스트 시나리오"의 정상/경계 시나리오를 `BeatSequenceController` 단위에서 검증한다.
/// RealityKit, ARKit, SwiftUI에 의존하지 않으므로 시뮬레이터/실기기 없이 실행 가능하다.
final class BeatSequenceControllerTests: XCTestCase {

    private func makeConfiguration() -> TutorialConfiguration {
        var configuration = TutorialConfiguration.default
        configuration.inputLockDuration = 0 // 테스트에서는 cooldown을 별도로 검증하므로 기본값에서는 제거
        return configuration
    }

    private func sample(_ position: SIMD3<Float>?, tracked: Bool = true) -> FingerTrackingSample {
        FingerTrackingSample(position: position, handedness: .right, isTracked: tracked, timestamp: 0)
    }

    // MARK: - 정상 시나리오

    func testFullCycleSucceedsInOrder() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        for (index, position) in positions.enumerated() {
            let outcome = controller.handle(sample: sample(position), configuration: configuration, now: now)
            now = now.addingTimeInterval(0.05)

            if index < 3 {
                guard case .beatAdvanced(let newBeat) = outcome else {
                    return XCTFail("Beat \(index + 1) 성공 시 beatAdvanced를 기대했지만 \(outcome)")
                }
                XCTAssertEqual(newBeat, index + 2)
            } else {
                guard case .cycleCompleted(let consecutive, let total) = outcome else {
                    return XCTFail("Beat 4 성공 시 cycleCompleted를 기대했지만 \(outcome)")
                }
                XCTAssertEqual(consecutive, 1)
                XCTAssertEqual(total, 1)
            }
        }
        XCTAssertEqual(controller.progress.currentBeat, 1, "사이클 성공 후 다음 사이클은 Beat 1부터 시작해야 한다")
    }

    func testThreeConsecutiveCyclesReachRequiredCount() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        for _ in 0..<configuration.requiredConsecutiveCycles {
            for position in positions {
                _ = controller.handle(sample: sample(position), configuration: configuration, now: now)
                now = now.addingTimeInterval(0.05)
            }
        }

        XCTAssertEqual(controller.progress.consecutiveCycles, configuration.requiredConsecutiveCycles)
        XCTAssertEqual(controller.progress.totalCyclesCompleted, configuration.requiredConsecutiveCycles)
    }

    func testResetClearsBeatAndConsecutiveCycles() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        for position in positions {
            _ = controller.handle(sample: sample(position), configuration: configuration, now: now)
            now = now.addingTimeInterval(0.05)
        }
        XCTAssertEqual(controller.progress.consecutiveCycles, 1)

        controller.reset()

        XCTAssertEqual(controller.progress.currentBeat, 1)
        XCTAssertEqual(controller.progress.consecutiveCycles, 0)
        XCTAssertEqual(controller.progress.totalCyclesCompleted, 0)
    }

    // MARK: - 경계 및 오류 시나리오 (PRD 17)

    /// "1 → 3 순서로 이동해도 Beat 2 대기 상태가 유지된다."
    func testOutOfOrderEntryDoesNotAdvanceOrComplete() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        let firstOutcome = controller.handle(sample: sample(positions[0]), configuration: configuration, now: now)
        guard case .beatAdvanced = firstOutcome else { return XCTFail("Beat 1 성공이 먼저 이루어져야 한다") }
        now = now.addingTimeInterval(0.05)

        let skipOutcome = controller.handle(sample: sample(positions[2]), configuration: configuration, now: now)

        XCTAssertEqual(controller.progress.currentBeat, 2, "Beat 3으로 건너뛰어도 목표는 여전히 Beat 2여야 한다")
        if case .beatAdvanced = skipOutcome { XCTFail("순서를 건너뛴 입력이 진행도를 올려서는 안 된다") }
        if case .cycleCompleted = skipOutcome { XCTFail("순서를 건너뛴 입력이 사이클을 완료시켜서는 안 된다") }
    }

    /// "목표 Zone 안에서 손을 정지해도 한 번만 판정된다." / "손을 Zone 경계에서 흔들어도
    /// 성공이 비정상적으로 반복되지 않는다."
    func testDwellingOrJitteringAfterSuccessDoesNotDoubleCount() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        let firstOutcome = controller.handle(sample: sample(positions[0]), configuration: configuration, now: now)
        guard case .beatAdvanced = firstOutcome else { return XCTFail("첫 진입은 성공해야 한다") }

        now = now.addingTimeInterval(0.05)
        let jitterOutcome = controller.handle(
            sample: sample(positions[0] + SIMD3<Float>(0.001, 0, 0)),
            configuration: configuration,
            now: now
        )

        XCTAssertEqual(jitterOutcome, .noChange)
        XCTAssertEqual(controller.progress.currentBeat, 2)
    }

    /// "손 추적이 잠시 끊기면 판정이 멈추고 복구 후 정상 진행된다."
    func testTrackingLossPausesJudgingAndRecoversCleanly() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        _ = controller.handle(sample: sample(positions[0]), configuration: configuration, now: now)
        now = now.addingTimeInterval(0.05)
        XCTAssertEqual(controller.progress.currentBeat, 2)

        let lostOutcome = controller.handle(sample: sample(nil, tracked: false), configuration: configuration, now: now)
        XCTAssertEqual(lostOutcome, .noChange)
        XCTAssertEqual(controller.progress.currentBeat, 2, "추적 유실 중에는 진행도가 바뀌지 않는다")

        now = now.addingTimeInterval(0.05)
        let recoveredOutcome = controller.handle(sample: sample(positions[1]), configuration: configuration, now: now)
        guard case .beatAdvanced(let newBeat) = recoveredOutcome else {
            return XCTFail("추적 복구 후에는 정상적으로 판정되어야 한다")
        }
        XCTAssertEqual(newBeat, 3)
    }

    /// 추적이 끊겼다가 같은 위치(목표 Zone 안)에서 다시 잡히면, 손가락이 실제로는
    /// Zone을 벗어난 적이 없으므로 재진입으로 오판해 성공이 중복 카운트되면 안 된다.
    /// (`TutorialViewModel`이 `trackingPaused → practicing` 전환 시 호출하는
    /// `synchronizeAfterTrackingRecovery`가 이 오판을 막아준다.)
    func testTrackingRecoveryAtSamePositionDoesNotDoubleCount() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        let firstOutcome = controller.handle(sample: sample(positions[0]), configuration: configuration, now: now)
        guard case .beatAdvanced = firstOutcome else { return XCTFail("Beat 1 성공이 먼저 이루어져야 한다") }
        XCTAssertEqual(controller.progress.currentBeat, 2)

        // 목표(Beat 2) 안에 있는 채로 추적이 끊긴다.
        now = now.addingTimeInterval(0.05)
        _ = controller.handle(sample: sample(nil, tracked: false), configuration: configuration, now: now)

        // 추적이 복구되면 ViewModel이 이 시점에 재동기화를 호출한다.
        now = now.addingTimeInterval(0.05)
        controller.synchronizeAfterTrackingRecovery(position: positions[1], configuration: configuration)

        // 같은 위치에서의 다음 판정은 새 진입으로 카운트되면 안 된다.
        now = now.addingTimeInterval(0.05)
        let recoveredOutcome = controller.handle(sample: sample(positions[1]), configuration: configuration, now: now)

        XCTAssertEqual(recoveredOutcome, .noChange, "이미 안에 있던 Zone은 추적 복구 후 재진입으로 오판되면 안 된다")
        XCTAssertEqual(controller.progress.currentBeat, 2)
    }

    /// "성공 직후 짧은 입력 잠금(cooldown)을 둔다."
    func testInputLockPreventsImmediateFollowUpSuccess() {
        var controller = BeatSequenceController()
        var configuration = makeConfiguration()
        configuration.inputLockDuration = 1.0
        let positions = BeatZoneLayout.positions(configuration: configuration)
        let now = Date()

        let firstOutcome = controller.handle(sample: sample(positions[0]), configuration: configuration, now: now)
        guard case .beatAdvanced = firstOutcome else { return XCTFail() }

        let lockedOutcome = controller.handle(
            sample: sample(positions[1]),
            configuration: configuration,
            now: now.addingTimeInterval(0.1)
        )

        XCTAssertEqual(lockedOutcome, .noChange, "cooldown 시간 안의 입력은 무시되어야 한다")
        XCTAssertEqual(controller.progress.currentBeat, 2)

        let unlockedOutcome = controller.handle(
            sample: sample(positions[1]),
            configuration: configuration,
            now: now.addingTimeInterval(1.1)
        )
        guard case .beatAdvanced(let newBeat) = unlockedOutcome else {
            return XCTFail("cooldown 이후에는 정상적으로 판정되어야 한다")
        }
        XCTAssertEqual(newBeat, 3)
    }

    /// PRD F-09 기본값: "잘못된 Zone 진입만으로 횟수를 초기화하지 않는다."
    func testWrongZoneEntryDoesNotResetConsecutiveCyclesByDefault() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        for position in positions {
            _ = controller.handle(sample: sample(position), configuration: configuration, now: now)
            now = now.addingTimeInterval(0.05)
        }
        XCTAssertEqual(controller.progress.consecutiveCycles, 1)

        // 사이클 완료 직후 손이 Zone 밖 중립 위치로 실제로 이동한 뒤, 오답 Zone(Beat 3 위치)에 진입한다.
        now = now.addingTimeInterval(0.1)
        _ = controller.handle(sample: sample(SIMD3<Float>(2, 2, 2)), configuration: configuration, now: now)

        now = now.addingTimeInterval(0.1)
        let wrongOutcome = controller.handle(sample: sample(positions[2]), configuration: configuration, now: now)

        XCTAssertEqual(wrongOutcome, .wrongZoneEntered)
        XCTAssertEqual(
            controller.progress.consecutiveCycles, 1,
            "기본값에서는 오답 Zone 진입만으로 연속 성공 횟수를 초기화하지 않는다"
        )
    }

    func testResetConsecutiveCyclesDueToTrackingLoss() {
        var controller = BeatSequenceController()
        let configuration = makeConfiguration()
        let positions = BeatZoneLayout.positions(configuration: configuration)
        var now = Date()

        for position in positions {
            _ = controller.handle(sample: sample(position), configuration: configuration, now: now)
            now = now.addingTimeInterval(0.05)
        }
        XCTAssertEqual(controller.progress.consecutiveCycles, 1)

        controller.resetConsecutiveCyclesDueToTrackingLoss()

        XCTAssertEqual(controller.progress.consecutiveCycles, 0)
    }
}
