import SwiftUI

/// Immersive Space 하단에 붙는 상태 안내 패널.
/// 진행 상황 메시지와 "다시 연습하기 / 시범 다시 보기" 버튼을 제공한다.
/// (종료는 `ImmersiveView`가 Zone 아래에 3D로 배치하는 별도의 "종료" 버튼이 담당한다.)
struct ImmersiveStatusOrnament: View {
    @Environment(TutorialViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 14) {
            messageRow

            if viewModel.phase != .idle {
                progressDots
            }

            if viewModel.phase == .practicing || viewModel.phase == .trackingPaused {
                beatProgressDots
            }

            controlButtons
        }
        .padding(20)
        .frame(minWidth: 420)
        .glassBackgroundEffect()
    }

    private var messageRow: some View {
        Label(displayMessage, systemImage: iconName)
            .font(.headline)
            .multilineTextAlignment(.leading)
    }

    private var displayMessage: String {
        if case .error(let message) = viewModel.phase {
            return message
        }
        return viewModel.currentMessage
    }

    private var iconName: String {
        switch viewModel.phase {
        case .trackingPaused: return "hand.raised.slash"
        case .error: return "exclamationmark.triangle.fill"
        case .completed: return "party.popper.fill"
        case .cycleSuccess: return "checkmark.circle.fill"
        default: return "sparkles"
        }
    }

    private var progressDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<viewModel.configuration.requiredConsecutiveCycles, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.progress.consecutiveCycles ? Color.green : Color.white.opacity(0.25))
                    .frame(width: 18, height: 18)
            }
            Text("연속 성공 \(viewModel.progress.consecutiveCycles)/\(viewModel.configuration.requiredConsecutiveCycles)")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }

    private var beatProgressDots: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { beat in
                Circle()
                    .fill(beat < viewModel.progress.currentBeat ? Color.yellow : Color.white.opacity(0.2))
                    .frame(width: 10, height: 10)
            }
            Text("현재 사이클 \(viewModel.progress.currentBeat)/4박")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            if case .error = viewModel.phase {
                Button("다시 시도") { viewModel.retryHandTrackingStart() }
            }

            if viewModel.phase == .practicing || viewModel.phase == .trackingPaused || viewModel.phase == .completed {
                Button("시범 다시 보기") { viewModel.watchDemonstrationAgain() }
            }

            if viewModel.phase == .completed {
                Button("다시 연습하기") { viewModel.practiceAgain() }
            }
        }
        .buttonStyle(.bordered)
    }
}
