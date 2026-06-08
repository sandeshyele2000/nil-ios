//
//  NILSampleApp.swift
//  NILSample
//
//  Created by Sandesh on 08/06/26.
//

import SwiftUI
import NIL

@main
struct NILSampleApp: App {
    init() {
        Task {
            await NIL.initialize(
                inspectorPayloadCharLimit: 200_000,
                maxStoredEvents: 300,
                persistenceEnabled: true
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
