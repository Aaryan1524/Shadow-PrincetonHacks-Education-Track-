//
//  ShadowApp.swift
//  Shadow
//
//  Created by Aaryan Gajula on 4/18/26.
//

import SwiftUI
import CoreData

@main
struct ShadowApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
