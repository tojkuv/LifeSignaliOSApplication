//
//  AppUITests.swift
//  LifeSignalUITests
//
//  Created by AI Assistant on 10/30/25.
//

import XCTest

final class AppUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify app launches successfully
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testTabBarNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test navigation between tabs
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        
        app.tabBars.buttons["Dependents"].tap()
        XCTAssertTrue(app.tabBars.buttons["Dependents"].isSelected)
        
        app.tabBars.buttons["Responders"].tap()
        XCTAssertTrue(app.tabBars.buttons["Responders"].isSelected)
        
        app.tabBars.buttons["Check-in"].tap()
        XCTAssertTrue(app.tabBars.buttons["Check-in"].isSelected)
        
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
