import SwiftUI

/// 지휘 궤적 선이 반복해서 그려지는 데모 애니메이션입니다.
/// `.trim`으로 0 → 1까지 그려진 뒤, 다시 처음부터 반복됩니다.
/// 한 바퀴를 도는 데 걸리는 시간은 `ConductingAnimationTiming.loopDuration`을 그대로 사용합니다.
struct ConductingPathTraceView: View {
    var lineColor: Color = .white.opacity(0.85)
    var lineWidth: CGFloat = 4

    @State private var trimEnd: CGFloat = 0

    var body: some View {
        BeatPathShape()
            .trim(from: 0, to: trimEnd)
            .stroke(
                lineColor,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: ConductingAnimationTiming.loopDuration)
                        .repeatForever(autoreverses: false)
                ) {
                    trimEnd = 1
                }
            }
    }
}

#Preview {
    ConductingPathTraceView()
        .frame(width: 260, height: 260)
        .padding(40)
}
