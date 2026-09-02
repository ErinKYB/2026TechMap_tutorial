import SwiftUI

/// 4/4박자 지휘 패턴을 잇는 닫힌 경로를 그리는 Shape입니다.
/// `ConductingLayout.pointOffsets`(실제 연습 공간과 같은 수식으로 계산된 좌표)를
/// `rect`의 중심에 그대로 옮겨 그리므로, 실제 연습의 Zone 배치와 모양이 일치합니다.
struct BeatPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        let points = ConductingLayout.pointOffsets.map { offset in
            CGPoint(x: center.x + offset.x, y: center.y + offset.y)
        }

        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: first) // 4박 → 1박으로 돌아오는 구간을 닫아줍니다.
        return path
    }
}
