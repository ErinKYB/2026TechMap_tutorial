import SwiftUI

/// 지휘 연습 온보딩 화면의 안내 문구와 "시작하기" 버튼입니다.
/// 배경은 투명하게 두어, 아래에 겹쳐진 궤적 선 레이어가 그대로 비칩니다.
///
/// 두 요소는 `ConductingLayout`을 통해, 실제 연습 공간에서 같은 역할을 하는
/// 요소와 같은 자리에 놓입니다.
/// - 안내 문구 → 실제 연습의 진행 표시등(신호등) 자리
/// - "시작하기" 버튼 → 실제 연습의 "종료" 버튼 자리
struct OnboardingPromptOverlay: View {
    var message: String = "검지 손가락으로 아래 4개의 점을\n순서대로 따라가며 지휘를 연습해요"
    var buttonTitle: String = "시작하기"
    var onStart: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let messagePoint = CGPoint(
                x: center.x + ConductingLayout.messageOffset.x,
                y: center.y + ConductingLayout.messageOffset.y
            )
            let buttonPoint = CGPoint(
                x: center.x + ConductingLayout.startButtonOffset.x,
                y: center.y + ConductingLayout.startButtonOffset.y
            )

            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .position(messagePoint)

            Button(buttonTitle, action: onStart)
                .buttonStyle(.borderedProminent)
                .position(buttonPoint)
        }
    }
}

#Preview {
    OnboardingPromptOverlay(onStart: {})
        .frame(width: ConductingLayout.windowSize.width, height: ConductingLayout.windowSize.height)
        .background(.black)
}
