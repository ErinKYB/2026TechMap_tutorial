//
//  ImmersiveView.swift
//  ddirori
//
//  Created by kiwiisae on 8/13/26.
//

import RealityKit
import SwiftUI

/// Immersive Space 콘텐츠.
///
/// 이 View는 `TutorialViewModel`을 관찰만 하고, 판정/상태 전이는 절대 수행하지 않는다.
///
/// 온보딩(경로 미리보기)은 더 이상 별도의 창(WindowGroup)으로 띄우지 않는다. 창은 시스템이
/// 정하는 거리(보통 실제 연습 Zone보다 훨씬 멂)에 뜨기 때문에, 온보딩을 보다가 연습이
/// 시작되면 오브젝트가 갑자기 눈앞으로 "튀어나오는" 것처럼 느껴졌다. 대신 `RealityView`의
/// attachment 기능으로 온보딩 SwiftUI 뷰를 이 Immersive Space 안, Zone과 똑같은 위치
/// (`configuration.zoneCenter`)에 직접 배치한다 — 온보딩과 실제 연습이 같은 좌표계, 같은
/// 거리를 공유하므로 전환 시 위치가 튀지 않는다.
struct ImmersiveView: View {
    @Environment(TutorialViewModel.self) private var viewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var rootEntity = Entity()
    /// 연습용 3D 콘텐츠(Zone, 손끝, 종료 버튼, 표시등 등)를 담는 컨테이너.
    /// 온보딩 중에는 이 전체를 숨긴다.
    @State private var practiceContentEntity = Entity()
    @State private var onboardingEntity: Entity?

    @State private var zoneEntities: [ModelEntity] = (1...4).map {
        BeatZoneEntity.make(beat: $0, configuration: .default)
    }
    @State private var fingertipEntity: ModelEntity?
    @State private var progressLightEntities = ControlEntity.makeProgressLights(
        count: TutorialConfiguration.default.requiredConsecutiveCycles,
        configuration: .default
    )
    @State private var progressLabelEntity = ControlEntity.makeProgressLabel(
        required: TutorialConfiguration.default.requiredConsecutiveCycles
    )
    @State private var progressTitleEntity = ControlEntity.makeProgressTitle(
        required: TutorialConfiguration.default.requiredConsecutiveCycles
    )
    @State private var completionTextEntity = ControlEntity.makeCompletionText()

    @State private var lastRenderedConsecutiveCycles: Int = -1

    var body: some View {
        RealityView { content, attachments in
            content.add(rootEntity)
            rootEntity.addChild(practiceContentEntity)

            for zoneEntity in zoneEntities {
                practiceContentEntity.addChild(zoneEntity)
            }

            let handle = FingertipEntity.make(
                configuration: viewModel.configuration,
                isDraggableHandle: viewModel.isSimulatorMode
            )
            // 시뮬레이터 모드에서는 손 추적 파이프라인의 첫 샘플을 기다리지 않고
            // 드래그 핸들을 곧바로 보여준다 (그래야 사용자가 처음부터 잡을 대상이 보인다).
            handle.isEnabled = viewModel.isSimulatorMode
            practiceContentEntity.addChild(handle)
            fingertipEntity = handle

            if let exitButton = attachments.entity(for: Self.exitButtonAttachmentID) {
                exitButton.position = BeatZoneLayout.exitButtonPosition(configuration: viewModel.configuration)
                exitButton.components.set(BillboardComponent())
                practiceContentEntity.addChild(exitButton)
            }

            let lightPositions = BeatZoneLayout.progressLightPositions(
                count: progressLightEntities.count,
                configuration: viewModel.configuration
            )
            for (index, light) in progressLightEntities.enumerated() {
                light.position = lightPositions[index]
                practiceContentEntity.addChild(light)
            }

            progressLabelEntity.position = BeatZoneLayout.progressLabelPosition(configuration: viewModel.configuration)
            practiceContentEntity.addChild(progressLabelEntity)

            progressTitleEntity.position = BeatZoneLayout.progressTitlePosition(configuration: viewModel.configuration)
            practiceContentEntity.addChild(progressTitleEntity)

            completionTextEntity.position = BeatZoneLayout.completionTextPosition(configuration: viewModel.configuration)
            practiceContentEntity.addChild(completionTextEntity)

            // 온보딩(경로 미리보기)을 Zone과 같은 지점(zoneCenter)에 붙인다.
            if let onboarding = attachments.entity(for: Self.onboardingAttachmentID) {
                onboarding.position = viewModel.configuration.zoneCenter
                onboarding.components.set(BillboardComponent())
                rootEntity.addChild(onboarding)
                onboardingEntity = onboarding
            }
        } update: { _, _ in
            updateScene()
        } attachments: {
            Attachment(id: Self.onboardingAttachmentID) {
                ConductorOnboardingView {
                    viewModel.finishOnboarding()
                }
            }
            Attachment(id: Self.exitButtonAttachmentID) {
                Button(role: .destructive) {
                    viewModel.prepareForExit()
                    Task { await dismissImmersiveSpace() }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text("종료")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
            }
        }
        .gesture(fingertipDragGesture)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            ImmersiveStatusOrnament()
        }
        // 연습 종료/진행 표시와 온보딩이 이제 3D 콘텐츠 안에 항상 존재하므로,
        // 메인 윈도우는 Immersive Space가 열려 있는 동안 계속 닫아둔다.
        .onAppear { dismissWindow(id: ddiroriApp.mainWindowID) }
        .onDisappear { openWindow(id: ddiroriApp.mainWindowID) }
        .onChange(of: viewModel.phase) { _, newPhase in
            // "성공!" 텍스트가 뜨고 3초 후 자동으로 연습을 종료한다.
            guard newPhase == .completed else { return }
            Task {
                try? await Task.sleep(for: .seconds(3))
                guard viewModel.phase == .completed else { return }
                viewModel.prepareForExit()
                await dismissImmersiveSpace()
            }
        }
    }

    private static let onboardingAttachmentID = "onboarding"
    private static let exitButtonAttachmentID = "exitButton"

    // MARK: - Gesture (시뮬레이터 모드 전용)

    private var fingertipDragGesture: some Gesture {
        DragGesture()
            .targetedToEntity(fingertipEntity ?? rootEntity)
            .onChanged { value in
                guard viewModel.isSimulatorMode else { return }
                let newPosition = value.convert(value.location3D, from: .local, to: practiceContentEntity)
                fingertipEntity?.position = newPosition
                viewModel.updateSimulatedFingerPosition(newPosition)
            }
    }

    // MARK: - 매 업데이트마다 Entity에 상태 반영

    private func updateScene() {
        // 온보딩(경로 미리보기) 동안에는 연습용 3D 콘텐츠를 숨기고, 그 반대도 마찬가지로 한다.
        let isOnboarding = viewModel.phase == .demonstrating
        practiceContentEntity.isEnabled = !isOnboarding
        onboardingEntity?.isEnabled = isOnboarding

        guard !isOnboarding else { return }

        updateZones()
        updateFingertip()
        updateProgressLights()
        updateCompletionText()
    }

    private func updateZones() {
        let positions = viewModel.beatZonePositions
        for (index, zoneEntity) in zoneEntities.enumerated() {
            zoneEntity.position = positions[index]
            BeatZoneEntity.update(zoneEntity, state: visualState(forZoneBeat: index + 1))
        }
    }

    private func visualState(forZoneBeat beat: Int) -> BeatZoneVisualState {
        switch viewModel.phase {
        case .practicing, .trackingPaused:
            if beat == viewModel.progress.currentBeat { return .current }
            return beat < viewModel.progress.currentBeat ? .completed : .idle
        case .cycleSuccess, .completed:
            return .completed
        case .idle, .openingSpace, .calibrating, .demonstrating, .error:
            return .idle
        }
    }

    private func updateFingertip() {
        guard let fingertipEntity else { return }
        FingertipEntity.setVisible(fingertipEntity, visible: viewModel.isFingertipVisible)

        // 시뮬레이터 모드에서는 드래그 제스처가 위치를 직접 갱신하므로 여기서 덮어쓰지 않는다.
        guard !viewModel.isSimulatorMode else { return }
        if let position = viewModel.latestFingerSample.position {
            fingertipEntity.position = position
        }
    }

    /// 신호등처럼, 연속 성공 횟수만큼 표시등을 켠다.
    private func updateProgressLights() {
        let consecutiveCycles = viewModel.progress.consecutiveCycles
        for (index, light) in progressLightEntities.enumerated() {
            ControlEntity.updateProgressLight(light, isLit: index < consecutiveCycles)
        }

        guard lastRenderedConsecutiveCycles != consecutiveCycles else { return }
        lastRenderedConsecutiveCycles = consecutiveCycles
        ControlEntity.updateProgressLabel(
            progressLabelEntity,
            current: consecutiveCycles,
            required: viewModel.configuration.requiredConsecutiveCycles
        )
    }

    /// 연속 성공 횟수를 다 채우면(완료) Zone 중앙에 "성공!" 텍스트를 띄운다.
    private func updateCompletionText() {
        ControlEntity.setCompletionTextVisible(completionTextEntity, visible: viewModel.phase == .completed)
    }
}
