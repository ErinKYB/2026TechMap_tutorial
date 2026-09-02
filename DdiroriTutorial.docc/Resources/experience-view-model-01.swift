import Foundation
import Observation
import simd

@MainActor
@Observable
final class TutorialViewModel {
    private(set) var phase: TutorialPhase = .idle
    private(set) var progress = TutorialProgress()
    private(set) var currentMessage: String = TutorialMessage.watchDemonstration
    private(set) var latestFingerSample = FingerTrackingSample(
        position: nil, handedness: nil, isTracked: false, timestamp: 0
    )

    let configuration: TutorialConfiguration

    private var sequenceController = BeatSequenceController()
    private var handTrackingService: HandTrackingService?
    private var samplesTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var trackingMonitorTask: Task<Void, Never>?
    private var lastTrackedAt: Date = .distantPast

    init(configuration: TutorialConfiguration = .default) {
        self.configuration = configuration
    }

    var beatZonePositions: [SIMD3<Float>] {
        BeatZoneLayout.positions(configuration: configuration)
    }

    var isFingertipVisible: Bool { latestFingerSample.isTracked }

    func immersiveSpaceEntered() {
        phase = .calibrating
        currentMessage = TutorialMessage.calibrating
        sequenceController.reset()
        progress = sequenceController.progress
        startTracking()
    }

    func prepareForExit() {
        transitionTask?.cancel()
        trackingMonitorTask?.cancel()
        samplesTask?.cancel()

        let serviceToStop = handTrackingService
        Task { await serviceToStop?.stop() }
        handTrackingService = nil

        phase = .idle
        sequenceController.reset()
        progress = sequenceController.progress
    }

    private func startTracking() {
        let service = HandTrackingService()
        handTrackingService = service

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
                let description = (error as? LocalizedError)?.errorDescription
                    ?? "손 추적을 시작할 수 없습니다."
                self.phase = .error(
                    message: TutorialMessage.handTrackingUnavailable(description)
                )
            }
        }
    }
}
