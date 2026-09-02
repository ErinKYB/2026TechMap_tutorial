//
//  ddiroriApp.swift
//  ddirori
//
//  Created by kiwiisae on 8/13/26.
//

import SwiftUI

@main
struct ddiroriApp: App {
    static let immersiveSpaceID = "ImmersiveSpace"
    static let mainWindowID = "ddiroriMain"

    @State private var viewModel = TutorialViewModel()

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView()
                .environment(viewModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 640, height: 520)

        ImmersiveSpace(id: Self.immersiveSpaceID) {
            ImmersiveView()
                .environment(viewModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
