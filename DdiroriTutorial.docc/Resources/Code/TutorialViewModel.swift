import Foundation
import Observation
import simd

/// 앱 전체 상태를 소유하고, 추적 입력 → 판정 → 상태/연출을 잇는 단일 오케스트레이터.
///
/// 데이터 흐름:
/// ```
/// HandTrackingProvider(또는 시뮬레이터) 업데이트
///         ↓
/// FingerTrackingSample
///         ↓
/// BeatSequenceController: 현재 목표와 거리·진입 판정
///         ↓
/// TutorialPhase/TutorialProgress 변경
///         ↓
/// RealityKit + SwiftUI: 시각·텍스트 피드백 반영
/// ```
///
/// RealityView와 SwiftUI 뷰는 이 객체를 관찰(`@Observable`)만 하고,
/// 판정/상태 전이 로직은 이 파일과 `BeatSequenceController`에만 존재한다.
@MainActor
@Observable
final class TutorialViewModel {

    // MARK: - 외부에서 관찰하는 상태

    private(set) var phase: TutorialPhase = .idle
    private(set) var progress = TutorialProgress()
    private(set) var currentMessage: String = TutorialMessage.watchDemonstration
    private(set) var latestFingerSample = FingerTrackingSample(
        position: nil, handedness: nil, isTracked: false, timestamp: 0
    )

    /// 사용자가 시작 화면에서 선택한 입력 방식. Immersive Space 진입 전에만 변경 가능하다.
    var inputMode: InputMode = .realHandTracking

    let configuration: TutorialConfiguration

    // MARK: - 내부 구성 요소

    private var sequenceController = BeatSequenceController()
    private var handTrackingService: HandTrackingProviding?
    private var simulatedService: SimulatedHandTrackingService?

    private var samplesTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var trackingMonitorTask: Task<Void, Never>?

    private var lastTrackedAt: Date = .distantPast

    init(configuration: TutorialConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - 파생 상태 (View가 읽기만 하는 계산 프로퍼티)

    /// 4개 Beat Zone의 공간 좌표. 세션 시작 시 재현 가능하도록 configuration에서만 계산한다.
    var beatZonePositions: [SIMD3<Float>] {
        BeatZoneLayout.positions(configuration: configuration)
    }

    var isSimulatorMode: Bool { inputMode == .simulator }

    /// 검지 끝 파티클을 화면에 그려도 되는가.
    var isFingertipVisible: Bool { latestFingerSample.isTracked }

    // MARK: - 생명주기 (Immersive Space)

    /// SwiftUI의 `openImmersiveSpace` 성공 직후 호출한다.
    func immersiveSpaceEntered() {
        phase = .calibrating
        currentMessage = TutorialMessage.calibrating
        sequenceController.reset()
        progress = sequenceController.progress
        startTracking()
    }

    /// SwiftUI의 `dismissImmersiveSpace` 호출 직전에 호출해 자원을 정리한다.
    func prepareForExit() {
        transitionTask?.cancel(); transitionTask = nil
        trackingMonitorTask?.cancel(); trackingMonitorTask = nil
        samplesTask?.cancel(); samplesTask = nil

        let serviceToStop = handTrackingService
        Task { await serviceToStop?.stop() }
        handTrackingService = nil
        simulatedService = nil

        phase = .idle
        sequenceController.reset()
        progress = sequenceController.progress
        latestFingerSample = FingerTrackingSample(position: nil, handedness: nil, isTracked: false, timestamp: 0)
        currentMessage = TutorialMessage.watchDemonstration
    }

    // MARK: - 사용자 액션

    /// 온보딩 화면(경로 미리보기)의 "시작하기"를 눌렀을 때 호출한다. 연습을 시작한다.
    func finishOnboarding() {
        guard phase == .demonstrating else { return }
        beginPracticing()
    }

    /// 완료 화면 또는 연습 중 "시범 다시 보기": 온보딩 화면으로 되돌아간다.
    func watchDemonstrationAgain() {
        guard phase == .completed || phase == .practicing || phase == .trackingPaused else { return }
        phase = .demonstrating
        currentMessage = TutorialMessage.watchDemonstration
    }

    /// 완료 화면의 "다시 연습하기": 온보딩 없이 바로 연습으로 되돌아간다.
    func practiceAgain() {
        guard phase == .completed else { return }
        beginPracticing()
    }

    /// Hand Tracking 시작 실패(`.error`) 후 재시도.
    func retryHandTrackingStart() {
        guard phase.isRecoverableError else { return }
        phase = .calibrating
        currentMessage = TutorialMessage.calibrating
        startTracking()
    }

    /// 시뮬레이터 모드에서 드래그 제스처가 검지 끝 위치를 갱신할 때 호출한다.
    func updateSimulatedFingerPosition(_ position: SIMD3<Float>) {
        simulatedService?.updatePosition(position)
    }

    /// 시뮬레이터 모드 디버그 컨트롤: 손 추적 유실 상황을 인위적으로 재현한다.
    func setSimulatedTrackingPaused(_ paused: Bool) {
        simulatedService?.setManuallyPausedForTesting(paused)
    }

    // MARK: - 추적 시작

    private func startTracking() {
        trackingMonitorTask?.cancel()
        samplesTask?.cancel()

        let service: HandTrackingProviding
        if inputMode == .simulator {
            let initial = BeatZoneLayout.position(forBeat: 1, configuration: configuration) + SIMD3<Float>(0, 0.05, 0.18)
            let simulated = SimulatedHandTrackingService(initialPosition: initial)
            simulatedService = simulated
            service = simulated
        } else {
            simulatedService = nil
            service = ARKitHandTrackingService()
        }
        handTrackingService = service

        lastTrackedAt = .distantPast

        samplesTask = Task { [weak self] in
            guard let self else { return }
            for await sample in service.samples {
                if Task.isCancelled { return }
                self.handle(sample: sample)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await service.start(configuration: self.configuration)
                self.beginOnboardingIfReady()
            } catch {
                let description = (error as? LocalizedError)?.errorDescription ?? "손 추적을 시작할 수 없습니다."
                self.phase = .error(message: TutorialMessage.handTrackingUnavailable(description))
            }
        }

        startTrackingLossMonitor()
    }

    // MARK: - 손 추적 샘플 처리

    private func handle(sample: FingerTrackingSample) {
        latestFingerSample = sample

        if sample.isTracked {
            lastTrackedAt = Date()
            if phase == .trackingPaused {
                phase = .practicing
                currentMessage = TutorialMessage.followBeat(progress.currentBeat)
                sequenceController.synchronizeAfterTrackingRecovery(position: sample.position, configuration: configuration)
                progress = sequenceController.progress
            }
        }

        guard phase.allowsBeatJudging, sample.isTracked else { return }

        let outcome = sequenceController.handle(sample: sample, configuration: configuration, now: Date())
        progress = sequenceController.progress

        switch outcome {
        case .noChange:
            break
        case .wrongZoneEntered:
            break
        case .beatAdvanced(let newBeat):
            currentMessage = TutorialMessage.beatSucceeded(newBeat - 1, next: newBeat)
        case .cycleCompleted(let consecutiveCycles, _):
            handleCycleCompleted(consecutiveCycles: consecutiveCycles)
        }
    }

    // MARK: - 온보딩 (경로 미리보기 창)

    private func beginOnboardingIfReady() {
        guard phase == .calibrating else { return }
        phase = .demonstrating
        currentMessage = TutorialMessage.watchDemonstration
    }

    private func beginPracticing() {
        sequenceController.reset()
        progress = sequenceController.progress
        phase = .practicing
        currentMessage = TutorialMessage.followBeat(1)
    }

    // MARK: - 사이클/완료 처리

    private func handleCycleCompleted(consecutiveCycles: Int) {
        phase = .cycleSuccess
        currentMessage = TutorialMessage.cycleSuccess(
            consecutive: consecutiveCycles,
            required: configuration.requiredConsecutiveCycles
        )

        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.configuration.cycleSuccessDisplayDuration))
            if Task.isCancelled { return }

            if consecutiveCycles >= self.configuration.requiredConsecutiveCycles {
                self.completeTutorial()
            } else {
                self.phase = .practicing
                self.currentMessage = TutorialMessage.followBeat(1)
            }
        }
    }

    private func completeTutorial() {
        phase = .completed
        currentMessage = TutorialMessage.completed
    }

    // MARK: - 손 추적 유실 감시

    private func startTrackingLossMonitor() {
        trackingMonitorTask?.cancel()
        trackingMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.2))
                if Task.isCancelled { return }
                self.evaluateTrackingLoss()
            }
        }
    }

    private func evaluateTrackingLoss() {
        guard phase == .practicing || phase == .trackingPaused else { return }
        let elapsed = Date().timeIntervalSince(lastTrackedAt)

        if elapsed >= configuration.trackingLossPauseThreshold, phase == .practicing {
            phase = .trackingPaused
            currentMessage = TutorialMessage.bringHandIntoView
        }

        if elapsed >= configuration.trackingLossResetThreshold, progress.consecutiveCycles > 0 {
            sequenceController.resetConsecutiveCyclesDueToTrackingLoss()
            progress = sequenceController.progress
        }
    }
}
