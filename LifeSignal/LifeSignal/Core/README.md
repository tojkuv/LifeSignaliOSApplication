# Core Module

This directory contains core components, utilities, and clients that are used across the application. The structure has been simplified to better follow The Composable Architecture (TCA) and vertical slice architecture principles.

## Directory Structure

- **Clients**: Protocol-based clients that provide access to external services
- **Components**: Reusable UI components
- **Constants**: Shared constants used across the application
- **Utilities**: Pure functions and extensions for common tasks

## TCA Integration

The clients in this directory are designed to be used as dependencies in TCA features. Each client follows these principles:

1. **Protocol-Based**: Each client is defined by a protocol, allowing for easy mocking in tests
2. **Dependency Injection**: Clients are registered as dependencies in the TCA dependency system
3. **Async/Await**: Clients use modern Swift concurrency for asynchronous operations
4. **Testability**: Each client has a mock implementation for testing

## Usage Example

```swift
import ComposableArchitecture

struct MyFeature: Reducer {
    struct State {
        var isLoading = false
        var errorMessage: String?
        var userData: UserData?
    }
    
    enum Action {
        case onAppear
        case userDataResponse(TaskResult<UserData>)
    }
    
    @Dependency(\.firebaseClient) var firebaseClient
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [userId = authClient.getCurrentUserId()] send in
                    guard let userId = userId else {
                        await send(.userDataResponse(.failure(AppError.notAuthenticated)))
                        return
                    }
                    
                    do {
                        let userData = try await getUserData(userId: userId)
                        await send(.userDataResponse(.success(userData)))
                    } catch {
                        await send(.userDataResponse(.failure(error)))
                    }
                }
                
            case .userDataResponse(.success(let userData)):
                state.isLoading = false
                state.userData = userData
                state.errorMessage = nil
                return .none
                
            case .userDataResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
```

## Vertical Slice Architecture

In a true vertical slice architecture, each feature would own its own models, views, and business logic. The core module should be kept as small as possible, containing only truly shared code.

When adding new functionality:

1. First consider if it belongs in a specific feature
2. Only add to core if it's used by multiple features
3. Keep dependencies between features minimal

## Constants

The `FirestoreConstants.swift` file contains shared constants used across the application. In a more complete vertical slice architecture, many of these constants would be moved to their respective feature modules.

## Utilities

Utilities like `TimeUtilities.swift` provide pure functions for common tasks. These are designed to be stateless and easily testable.

## Components

UI components like `AvatarView.swift` are designed to be reusable across the application. They should be simple, focused, and not contain business logic.
