import Foundation
import simd

/// 한 프레임(또는 한 업데이트)에서 얻은 검지 끝 추적 결과.
///
/// 실제 ARKit 손 추적과 시뮬레이터 드래그 입력 모두 동일한 형태로 공급되므로,
/// `BeatJudge`를 포함한 판정/연출 파이프라인은 입력 출처를 알 필요가 없다.
struct FingerTrackingSample: Sendable, Equatable {
    /// 공통(Immersive Space) 좌표계 기준 검지 끝 위치. 추적되지 않으면 nil.
    var position: SIMD3<Float>?
    var handedness: Handedness?
    var isTracked: Bool
    var timestamp: TimeInterval
}

/// 검지 끝 위치 공급원에 대한 추상화.
///
/// - `ARKitHandTrackingService`: 실제 기기에서 ARKit Hand Tracking을 사용한다.
/// - `SimulatedHandTrackingService`: Hand Tracking을 사용할 수 없는 visionOS Simulator 등에서
///   드래그 제스처로 검지 끝 위치를 대신 제공한다.
///
/// PRD F-02 수용 기준: "관절 또는 손 Anchor가 추적되지 않을 때 이전 좌표로 판정하지 않는다."
/// 두 구현 모두 추적 불가 상태에서는 `position == nil`, `isTracked == false`를 방출해야 한다.
protocol HandTrackingProviding: AnyObject, Sendable {
    /// 검지 끝 추적 결과 스트림. 값이 바뀔 때마다(또는 매 업데이트마다) 새 샘플을 방출한다.
    var samples: AsyncStream<FingerTrackingSample> { get }

    /// 추적을 시작한다. 지원되지 않거나 권한이 없으면 에러를 던진다.
    func start(configuration: TutorialConfiguration) async throws

    /// 추적을 중단하고 자원을 정리한다. (PRD 12.2: "비동기 추적 작업은 공간 종료 시 취소 또는 정리")
    func stop() async
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
