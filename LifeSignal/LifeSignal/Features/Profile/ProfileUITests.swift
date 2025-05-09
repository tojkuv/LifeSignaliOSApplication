//
//  ProfileUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class ProfileUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testProfileViewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Profile tab
        app.tabBars.buttons["Profile"].tap()
        
        // Verify Profile view elements are present
        XCTAssertTrue(app.navigationBars["Profile"].exists)
    }
    
    @MainActor
    func testEditProfileFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Profile tab
        app.tabBars.buttons["Profile"].tap()
        
        // Tap Edit button
        app.buttons["Edit"].tap()
        
        // Verify Edit Profile view is displayed
        XCTAssertTrue(app.navigationBars["Edit Profile"].exists)
    }
}
