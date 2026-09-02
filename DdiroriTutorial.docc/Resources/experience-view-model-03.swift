import Foundation
import Observation
import simd

/// 앱 전체 상태를 소유하고, 추적 입력 → 판정 → 상태/연출을 잇는 단일 오케스트레이터.
///
/// 데이터 흐름:
/// ```
/// ARKit HandTrackingProvider 업데이트
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

    let configuration: TutorialConfiguration

    // MARK: - 내부 구성 요소

    private var sequenceController = BeatSequenceController()
    private var handTrackingService: HandTrackingService?

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

    // MARK: - 추적 시작

    /// 새 `HandTrackingService`를 만들고, 두 개의 독립된 Task로 나눠 시작한다.
    /// - `samplesTask`: 서비스가 내보내는 `FingerTrackingSample`을 계속 소비한다. 이 루프는
    ///   `service.start()`가 끝나기 전부터 돌기 시작해도 안전하다 (AsyncStream이 값을 버퍼링한다).
    /// - 별도 Task: 실제 ARKit 세션 시작(`service.start`)은 권한 요청 등으로 시간이 걸릴 수 있어
    ///   `await`가 필요하다. 실패하면(미지원 기기, 권한 거부 등) `.error` 상태로 전환해
    ///   `ImmersiveStatusOrnament`의 "다시 시도" 버튼으로 복구할 수 있게 한다.
    private func startTracking() {
        trackingMonitorTask?.cancel()
        samplesTask?.cancel()

        let service = HandTrackingService()
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

    /// ARKit이 새 위치를 줄 때마다(대략 프레임마다) 호출된다.
    private func handle(sample: FingerTrackingSample) {
        latestFingerSample = sample

        if sample.isTracked {
            lastTrackedAt = Date()
            if phase == .trackingPaused {
                phase = .practicing
                currentMessage = TutorialMessage.followBeat(progress.currentBeat)
                // 추적이 끊긴 동안 판정 로직 내부의 "목표 안에 있었는가" 상태가 false로
                // 리셋돼 있으므로, 손이 실제로 목표를 벗어난 적이 없어도 복구 시점에
                // 새로 진입한 것처럼 오판할 수 있다. 현재 위치로 먼저 동기화해 이를 막는다.
                sequenceController.synchronizeAfterTrackingRecovery(position: sample.position, configuration: configuration)
                progress = sequenceController.progress
            }
        }

        // 판정은 practicing 상태이고 추적이 유효할 때만 수행한다.
        guard phase.allowsBeatJudging, sample.isTracked else { return }

        let outcome = sequenceController.handle(sample: sample, configuration: configuration, now: Date())
        progress = sequenceController.progress

        switch outcome {
        case .noChange, .wrongZoneEntered:
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

    /// Beat 4까지 한 번 성공할 때마다 호출된다. 짧게 `cycleSuccess` 연출을 보여준 뒤,
    /// 목표 횟수(`requiredConsecutiveCycles`)를 채웠으면 완료로, 아니면 다시 연습으로 전환한다.
    /// 이 대기 동안은 `allowsBeatJudging`이 false라 다음 판정이 시작되지 않는다.
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

    /// ARKit은 "추적이 끊겼다"는 별도 이벤트를 주지 않고 그냥 샘플이 안 온다. 그래서
    /// 0.2초 간격으로 깨어나 마지막으로 유효한 샘플을 받은 시각을 직접 확인한다.
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

    /// 짧은 유실(pause threshold)과 긴 유실(reset threshold)에 서로 다르게 반응한다:
    /// 잠깐 손이 시야를 벗어난 정도로는 "손을 다시 보여주세요" 안내만 하고 진행도는 보존하지만,
    /// 훨씬 오래 끊기면(예: 사용자가 자리를 떠남) 연속 성공 횟수만 초기화해 다시 도전하게 한다.
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
