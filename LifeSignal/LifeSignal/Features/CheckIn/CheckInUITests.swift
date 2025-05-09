//
//  CheckInUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class CheckInUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testCheckInViewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Check-in tab
        app.tabBars.buttons["Check-in"].tap()
        
        // Verify Check-in view elements are present
        XCTAssertTrue(app.staticTexts["Next Check-in"].exists)
    }
    
    @MainActor
    func testCheckInButtonInteraction() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Check-in tab
        app.tabBars.buttons["Check-in"].tap()
        
        // Tap Check-in button
        app.buttons["Check In Now"].tap()
        
        // Verify confirmation dialog or success message appears
        XCTAssertTrue(app.alerts["Check-in Successful"].exists || app.staticTexts["Checked in successfully"].exists)
    }
}
