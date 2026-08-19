import Foundation
import simd

/// Hand Tracking을 사용할 수 없는 환경(visionOS Simulator, 또는 실기기 없이 로직만 확인하고 싶을 때)에서
/// 검지 끝 위치를 대신 공급하는 구현.
///
/// ImmersiveView는 이 서비스가 활성화된 동안 화면에 드래그 가능한 "가상 검지 끝" 엔티티를 보여주고,
/// 사용자가 트랙패드/마우스로 그 엔티티를 드래그하면 `updatePosition(_:)`을 호출한다.
/// 그 값이 그대로 `FingerTrackingSample`로 방출되므로, `BeatJudge`와 상태 머신은
/// 실기기 모드와 완전히 동일한 코드 경로로 판정을 수행한다 — 즉 "판정 로직은 시뮬레이터에서도
/// 검증 가능해야 한다"(PRD 9.4)는 요구를 시각적 손 추적이 없어도 그대로 만족시킨다.
final class SimulatedHandTrackingService: HandTrackingProviding, @unchecked Sendable {

    private var continuation: AsyncStream<FingerTrackingSample>.Continuation?
    lazy var samples: AsyncStream<FingerTrackingSample> = AsyncStream { [weak self] continuation in
        self?.continuation = continuation
        guard let self else { return }
        continuation.yield(self.currentSample())
    }

    private(set) var currentPosition: SIMD3<Float>
    private var isRunning: Bool = false
    /// 디버그용: 추적 유실 상황(F-02 예외 플로우)을 시뮬레이터에서도 재현하기 위한 수동 토글.
    private var isManuallyPausedForTesting: Bool = false

    init(initialPosition: SIMD3<Float>) {
        self.currentPosition = initialPosition
    }

    func start(configuration: TutorialConfiguration) async throws {
        isRunning = true
        continuation?.yield(currentSample())
    }

    func stop() async {
        isRunning = false
        continuation?.yield(
            FingerTrackingSample(position: nil, handedness: nil, isTracked: false, timestamp: now)
        )
    }

    /// ImmersiveView의 드래그 제스처에서 호출한다. 드래그 중에는 항상 "추적됨" 상태로 방출한다.
    func updatePosition(_ position: SIMD3<Float>) {
        currentPosition = position
        guard isRunning else { return }
        continuation?.yield(currentSample())
    }

    /// 손 추적 유실을 흉내내는 디버그 스위치. 시뮬레이터에서 F-02/F-10의
    /// "손이 추적되지 않음" 플로우를 손쉽게 재현할 수 있게 한다.
    func setManuallyPausedForTesting(_ paused: Bool) {
        isManuallyPausedForTesting = paused
        guard isRunning else { return }
        continuation?.yield(currentSample())
    }

    private func currentSample() -> FingerTrackingSample {
        if isManuallyPausedForTesting {
            return FingerTrackingSample(position: nil, handedness: .right, isTracked: false, timestamp: now)
        }
        return FingerTrackingSample(position: currentPosition, handedness: .right, isTracked: true, timestamp: now)
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
