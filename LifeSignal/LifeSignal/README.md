# LifeSignal iOS App - Vertical Slice Architecture

This project uses a vertical slice architecture to organize code by feature rather than by technical role. This approach makes it easier to understand feature boundaries and reduces the need to navigate between multiple directories when working on a single feature.

## Directory Structure

```
LifeSignal/
├── App/ (App-wide components)
│   ├── LifeSignalApp.swift
│   ├── AppState.swift
│   ├── AppDelegate.swift
│   └── ContentView.swift
├── Core/ (Shared core functionality)
│   ├── Extensions/
│   ├── Models/
│   │   └── BaseUser.swift
│   ├── Services/
│   │   ├── AuthenticationService.swift
│   │   ├── FirebaseService.swift
│   │   └── NotificationService.swift
│   ├── UI/
│   │   ├── Components/
│   │   └── Styles/
│   └── ViewModels/
│       └── BaseViewModel.swift
└── Features/ (Feature-specific code)
    ├── Authentication/
    │   ├── AuthenticationView.swift
    │   └── AuthenticationViewModel.swift
    ├── Profile/
    │   ├── ProfileView.swift
    │   ├── UserProfileViewModel.swift
    │   └── User+Profile.swift
    ├── CheckIn/
    │   ├── CountdownView.swift
    │   ├── CheckInViewModel.swift
    │   └── User+CheckIn.swift
    ├── Contacts/
    │   ├── DependentsView.swift
    │   ├── RespondersView.swift
    │   ├── ContactsViewModel.swift
    │   ├── ContactsViewModel+Firestore.swift
    │   ├── ContactsViewModel+Pings.swift
    │   ├── ContactsViewModel+ContactManagement.swift
    │   └── User+Contacts.swift
    └── QRCode/
        ├── QRCodeCardView.swift
        ├── UserProfileViewModel+QRCode.swift
        └── User+QRCode.swift
```

## Key Concepts

### 1. Feature-Based Organization

Code is organized by feature rather than by technical role. Each feature directory contains all the files needed for that feature, regardless of whether they are models, views, or view models.

### 2. Core Shared Functionality

The `Core` directory contains shared functionality that is used across multiple features, such as base models, services, and utilities.

### 3. Extensions for Model Composition

Instead of having large model files, we use Swift extensions to break up models by feature. For example:

- `Core/Models/BaseUser.swift` - Contains the base User model with essential properties
- `Features/CheckIn/User+CheckIn.swift` - Adds check-in related properties and methods to the User model
- `Features/Contacts/User+Contacts.swift` - Adds contacts-related properties and methods to the User model

This approach allows each feature to define only the properties and methods it needs, making the code more modular and easier to understand.

### 4. View Model Extensions

Similarly, view models are broken up using extensions to organize functionality by feature:

- `Features/Contacts/ContactsViewModel.swift` - Core contacts functionality
- `Features/Contacts/ContactsViewModel+Firestore.swift` - Firestore-specific functionality
- `Features/Contacts/ContactsViewModel+Pings.swift` - Ping-related functionality

### 5. Dependency Injection

View models are injected into views using SwiftUI's environment objects, making it easy to share state between views and test components in isolation.

## Benefits of This Architecture

1. **Cohesion**: Related code is kept together, making it easier to understand and modify features.
2. **Reduced Navigation**: When working on a feature, you don't need to jump between multiple directories.
3. **Clear Boundaries**: Feature boundaries are explicit in the directory structure.
4. **Modularity**: Features can be developed, tested, and maintained independently.
5. **Scalability**: New features can be added without affecting existing ones.

## How to Add a New Feature

1. Create a new directory in the `Features` directory with the name of your feature.
2. Add any feature-specific views, view models, and model extensions to this directory.
3. If needed, extend existing models using Swift extensions to add feature-specific properties and methods.
4. Register any environment objects in the `LifeSignalApp.swift` file.

## Best Practices

1. Keep feature directories focused on a single responsibility.
2. Use extensions to break up large files by functionality.
3. Place shared code in the `Core` directory.
4. Use dependency injection to share state between views.
5. Keep view models focused on their specific feature.
6. Use the `App` directory only for app-wide components.
