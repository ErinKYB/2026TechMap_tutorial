import simd

/// 4개 Beat Zone의 공간 배치를 계산한다.
///
/// `UI/ConductingBeat.swift`(온보딩 화면의 지휘 경로 미리보기)가 정의하는 정규화 좌표를
/// 기준으로 삼아, 온보딩에서 보여준 4개 점의 순서·모양이 실제 연습 공간의 Zone 배치와
/// 정확히 일치하도록 한다. (1박: 아래, 2박: 왼쪽, 3박: 오른쪽, 4박: 위)
enum BeatZoneLayout {

    /// 인덱스 0...3 == Beat 1...4. `ConductingBeat.allCases`와 순서가 같다.
    static func positions(configuration: TutorialConfiguration) -> [SIMD3<Float>] {
        let center = configuration.zoneCenter
        let h = configuration.zoneHorizontalSpread
        let v = configuration.zoneVerticalSpread
        return ConductingBeat.allCases.map { beat in
            let normalized = beat.normalizedOffset
            // ConductingBeat의 정규화 좌표는 SwiftUI 기준(x: 오른쪽+, y: 아래+)이므로,
            // RealityKit(y: 위+)에 맞추려면 y 부호를 뒤집어야 한다 (ConductingWorldMapping과 동일한 규칙).
            return center + SIMD3<Float>(normalized.x * h, -normalized.y * v, 0)
        }
    }

    static func position(forBeat beat: Int, configuration: TutorialConfiguration) -> SIMD3<Float> {
        precondition((1...4).contains(beat), "beat must be within 1...4, got \(beat)")
        return positions(configuration: configuration)[beat - 1]
    }

    /// 4개 Zone 그룹 중 가장 아래 지점보다 더 아래, "종료" 버튼이 놓일 위치.
    static func exitButtonPosition(configuration: TutorialConfiguration) -> SIMD3<Float> {
        let center = configuration.zoneCenter
        return SIMD3<Float>(center.x, lowestZoneY(configuration: configuration) - 0.16, center.z)
    }

    /// 4개 Zone 그룹 중 가장 위 지점보다 더 위, 연속 성공 표시등이 가로로 나열될 위치들.
    static func progressLightPositions(count: Int, configuration: TutorialConfiguration) -> [SIMD3<Float>] {
        let baseY = progressLightsBaseY(configuration: configuration)
        let spacing: Float = 0.07
        let totalWidth = spacing * Float(max(count - 1, 0))
        return (0..<count).map { index in
            let x = -totalWidth / 2 + spacing * Float(index)
            return SIMD3<Float>(x, baseY, configuration.zoneCenter.z)
        }
    }

    /// 표시등 바로 위, "성공 N/M" 텍스트가 놓일 위치.
    static func progressLabelPosition(configuration: TutorialConfiguration) -> SIMD3<Float> {
        SIMD3<Float>(0, progressLightsBaseY(configuration: configuration) + 0.05, configuration.zoneCenter.z)
    }

    /// "성공 N/M" 텍스트보다 더 위, 표시등이 무엇을 뜻하는지 설명하는 제목이 놓일 위치
    /// (전체 콘텐츠 중 최상단).
    static func progressTitlePosition(configuration: TutorialConfiguration) -> SIMD3<Float> {
        progressLabelPosition(configuration: configuration) + SIMD3<Float>(0, 0.045, 0)
    }

    /// 표시등이 놓인 줄의 중심 위치. 온보딩 화면의 안내 문구가 이 자리에 놓인다
    /// ("성공 N/M" 텍스트 자리가 아니라 표시등 줄 자체와 같은 높이).
    static func progressLightsRowPosition(configuration: TutorialConfiguration) -> SIMD3<Float> {
        SIMD3<Float>(0, progressLightsBaseY(configuration: configuration), configuration.zoneCenter.z)
    }

    /// Zone 4개가 이루는 경로의 정중앙. 완료 시 "성공!" 텍스트가 뜨는 위치.
    static func completionTextPosition(configuration: TutorialConfiguration) -> SIMD3<Float> {
        configuration.zoneCenter
    }

    private static func lowestZoneY(configuration: TutorialConfiguration) -> Float {
        positions(configuration: configuration).map(\.y).min() ?? configuration.zoneCenter.y
    }

    private static func highestZoneY(configuration: TutorialConfiguration) -> Float {
        positions(configuration: configuration).map(\.y).max() ?? configuration.zoneCenter.y
    }

    private static func progressLightsBaseY(configuration: TutorialConfiguration) -> Float {
        highestZoneY(configuration: configuration) + 0.16
    }
}
