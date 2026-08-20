import SwiftUI

/// 4/4박자 지휘 패턴을 잇는 닫힌 경로를 그리는 Shape입니다.
/// `ConductingPath.normalizedPoints`를 뷰의 크기에 맞게 투영합니다.
struct BeatPathShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        let points = ConductingPath.normalizedPoints.map { normalized in
            CGPoint(
                x: center.x + CGFloat(normalized.x) * radius,
                y: center.y + CGFloat(normalized.y) * radius
            )
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
