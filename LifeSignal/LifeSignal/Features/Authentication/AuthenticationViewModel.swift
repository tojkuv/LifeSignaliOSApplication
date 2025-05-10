import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// ViewModel for managing user authentication
class AuthenticationViewModel: BaseViewModel {
    // MARK: - Published Properties

    /// Phone number for authentication
    @Published var phoneNumber: String = ""

    /// Phone region for authentication
    @Published var phoneRegion: String = "US"

    /// Verification code entered by the user
    @Published var verificationCode: String = ""

    /// Verification ID received from Firebase
    @Published var verificationID: String = ""

    /// Flag indicating if verification code has been sent
    @Published var isCodeSent: Bool = false

    /// Flag indicating if user is authenticated
    @Published var isAuthenticated: Bool = false

    // MARK: - Initialization

    override init() {
        super.init()

        // Check if user is already authenticated
        isAuthenticated = AuthenticationService.shared.isAuthenticated
    }

    // MARK: - Authentication Methods

    /// Send verification code to the provided phone number
    /// - Parameter completion: Optional callback with success flag and error
    func sendVerificationCode(completion: ((Bool, Error?) -> Void)? = nil) {
        guard !phoneNumber.isEmpty else {
            let error = NSError(domain: "AuthenticationViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Phone number is required"])
            completion?(false, error)
            return
        }

        isLoading = true

        // Format the phone number with country code
        let formattedPhoneNumber = formatPhoneNumber(phoneNumber, region: phoneRegion)

        // Send verification code
        AuthenticationService.shared.signInWithPhoneNumber(formattedPhoneNumber) { [weak self] verificationID, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Error sending verification code: \(error.localizedDescription)")
                self.error = error
                completion?(false, error)
                return
            }

            guard let verificationID = verificationID else {
                let error = NSError(domain: "AuthenticationViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "No verification ID received"])
                self.error = error
                completion?(false, error)
                return
            }

            // Store the verification ID
            DispatchQueue.main.async {
                self.verificationID = verificationID
                self.isCodeSent = true
            }

            print("Verification code sent successfully")
            completion?(true, nil)
        }
    }

    /// Verify the code entered by the user
    /// - Parameters:
    ///   - isAuthenticated: Binding to update authentication state
    ///   - needsOnboarding: Binding to update onboarding state
    ///   - completion: Optional callback with success flag and error
    func verifyCode(isAuthenticated: Binding<Bool>, needsOnboarding: Binding<Bool>, completion: ((Bool, Error?) -> Void)? = nil) {
        guard !verificationCode.isEmpty else {
            let error = NSError(domain: "AuthenticationViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Verification code is required"])
            completion?(false, error)
            return
        }

        guard !verificationID.isEmpty else {
            let error = NSError(domain: "AuthenticationViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "No verification ID available"])
            completion?(false, error)
            return
        }

        isLoading = true

        // Verify the code
        AuthenticationService.shared.verifyCode(verificationID: verificationID, verificationCode: verificationCode) { [weak self] authResult, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("Error verifying code: \(error.localizedDescription)")
                self.error = error
                completion?(false, error)
                return
            }

            guard let authResult = authResult else {
                let error = NSError(domain: "AuthenticationViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "No authentication result received"])
                self.error = error
                completion?(false, error)
                return
            }

            // Check if user exists in Firestore
            self.checkUserExists(userId: authResult.user.uid) { exists, error in
                if let error = error {
                    print("Error checking if user exists: \(error.localizedDescription)")
                    self.error = error
                    completion?(false, error)
                    return
                }

                // Update authentication state
                DispatchQueue.main.async {
                    self.isAuthenticated = true
                    isAuthenticated.wrappedValue = true

                    // If user doesn't exist, they need onboarding
                    needsOnboarding.wrappedValue = !exists
                }

                print("Code verified successfully. User exists: \(exists)")
                completion?(true, nil)
            }
        }
    }

    /// Check if a user exists in Firestore
    /// - Parameters:
    ///   - userId: The user ID to check
    ///   - completion: Callback with existence flag and error
    private func checkUserExists(userId: String, completion: @escaping (Bool, Error?) -> Void) {
        let db = Firestore.firestore()
        let userRef = db.collection(FirestoreCollections.users).document(userId)

        userRef.getDocument { document, error in
            if let error = error {
                print("Error checking if user exists: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            let exists = document?.exists ?? false
            completion(exists, nil)
        }
    }

    /// Format a phone number with country code
    /// - Parameters:
    ///   - phoneNumber: The phone number to format
    ///   - region: The phone region (country code)
    /// - Returns: The formatted phone number
    private func formatPhoneNumber(_ phoneNumber: String, region: String) -> String {
        var formattedNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove any non-numeric characters
        formattedNumber = formattedNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        // Add country code if not already present
        if !formattedNumber.hasPrefix("+") {
            switch region {
            case "US":
                formattedNumber = "+1" + formattedNumber
            case "CA":
                formattedNumber = "+1" + formattedNumber
            case "UK":
                formattedNumber = "+44" + formattedNumber
            // Add more countries as needed
            default:
                formattedNumber = "+1" + formattedNumber // Default to US
            }
        }

        return formattedNumber
    }
}
