//
//  ARApp.swift
//  AR
//
//  Created by Barak Ben Hur on 27/01/2024.
//

import SwiftUI

@main
struct Diary_AiApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
