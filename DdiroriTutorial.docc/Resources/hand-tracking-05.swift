import ARKit
import Foundation
import simd

/// 한 프레임(또는 한 업데이트)에서 얻은 검지 끝 추적 결과.
struct FingerTrackingSample: Sendable, Equatable {
    /// Immersive Space 좌표계 기준 검지 끝 위치. 추적되지 않으면 nil.
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

/// Apple Vision Pro에서 ARKit Hand Tracking으로 검지 끝 위치를 공급한다.
///
/// - 양손 모두 지원한다. 어느 한쪽 손을 쓰기 시작하면 그 손이 계속 추적되는 동안은
///   그 손을 그대로 쓰고("고정"), 그 손이 시야를 벗어나면 그때 반대쪽 손으로 넘어간다.
///   이렇게 하지 않고 매 프레임 "오른손이 조금이라도 보이면 무조건 오른손"으로 판정하면,
///   왼손으로 열심히 지휘하는 중에 오른손이 무릎 위에서 살짝 보이기만 해도 판정이
///   오른손(가만히 있는 손)으로 튀어버리는 문제가 생긴다.
/// - 관절/손 Anchor가 추적되지 않으면 이전 좌표를 재사용하지 않고 `isTracked: false`를 방출한다.
final class HandTrackingService: @unchecked Sendable {

    private let session = ARKitSession()
    private let handTrackingProvider = HandTrackingProvider()

    private var continuation: AsyncStream<FingerTrackingSample>.Continuation?
    lazy var samples: AsyncStream<FingerTrackingSample> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
    }

    private var latestLeftAnchor: HandAnchor?
    private var latestRightAnchor: HandAnchor?
    /// 지금 판정에 쓰고 있는 손. 이 손이 계속 추적되는 한 바뀌지 않는다.
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

    /// 이미 쓰고 있던 손이 여전히 추적되면 그 손을 유지하고("고정"), 아니면 지금 추적되는
    /// 손 중 하나를 새로 고른다(둘 다 추적되면 `preferredHandedness`를 기준 손으로 삼는다).
    private func resolveHandSelection() -> (anchor: HandAnchor, handedness: Handedness)? {
        if let current = currentHandedness, let anchor = anchor(for: current) {
            return (anchor, current)
        }
        let preferred = configuration.preferredHandedness
        if let anchor = anchor(for: preferred) {
            return (anchor, preferred)
        }
        if let anchor = anchor(for: preferred.opposite) {
            return (anchor, preferred.opposite)
        }
        return nil
    }

    /// 왼손·오른손 Anchor가 갱신될 때마다 호출되어, "지금 판정에 쓸 손"을 하나 골라
    /// 그 검지 끝 위치를 `samples` 스트림으로 내보낸다.
    private func emitLatestSample() {
        let selection = resolveHandSelection()
        currentHandedness = selection?.handedness

        guard let selection, let skeleton = selection.anchor.handSkeleton else {
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
