import Foundation

/// 검지 끝 위치를 어디서 얻을지 선택한다.
///
/// 사용자 요청: "Handtracking을 사용하지 못하는 시뮬레이션에서도 테스트할 수 있도록 하는 옵션을
/// 별도로 추가" — visionOS Simulator는 실제 ARKit Hand Tracking 데이터를 제공하지 않으므로,
/// 드래그 제스처로 검지 끝을 대신 조작하는 모드를 시작 화면에서 선택할 수 있게 한다.
enum InputMode: String, CaseIterable, Identifiable, Sendable {
    /// 실제 기기의 ARKit Hand Tracking을 사용한다. (Apple Vision Pro 전용)
    case realHandTracking
    /// Hand Tracking 없이, 드래그 제스처로 검지 끝 위치를 대신 입력한다. (Simulator/디버그용)
    case simulator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .realHandTracking: return "실기기 Hand Tracking"
        case .simulator: return "손 추적 없이 시뮬레이션"
        }
    }

    var subtitle: String {
        switch self {
        case .realHandTracking:
            return "Apple Vision Pro에서 실제 검지 끝 추적으로 연습합니다."
        case .simulator:
            return "visionOS Simulator 등 Hand Tracking을 사용할 수 없는 환경에서, 드래그로 검지 끝을 직접 움직여 판정 로직을 테스트합니다."
        }
    }

    var systemImageName: String {
        switch self {
        case .realHandTracking: return "hand.point.up.left.fill"
        case .simulator: return "hand.draw.fill"
        }
    }
}
