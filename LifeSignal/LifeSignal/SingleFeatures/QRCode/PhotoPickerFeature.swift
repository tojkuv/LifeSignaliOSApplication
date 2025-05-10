import SwiftUI
import ComposableArchitecture
import PhotosUI

/// Feature for picking photos
@Reducer
struct PhotoPickerFeature {
    /// The state of the photo picker feature
    struct State: Equatable {
        /// Selected photo items
        var selectedItems: [PhotosPickerItem] = []
    }

    /// Actions that can be performed on the photo picker feature
    enum Action: Equatable {
        /// Update selected items
        case updateSelectedItems([PhotosPickerItem])

        /// Process selected items
        case processSelectedItems

        /// Dismiss the photo picker
        case dismiss
    }

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .updateSelectedItems(items):
                state.selectedItems = items
                return .none

            case .processSelectedItems:
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
