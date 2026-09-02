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
/// 온보딩(경로 미리보기)은 별도의 창(WindowGroup)이 아니라, `RealityView`의 attachment
/// 기능으로 이 Immersive Space 안, 실제 연습 Zone과 똑같은 위치(`configuration.zoneCenter`)에
/// 직접 배치한다. 창은 시스템이 정하는 임의의 거리에 뜨기 때문에, 온보딩을 보다가 연습이
/// 시작되면 Zone이 눈앞으로 갑자기 "튀어나오는" 것처럼 느껴지는데, 온보딩과 연습이 같은
/// 좌표·같은 거리를 공유하면 그 문제가 사라진다. "종료" 버튼도 같은 방법으로, Zone 아래에
/// 진짜 SwiftUI 버튼을 3D로 띄운다.
struct ImmersiveView: View {
    @Environment(TutorialViewModel.self) private var viewModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private static let onboardingAttachmentID = "onboarding"
    private static let exitButtonAttachmentID = "exitButton"

    // 3D 콘텐츠는 두 그룹으로 나뉘어 rootEntity 아래에 나란히 놓이고, 어느 한쪽만 보이도록
    // isEnabled를 서로 반대로 토글한다 (updateScene() 참고).
    @State private var rootEntity = Entity()
    /// 연습용 3D 콘텐츠(Zone, 손끝, 종료 버튼, 표시등 등)를 담는 컨테이너. 온보딩 중에는 숨긴다.
    @State private var practiceContentEntity = Entity()
    /// 온보딩(경로 미리보기) attachment. 연습 중에는 숨긴다.
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
            addPracticeContent(to: practiceContentEntity, attachments: attachments, configuration: viewModel.configuration)
            attachOnboarding(from: attachments, to: rootEntity, configuration: viewModel.configuration)
        } update: { _, _ in
            updateScene()
        } attachments: {
            // 여기 정의된 SwiftUI 뷰들이 위 make 클로저에서
            // `attachments.entity(for: <id>)`로 조회할 수 있는 Entity가 된다.
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

    // MARK: - 3D 콘텐츠 조립 (RealityView의 make 클로저에서 한 번만 호출됨)

    /// Zone, 손끝, 종료 버튼, 표시등, 완료 텍스트를 만들어 `container` 아래에 배치한다.
    private func addPracticeContent(to container: Entity, attachments: RealityViewAttachments, configuration: TutorialConfiguration) {
        for zoneEntity in zoneEntities {
            container.addChild(zoneEntity)
        }

        let handle = FingertipEntity.make(configuration: configuration)
        handle.isEnabled = false
        container.addChild(handle)
        fingertipEntity = handle

        // "종료" 버튼은 3D 구체가 아니라 진짜 SwiftUI Button이다. RealityView의 attachment
        // 기능(위 `attachments:` 클로저)이 SwiftUI 뷰를 렌더링해 Entity로 돌려주므로,
        // 그 Entity를 다른 3D 오브젝트처럼 원하는 위치에 배치하면 된다.
        if let exitButton = attachments.entity(for: Self.exitButtonAttachmentID) {
            exitButton.position = BeatZoneLayout.exitButtonPosition(configuration: configuration)
            exitButton.components.set(BillboardComponent()) // 항상 사용자를 정면으로 바라보게 함
            container.addChild(exitButton)
        }

        let lightPositions = BeatZoneLayout.progressLightPositions(
            count: progressLightEntities.count,
            configuration: configuration
        )
        for (index, light) in progressLightEntities.enumerated() {
            light.position = lightPositions[index]
            container.addChild(light)
        }

        progressLabelEntity.position = BeatZoneLayout.progressLabelPosition(configuration: configuration)
        container.addChild(progressLabelEntity)

        progressTitleEntity.position = BeatZoneLayout.progressTitlePosition(configuration: configuration)
        container.addChild(progressTitleEntity)

        completionTextEntity.position = BeatZoneLayout.completionTextPosition(configuration: configuration)
        container.addChild(completionTextEntity)
    }

    /// 온보딩 attachment를 Zone과 같은 위치(zoneCenter)에 붙인다.
    private func attachOnboarding(from attachments: RealityViewAttachments, to root: Entity, configuration: TutorialConfiguration) {
        guard let onboarding = attachments.entity(for: Self.onboardingAttachmentID) else { return }
        onboarding.position = configuration.zoneCenter
        onboarding.components.set(BillboardComponent())
        root.addChild(onboarding)
        onboardingEntity = onboarding
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
        case .idle, .calibrating, .demonstrating, .error:
            return .idle
        }
    }

    private func updateFingertip() {
        guard let fingertipEntity else { return }
        FingertipEntity.setVisible(fingertipEntity, visible: viewModel.isFingertipVisible)
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

        // updateScene()은 손 추적 프레임마다(초당 수십 번) 불리지만, 텍스트 갱신은
        // 3D 텍스트 Mesh를 매번 새로 생성하는 비교적 무거운 작업이라 값이 실제로
        // 바뀌었을 때만 수행한다.
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
