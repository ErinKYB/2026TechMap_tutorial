import SwiftUI

/// 지휘 연습 온보딩 화면의 안내 문구(상단)와 "시작하기" 버튼(하단)입니다.
/// 배경은 투명하게 두어, 아래에 겹쳐진 궤적 선/파티클 레이어가 그대로 비칩니다.
struct OnboardingPromptOverlay: View {
    var message: String = "아래 동작을 참고해,\n지휘를 연습해 보아요"
    var buttonTitle: String = "시작하기"
    var onStart: () -> Void

    var body: some View {
        VStack {
            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Spacer()

            Button(buttonTitle, action: onStart)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingPromptOverlay(onStart: {})
        .frame(width: 400, height: 400)
        .background(.black)
}
