//
//  ContactsUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class ContactsUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testDependentsViewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Dependents tab
        app.tabBars.buttons["Dependents"].tap()
        
        // Verify Dependents view elements are present
        XCTAssertTrue(app.navigationBars["Dependents"].exists)
    }
    
    @MainActor
    func testRespondersViewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Responders tab
        app.tabBars.buttons["Responders"].tap()
        
        // Verify Responders view elements are present
        XCTAssertTrue(app.navigationBars["Responders"].exists)
    }
}
