import ARKit
import Foundation
import simd

/// 실제 Apple Vision Pro에서 ARKit Hand Tracking을 사용하는 구현.
///
/// PRD 8.2 좌표 계산을 그대로 따른다:
/// ```
/// originFromIndexTip = originFromHandAnchor * handAnchorFromIndexTip
/// fingerPosition = originFromIndexTip.translation
/// ```
///
/// PRD F-02 수용 기준을 충족한다:
/// - 손 선택 규칙(오른손 우선, 왼손 대체)이 일관됨
/// - 관절/손 Anchor 미추적 시 이전 좌표를 재사용하지 않음
final class ARKitHandTrackingService: HandTrackingProviding, @unchecked Sendable {

    private let session = ARKitSession()
    private let handTrackingProvider = HandTrackingProvider()

    private var continuation: AsyncStream<FingerTrackingSample>.Continuation?
    lazy var samples: AsyncStream<FingerTrackingSample> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }

    private var latestLeftAnchor: HandAnchor?
    private var latestRightAnchor: HandAnchor?
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
        session.stop()
        emitUntracked()
    }

    // MARK: - Private

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

    private func anchor(for handedness: Handedness) -> HandAnchor? {
        handedness == .right ? latestRightAnchor : latestLeftAnchor
    }

    private func emitLatestSample() {
        let preferred = configuration.preferredHandedness

        var selection: (anchor: HandAnchor, handedness: Handedness)?
        if let primary = anchor(for: preferred) {
            selection = (primary, preferred)
        } else if configuration.allowFallbackHand, let fallback = anchor(for: preferred.opposite) {
            selection = (fallback, preferred.opposite)
        }

        guard let selection,
              selection.anchor.isTracked,
              let skeleton = selection.anchor.handSkeleton else {
            emitUntracked(handedness: selection?.handedness)
            return
        }

        let indexTip = skeleton.joint(.indexFingerTip)
        guard indexTip.isTracked else {
            emitUntracked(handedness: selection.handedness)
            return
        }

        // originFromIndexTip = originFromHandAnchor * handAnchorFromIndexTip
        let originFromHandAnchor = selection.anchor.originFromAnchorTransform
        let handAnchorFromIndexTip = indexTip.anchorFromJointTransform
        let originFromIndexTip = originFromHandAnchor * handAnchorFromIndexTip
        let position = SIMD3<Float>(
            originFromIndexTip.columns.3.x,
            originFromIndexTip.columns.3.y,
            originFromIndexTip.columns.3.z
        )

        continuation?.yield(
            FingerTrackingSample(
                position: position,
                handedness: selection.handedness,
                isTracked: true,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
        )
    }

    private func emitUntracked(handedness: Handedness? = nil) {
        continuation?.yield(
            FingerTrackingSample(
                position: nil,
                handedness: handedness,
                isTracked: false,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
        )
    }
}
