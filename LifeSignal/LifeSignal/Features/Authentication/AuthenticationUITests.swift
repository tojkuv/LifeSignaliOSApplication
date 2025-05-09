//
//  AuthenticationUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class AuthenticationUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testAuthenticationFlow() throws {
        let app = XCUIApplication()
        // Launch app with a flag to reset authentication state for testing
        app.launchArguments = ["--uitesting", "--reset-auth"]
        app.launch()
        
        // Verify authentication screen is displayed
        XCTAssertTrue(app.staticTexts["Welcome to LifeSignal"].exists)
        
        // Enter phone number
        let phoneField = app.textFields["Phone Number"]
        XCTAssertTrue(phoneField.exists)
        phoneField.tap()
        phoneField.typeText("5551234567")
        
        // Tap Continue button
        app.buttons["Continue"].tap()
        
        // Verify verification code screen appears
        XCTAssertTrue(app.staticTexts["Verification Code"].exists)
    }
}
