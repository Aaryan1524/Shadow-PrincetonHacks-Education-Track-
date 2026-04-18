//
//  ShadowApp.swift
//  Shadow
//
//  Created by Aaryan Gajula on 4/18/26.
//

import SwiftUI
import CoreData
import MWDATCore

@main
struct ShadowApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        do {
            try Wearables.configure()
        } catch {
            assertionFailure("Failed to configure Wearables SDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView(wearables: Wearables.shared)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
