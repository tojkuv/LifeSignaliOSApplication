import SwiftUI
import Foundation
import UIKit

struct ContactView: View {
    let contact: ContactReference

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(contact.name)
                        .font(.title3)
                }

                if let lastCheckIn = contact.lastCheckIn {
                    Section {
                        Text("Last checked in: \(TimeManager.shared.formatTimeAgo(lastCheckIn))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !contact.note.isEmpty {
                    Section {
                        Text(contact.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("No emergency note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(contact.name)
        }
    }
}
