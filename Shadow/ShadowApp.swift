//
//  ShadowApp.swift
//  Shadow
//
//  Created by Aaryan Gajula on 4/18/26.
//

import SwiftUI
import CoreData
import CoreText

@main
struct ShadowApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        registerFont(named: "CopernicusTrial-Book-BF66160450c2e92")
    }

    var body: some Scene {
        WindowGroup {
            LandingView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }

    private func registerFont(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
            print("Font not found in bundle: \(name).ttf")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}
