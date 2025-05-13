import Foundation
import ComposableArchitecture
import FirebaseFunctions
import FirebaseAuth
import Dependencies

/// Feature for adding a new contact
@Reducer
struct AddContactFeature {
    /// The state of the add contact feature
    @ObservableState
    struct State: Equatable, Sendable {
        // MARK: - Contact Data
        @Shared(.inMemory("qrCode")) var qrCode = QRCodeData()
        var id: String = ""
        var name: String = ""
        var phone: String = ""
        var emergencyNote: String = ""
        var isResponder: Bool = false
        var isDependent: Bool = false

        // MARK: - UI State
        var isLoading: Bool = false
        var isSheetPresented: Bool = false
        var error: Error? = nil
    }

    /// Actions that can be performed on the add contact feature
    enum Action: Equatable, Sendable {
        // MARK: - UI Actions
        case setSheetPresented(Bool)

        // MARK: - Data Actions
        case updateQRCode(String)
        case lookupUserByQRCode
        case lookupUserByQRCodeResponse(TaskResult<(id: String, name: String, phone: String, emergencyNote: String)>)
        case updateName(String)
        case updatePhone(String)
        case updateIsResponder(Bool)
        case updateIsDependent(Bool)
        case addContact
        case addContactResponse(TaskResult<Bool>)
        case setError(Error?)
        case dismiss

        // MARK: - Delegate Actions
        case contactAdded(Bool, Bool) // isResponder, isDependent
    }

    /// Dependencies for the add contact feature
    @Dependency(\.firebaseContactsClient) var firebaseContactsClient
    @Dependency(\.firebaseAuth) var firebaseAuth

    /// The body of the reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - UI Actions
            case let .setSheetPresented(isPresented):
                state.isSheetPresented = isPresented
                if !isPresented {
                    // Reset state when sheet is dismissed
                    state.$qrCode.withLock { $0 = QRCodeData() }
                    state.id = ""
                    state.name = ""
                    state.phone = ""
                    state.emergencyNote = ""
                    state.isResponder = false
                    state.isDependent = false
                    state.error = nil
                }
                return .none

            // MARK: - Data Actions
            case let .updateQRCode(code):
                // Update the shared QR code state
                state.$qrCode.withLock { $0.code = code }
                state.id = ""
                state.name = ""
                state.phone = ""
                state.emergencyNote = ""

                if !code.isEmpty {
                    return .send(.lookupUserByQRCode)
                }
                return .none

            case .lookupUserByQRCode:
                state.isLoading = true

                return .run { [firebaseContactsClient, qrCode = state.qrCode.code] send in
                    guard !qrCode.isEmpty else {
                        await send(.lookupUserByQRCodeResponse(.failure(
                            FirebaseError.invalidData
                        )))
                        return
                    }

                    let result = await TaskResult {
                        try await firebaseContactsClient.lookupUserByQRCode(qrCode: qrCode)
                    }

                    await send(.lookupUserByQRCodeResponse(result))
                }

            case let .lookupUserByQRCodeResponse(result):
                state.isLoading = false

                switch result {
                case let .success(userData):
                    state.id = userData.id
                    state.name = userData.name
                    state.phone = userData.phone
                    state.emergencyNote = userData.emergencyNote
                    return .none
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .updateName(name):
                state.name = name
                return .none

            case let .updatePhone(phone):
                state.phone = phone
                return .none

            case let .updateIsResponder(isResponder):
                state.isResponder = isResponder
                return .none

            case let .updateIsDependent(isDependent):
                state.isDependent = isDependent
                return .none

            case .addContact:
                guard !state.id.isEmpty else {
                    return .none
                }

                state.isLoading = true

                return .run { [firebaseContactsClient, firebaseAuth, state] send in
                    do {
                        let userId = try await firebaseAuth.currentUserId()

                        try await firebaseContactsClient.addContactRelation(
                            userId: userId,
                            contactId: state.id,
                            isResponder: state.isResponder,
                            isDependent: state.isDependent
                        )

                        await send(.addContactResponse(.success(true)))
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.addContactResponse(.failure(userFacingError)))
                    }
                }

            case let .addContactResponse(result):
                state.isLoading = false
                switch result {
                case .success:
                    // Notify that contact was added successfully
                    return .send(.contactAdded(state.isResponder, state.isDependent))
                case let .failure(error):
                    state.error = error
                    return .none
                }

            case let .setError(error):
                state.error = error
                return .none

            case .dismiss:
                // Reset state and close sheet
                state = State()
                return .none

            case .contactAdded:
                // This action is meant to be handled by the parent
                return .none
            }
        }
    }
}