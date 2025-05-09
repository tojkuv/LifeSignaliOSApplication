//
//  HomeUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class HomeUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testHomeViewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Home tab if not already there
        app.tabBars.buttons["Home"].tap()
        
        // Verify Home view elements are present
        XCTAssertTrue(app.staticTexts["Your QR Code"].exists)
    }
    
    @MainActor
    func testQRCodeDisplay() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Home tab
        app.tabBars.buttons["Home"].tap()
        
        // Verify QR code image is displayed
        XCTAssertTrue(app.images["QR Code"].exists || app.otherElements["QR Code"].exists)
    }
}
