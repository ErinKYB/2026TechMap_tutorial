//
//  ContentView.swift
//  ddirori
//
//  Created by kiwiisae on 8/13/26.
//

import SwiftUI

/// 메인 윈도우: 입력 방식 선택 + "튜토리얼 시작" 화면.
///
/// 온보딩(경로 미리보기)은 `ImmersiveView`가 Immersive Space 안에 3D로 직접 띄우므로
/// (Zone과 같은 위치·거리를 공유하기 위함), 이 창은 Immersive Space가 열려 있는 동안
/// 계속 닫혀 있다가 완전히 종료됐을 때만 다시 나타난다.
struct ContentView: View {
    @Environment(TutorialViewModel.self) private var viewModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    @State private var isOpeningSpace = false
    @State private var spaceOpenErrorMessage: String?

    var body: some View {
        @Bindable var viewModel = viewModel

        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                inputModeSection(binding: $viewModel.inputMode)

                if let spaceOpenErrorMessage {
                    errorBanner(message: spaceOpenErrorMessage)
                }

                startButton
            }
            .padding(32)
        }
        .frame(minWidth: 520, idealWidth: 620, minHeight: 420)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("띠로리 Ddirori")
                .font(.largeTitle.bold())
            Text("검지 끝으로 4/4박자 지휘 동작을 익히는 visionOS 튜토리얼 데모")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func inputModeSection(binding: Binding<InputMode>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("입력 방식 선택")
                .font(.headline)

            ForEach(InputMode.allCases) { mode in
                InputModeCard(
                    mode: mode,
                    isSelected: binding.wrappedValue == mode,
                    action: { binding.wrappedValue = mode }
                )
            }

            Text("실기기가 아닌 환경(visionOS Simulator 등)에서는 ARKit Hand Tracking을 사용할 수 없습니다. 이때는 \"손 추적 없이 시뮬레이션\"을 선택하면 드래그로 검지 끝을 직접 움직여 같은 판정 로직을 테스트할 수 있어요.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func errorBanner(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(12)
            .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var startButton: some View {
        Button {
            Task { await openSpace() }
        } label: {
            if isOpeningSpace {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label("튜토리얼 시작", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(isOpeningSpace)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: - 액션

    private func openSpace() async {
        guard !isOpeningSpace else { return }
        isOpeningSpace = true
        spaceOpenErrorMessage = nil

        switch await openImmersiveSpace(id: ddiroriApp.immersiveSpaceID) {
        case .opened:
            viewModel.immersiveSpaceEntered()
        case .userCancelled, .error:
            spaceOpenErrorMessage = TutorialMessage.spaceOpenFailed
        @unknown default:
            spaceOpenErrorMessage = TutorialMessage.spaceOpenFailed
        }

        isOpeningSpace = false
    }
}

/// 입력 방식 하나를 보여주는 선택 카드.
private struct InputModeCard: View {
    let mode: InputMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: mode.systemImageName)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(mode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(TutorialViewModel())
}
