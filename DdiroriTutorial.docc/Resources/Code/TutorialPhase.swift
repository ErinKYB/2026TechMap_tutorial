import Foundation

/// 앱 상위 상태. PRD 9.1 "상위 앱 상태"를 그대로 구현한다.
///
/// 상태 전이는 `TutorialViewModel`에서만 수행하며, 렌더링 코드는 이 값을 관찰(observe)만 한다.
/// (PRD 9.4 "상태 관리 원칙": 렌더링 코드와 판정 로직을 분리한다.)
enum TutorialPhase: Equatable, Sendable {
    /// 시작 전 (시작 화면)
    case idle
    /// Immersive Space 진입 중
    case openingSpace
    /// 콘텐츠 배치 및 손 추적 확인
    case calibrating
    /// 가이드 시범 재생 중 (사용자 입력 판정하지 않음)
    case demonstrating
    /// 사용자 입력 판정 중
    case practicing
    /// 한 사이클(Beat 1~4) 성공 연출 중
    case cycleSuccess
    /// 연속 3회 성공 — 튜토리얼 완료
    case completed
    /// 손 추적 일시 중단 (판정 중단, 안내 표시)
    case trackingPaused
    /// 복구 가능한 오류 (예: Immersive Space 열기 실패)
    case error(message: String)

    /// 이 상태에서 Beat 판정을 수행해도 되는가.
    /// PRD 8.5: "시범, 사이클 성공 연출, 완료 상태에서는 판정하지 않는다."
    var allowsBeatJudging: Bool {
        self == .practicing
    }

    var isRecoverableError: Bool {
        if case .error = self { return true }
        return false
    }
}
