import SwiftUI
import ComposableArchitecture

/// A SwiftUI view for configuring notification settings using TCA
struct NotificationSettingsView: View {
    /// The store for the check-in feature
    let store: StoreOf<CheckInFeature>
    
    /// Binding to control the presentation of this view
    @Binding var isPresented: Bool
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                Form {
                    Section(header: Text("Notification Lead Time")) {
                        Button {
                            viewStore.send(.updateNotificationLeadTime(30))
                            isPresented = false
                        } label: {
                            HStack {
                                Text("30 minutes")
                                Spacer()
                                if viewStore.notificationLeadTime == 30 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Button {
                            viewStore.send(.updateNotificationLeadTime(120))
                            isPresented = false
                        } label: {
                            HStack {
                                Text("2 hours")
                                Spacer()
                                if viewStore.notificationLeadTime == 120 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if viewStore.isLoading {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Notification Settings")
                .navigationBarItems(
                    trailing: Button("Cancel") {
                        isPresented = false
                    }
                )
            }
        }
    }
}
