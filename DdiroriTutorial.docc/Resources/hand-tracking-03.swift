import ARKit
import Foundation
import simd

struct FingerTrackingSample: Sendable, Equatable {
    var position: SIMD3<Float>?
    var handedness: Handedness?
    var isTracked: Bool
    var timestamp: TimeInterval
}

enum HandTrackingServiceError: LocalizedError {
    case unsupported
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "이 기기에서는 Hand Tracking을 사용할 수 없습니다."
        case .authorizationDenied:
            return "Hand Tracking 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
        }
    }
}

final class HandTrackingService: @unchecked Sendable {
    private let session = ARKitSession()
    private let handTrackingProvider = HandTrackingProvider()

    private var continuation: AsyncStream<FingerTrackingSample>.Continuation?
    lazy var samples: AsyncStream<FingerTrackingSample> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }

    private var latestLeftAnchor: HandAnchor?
    private var latestRightAnchor: HandAnchor?
    private var currentHandedness: Handedness?
    private var updateTask: Task<Void, Never>?
    private var configuration: TutorialConfiguration = .default

    func start(configuration: TutorialConfiguration) async throws {
        self.configuration = configuration

        guard HandTrackingProvider.isSupported else {
            throw HandTrackingServiceError.unsupported
        }

        let authorizationResult = await session.requestAuthorization(for: [.handTracking])
        guard authorizationResult[.handTracking] == .allowed else {
            throw HandTrackingServiceError.authorizationDenied
        }

        try await session.run([handTrackingProvider])

        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }
            for await update in self.handTrackingProvider.anchorUpdates {
                if Task.isCancelled { break }
                self.consume(update: update)
            }
        }
    }

    func stop() async {
        updateTask?.cancel()
        updateTask = nil
        latestLeftAnchor = nil
        latestRightAnchor = nil
        currentHandedness = nil
        session.stop()
        emitUntracked()
    }

    private func consume(update: AnchorUpdate<HandAnchor>) {
        let anchor = update.anchor
        switch anchor.chirality {
        case .left:
            latestLeftAnchor = anchor.isTracked ? anchor : nil
        case .right:
            latestRightAnchor = anchor.isTracked ? anchor : nil
        @unknown default:
            break
        }
        emitLatestSample()
    }
}
