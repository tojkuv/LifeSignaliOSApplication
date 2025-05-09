import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

/// Base view model class with common functionality for all view models
class BaseViewModel: ObservableObject {
    /// Error state for operations
    @Published var error: Error? = nil
    
    /// Loading state for operations
    @Published var isLoading: Bool = false
    
    /// Cancellables for managing subscriptions
    var cancellables = Set<AnyCancellable>()
    
    /// Initialize a new BaseViewModel
    init() {
        // Common initialization
    }
    
    /// Validates that the user is authenticated and returns the user ID
    /// - Parameter completion: Callback with user ID or error
    /// - Returns: The user ID if authenticated, nil otherwise
    func validateAuthentication(completion: ((String?, Error?) -> Void)? = nil) -> String? {
        guard AuthenticationService.shared.isAuthenticated else {
            let error = NSError(domain: "BaseViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion?(nil, error)
            return nil
        }
        
        guard let userId = AuthenticationService.shared.getCurrentUserID() else {
            let error = NSError(domain: "BaseViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not available"])
            completion?(nil, error)
            return nil
        }
        
        completion?(userId, nil)
        return userId
    }
    
    /// Calls a Firebase function with the given name and parameters
    /// - Parameters:
    ///   - functionName: The name of the function to call
    ///   - parameters: The parameters to pass to the function
    ///   - completion: Callback with result data and error
    func callFirebaseFunction(
        functionName: String,
        parameters: [String: Any],
        completion: @escaping ([String: Any]?, Error?) -> Void
    ) {
        let functions = Functions.functions(region: "us-central1")
        functions.httpsCallable(functionName).call(parameters) { result, error in
            if let error = error {
                print("Error calling \(functionName): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let data = result?.data as? [String: Any] else {
                let error = NSError(domain: "BaseViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(nil, error)
                return
            }
            
            completion(data, nil)
        }
    }
    
    /// Calls a Firebase function with the given name and parameters and handles common success/failure patterns
    /// - Parameters:
    ///   - functionName: The name of the function to call
    ///   - parameters: The parameters to pass to the function
    ///   - completion: Callback with success flag and error
    func callFirebaseFunctionWithSuccessCheck(
        functionName: String,
        parameters: [String: Any],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        callFirebaseFunction(functionName: functionName, parameters: parameters) { data, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let data = data,
                  let success = data["success"] as? Bool else {
                let serverError = NSError(domain: "BaseViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(false, serverError)
                return
            }
            
            if !success {
                let serverError = NSError(domain: "BaseViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server reported failure"])
                completion(false, serverError)
                return
            }
            
            completion(true, nil)
        }
    }
}
