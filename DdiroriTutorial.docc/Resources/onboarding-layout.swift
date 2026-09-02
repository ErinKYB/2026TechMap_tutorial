import SwiftUI

/// 온보딩 화면(2D 창)의 각 요소 위치를, 실제 연습 공간(3D)의 `BeatZoneLayout`과
/// **똑같은 배치 수식**으로 계산한다.
///
/// `BeatZoneLayout`이 쓰는 `zoneCenter`를 원점(.zero)에 둔 "논리 좌표"를 그대로 재사용해서,
/// 온보딩에서 본 4개 점·시작 버튼·안내 문구의 상대적 배치가 실제 연습에서 겪는
/// Zone·종료 버튼·진행 표시등의 배치와 구조적으로 일치하도록 보장한다.
/// (같은 원본 수치를 두 좌표계 — 미터 vs 포인트 — 에 각자 투영하는 것뿐이다.)
enum ConductingLayout {

    /// 미터 단위 좌표를 온보딩 창의 포인트 좌표로 변환하는 배율.
    /// visionOS 창은 대략 1미터 ≈ 1360pt로 렌더링됩니다(체감 거리에 따라 달라질 수 있음).
    /// 실기기에서 온보딩과 실제 연습의 체감 크기가 다르게 느껴지면 이 값을 조정하세요.
    static let pointsPerMeter: CGFloat = 1360

    /// `BeatZoneLayout`과 동일한 spread 값을 쓰되, 중심을 원점에 둔 논리 설정.
    private static var referenceConfiguration: TutorialConfiguration {
        var configuration = TutorialConfiguration.default
        configuration.zoneCenter = .zero
        return configuration
    }

    /// 4개 점(Beat 1...4)의, 창 중심 기준 포인트 좌표.
    static var pointOffsets: [CGPoint] {
        BeatZoneLayout.positions(configuration: referenceConfiguration).map(toPoint)
    }

    /// 실제 연습의 "종료" 버튼과 같은 위치 — 온보딩의 "시작하기" 버튼이 여기 놓인다.
    static var startButtonOffset: CGPoint {
        toPoint(BeatZoneLayout.exitButtonPosition(configuration: referenceConfiguration))
    }

    /// 실제 연습의 진행 표시등(신호등)과 같은 위치 — 온보딩의 상단 안내 문구가 여기 놓인다.
    static var messageOffset: CGPoint {
        toPoint(BeatZoneLayout.progressLightsRowPosition(configuration: referenceConfiguration))
    }

    /// 위 요소를 모두 담는 온보딩 창 크기(여백 포함), 포인트 단위.
    /// 시작 화면(`ContentView`)도 같은 창을 재사용하므로, 폭은 그 화면의 최소 폭보다 좁아지지 않게 한다.
    static var windowSize: CGSize {
        let allOffsets = pointOffsets + [startButtonOffset, messageOffset]
        let maxX = allOffsets.map { abs($0.x) }.max() ?? 0
        let maxY = allOffsets.map { abs($0.y) }.max() ?? 0
        let margin: CGFloat = 100
        let minWidth: CGFloat = 560
        return CGSize(width: max(maxX * 2 + margin, minWidth), height: maxY * 2 + margin)
    }

    /// 미터 좌표(RealityKit 기준, y: 위+) → 창 중심 기준 포인트 좌표(SwiftUI 기준, y: 아래+).
    private static func toPoint(_ meters: SIMD3<Float>) -> CGPoint {
        CGPoint(x: CGFloat(meters.x) * pointsPerMeter, y: -CGFloat(meters.y) * pointsPerMeter)
    }
}
