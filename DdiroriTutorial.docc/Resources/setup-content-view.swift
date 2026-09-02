//
//  ContentView.swift
//  ddirori
//
//  Created by kiwiisae on 8/13/26.
//

import SwiftUI

/// 메인 윈도우: "튜토리얼 시작" 화면.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if let spaceOpenErrorMessage {
                    errorBanner(message: spaceOpenErrorMessage)
                }

                startButton
            }
            .padding(32)
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("띠로리 Ddirori")
                .font(.largeTitle.bold())
            Text("검지 끝으로 4/4박자 지휘 동작을 익히는 visionOS 튜토리얼")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Apple Vision Pro 실기기에서 손 추적으로 진행합니다.")
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

#Preview {
    ContentView()
        .environment(TutorialViewModel())
}
