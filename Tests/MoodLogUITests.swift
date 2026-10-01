import XCTest

final class MoodLogUITests: XCTestCase {
    @MainActor func testCompleteRecordAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        func tap(_ id: String) {
            if id.hasPrefix("choice_clock"), let minutes = Int(id.dropFirst("choice_clock".count)) {
                let bedtime = app.staticTexts["question"].label.contains("寝た")
                let normal = bedtime ? "18:00〜翌5:30" : "3:00〜14:30"
                let inNormal = bedtime ? (minutes >= 1080 || minutes < 360) : (minutes >= 180 && minutes < 900)
                if (app.staticTexts["clockWindow"].label == normal) != inNormal { app.buttons["clockWindowToggle"].tap() }
                let angle = Double(minutes % 720) / 720 * .pi * 2 - .pi / 2
                app.otherElements["clockDial"].coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)).tap()
                return
            }
            if app.state != .runningForeground { app.activate() }
            let button = app.buttons[id]
            if !button.exists { XCTAssertTrue(button.waitForExistence(timeout: 5), id) }
            if id == "deleteCustom" && !button.isHittable { app.scrollViews["itemSettingsScroll"].swipeUp() }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
            if !button.isEnabled || !button.isHittable { XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, id) }
            let question = app.staticTexts["question"]
            let previous = question.exists ? question.label : ""
            button.tap()
            let advances = id == "skip" || id == "back" || id == "substanceNotUsed" || ["choice_", "nutrition_", "range_", "conversation_", "event_", "pleasant_", "substance_"].contains { id.hasPrefix($0) }
            if advances && !previous.isEmpty {
                let progressed = NSPredicate { _, _ in !question.exists || question.label != previous || app.alerts.count > 0 }
                let wait = XCTNSPredicateExpectation(predicate: progressed, object: nil)
                if XCTWaiter.wait(for: [wait], timeout: 1) != .completed && button.exists {
                    // An OS interruption can consume the first tap. Retry only while
                    // the same question is still visible, never on the next question.
                    if app.state != .runningForeground { app.activate() }
                    if question.exists && question.label == previous { button.tap() }
                }
            }
        }
        func capture(_ name: String) {
            Thread.sleep(forTimeInterval: 0.35)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        capture("01-mood")
        tap("choice_mood4")
        capture("02-energy")
        tap("choice_energy3")
        capture("03-hunger")
        tap("choice_hunger3")
        capture("03-bedtime")
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "18:00〜翌5:30")
        let dial = app.otherElements["clockDial"]
        XCTAssertTrue(dial.isHittable)
        let firstDialY = dial.frame.minY
        tap("choice_clock0")
        XCTAssertTrue(app.staticTexts["question"].label.contains("起きた"))
        tap("back")
        XCTAssertEqual(app.staticTexts["clockTime"].label, "0:00")
        tap("clockWindowToggle")
        XCTAssertEqual(app.staticTexts["clockTime"].label, "12:00")
        XCTAssertTrue(app.staticTexts["question"].label.contains("寝た"), "Window switching does not commit by itself")
        tap("clockWindowToggle")
        let startAngle = Double.pi / 2
        let endAngle = Double(23) * Double.pi / 12 - Double.pi / 2
        let start = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(startAngle) * 0.29, dy: 0.5 + sin(startAngle) * 0.29))
        let end = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(endAngle) * 0.415, dy: 0.5 + sin(endAngle) * 0.415))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["clockWindow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["question"].label.contains("起きた"))
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "3:00〜14:30")
        XCTAssertEqual(dial.frame.minY, firstDialY, accuracy: 1)
        capture("04-wake-time")
        tap("back")
        XCTAssertEqual(app.staticTexts["clockTime"].label, "23:30", "Drag snaps to the half-hour between 11 and 12")
        capture("bedtime-dial-selected")
        tap("choice_clock1410")
        tap("choice_clock420")
        capture("05-iron")
        let matrixFirst = app.buttons["nutrition_today_0"].frame
        let matrixLast = app.buttons["nutrition_older_2"].frame
        XCTAssertTrue(app.buttons["nutrition_older_2"].isHittable)
        tap("ironExamples")
        XCTAssertTrue(app.staticTexts["野菜"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["小松菜・ほうれん草・春菊・水菜"].isHittable)
        capture("iron-examples")
        tap("closeExamples")
        tap("nutrition_yesterday_1")
        capture("06-b12")
        XCTAssertEqual(app.buttons["nutrition_today_0"].frame.minY, matrixFirst.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["nutrition_older_2"].frame.maxY, matrixLast.maxY, accuracy: 1)
        tap("nutrition_today_2")
        tap("back")
        XCTAssertTrue(app.buttons["nutrition_today_2"].waitForExistence(timeout: 5))
        tap("nutrition_today_1")
        capture("07-exercise")
        let dateFirstY = app.buttons["range_today"].frame.minY
        let dateLastY = app.buttons["range_older"].frame.maxY
        XCTAssertFalse(app.buttons["previousMonth"].exists)
        XCTAssertFalse(app.staticTexts["todayHeading"].exists)
        XCTAssertEqual(app.buttons["range_today"].frame.midX, app.buttons["range_older"].frame.midX, accuracy: 1)
        XCTAssertFalse(app.buttons["range_today"].isSelected)
        tap("range_today"); tap("back")
        XCTAssertTrue(app.buttons["range_today"].isSelected)
        selectDateRange(app, offset: -2)
        capture("08-obligation")
        XCTAssertEqual(app.buttons["range_today"].frame.minY, dateFirstY, accuracy: 1)
        XCTAssertEqual(app.buttons["range_older"].frame.maxY, dateLastY, accuracy: 1)
        tap("range_today")
        capture("09-next-obligation")
        XCTAssertEqual(app.buttons["range_today"].frame.minY, dateFirstY, accuracy: 1)
        XCTAssertEqual(app.buttons["range_older"].frame.maxY, dateLastY, accuracy: 1)
        selectDateRange(app, offset: 1)
        tap("back"); tap("back")
        tap("choice_inProgress")
        XCTAssertTrue(app.buttons["choice_backlog0"].waitForExistence(timeout: 5), "In-progress obligation skips the next obligation question")
        tap("back")
        XCTAssertTrue(app.buttons["choice_inProgress"].exists, "Back skips the omitted next shift")
        tap("choice_inProgress")
        capture("10-backlog")
        XCTAssertTrue(app.buttons["choice_backlog4"].isHittable)
        tap("choice_backlog3")
        capture("10-conversation")
        XCTAssertEqual(app.buttons["conversation_today_0"].frame.minY, matrixFirst.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["conversation_older_2"].frame.maxY, matrixLast.maxY, accuracy: 1)
        tap("conversation_threeToSix_2")
        capture("11-event")
        XCTAssertEqual(app.buttons["event_today_0"].frame.minY, matrixFirst.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["event_older_2"].frame.maxY, matrixLast.maxY, accuracy: 1)
        XCTAssertTrue(app.buttons["event_older_2"].isHittable)
        tap("event_yesterday_1")
        XCTAssertTrue(app.buttons["pleasant_older_2"].isHittable)
        capture("12-pleasant-event")
        XCTAssertEqual(app.buttons["pleasant_today_0"].frame.minY, matrixFirst.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["pleasant_older_2"].frame.maxY, matrixLast.maxY, accuracy: 1)
        tap("pleasant_today_2")
        capture("14-caffeine")
        XCTAssertEqual(app.buttons["substance_today_0"].frame.minY, matrixFirst.minY, accuracy: 1)
        XCTAssertEqual(app.buttons["substance_older_2"].frame.maxY, matrixLast.maxY, accuracy: 1)
        tap("substance_today_2")
        capture("15-alcohol")
        tap("substanceNotUsed")
        capture("16-tobacco")
        tap("substanceNotUsed")
        capture("17-save")
        XCTAssertTrue(app.buttons["voice"].isHittable)
        XCTAssertFalse(app.buttons["keyboardMemo"].exists)
        XCTAssertEqual(app.textViews.count, 0)
        XCTAssertEqual(app.textFields.count, 0)
        tap("save")
        XCTAssertTrue(app.buttons["choice_mood4"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        tap("review")
        capture("review-trend")
        app.segmentedControls["reviewTabs"].buttons["比較"].tap()
        tap("factorMenu"); app.buttons["溜まった用事"].tap()
        XCTAssertTrue(app.staticTexts["そこそこ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["とても多い"].exists)
        capture("review-comparison")
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["昨日・1食分"].exists)
        XCTAssertTrue(app.staticTexts["今日・1食分"].exists)
        XCTAssertTrue(app.staticTexts["今やっている"].exists)
        XCTAssertTrue(app.staticTexts["多い"].exists)
        XCTAssertFalse(app.staticTexts["明日"].exists, "Working clears the old next shift answer")
        XCTAssertTrue(app.staticTexts["23:30→7:00（7時間30分）"].exists)
        XCTAssertFalse(app.buttons["historyNextPage"].exists)
        XCTAssertTrue(app.staticTexts["3〜6日前・長時間"].exists)
        XCTAssertTrue(app.staticTexts["昨日・かなりつらかった"].exists)
        XCTAssertTrue(app.staticTexts["今日・とても楽しかった"].exists)
        capture("review-history")
        tap("closeReview")
        tap("customSettings")
        XCTAssertEqual(app.switches["substanceVisible_16"].value as? String, "1")
        XCTAssertEqual(app.switches["substanceVisible_17"].value as? String, "0")
        XCTAssertEqual(app.switches["substanceVisible_18"].value as? String, "0")
        app.switches["substanceVisible_17"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["substanceVisible_17"].value as? String, "1")
        capture("substance-settings")
        tap("closeCustom")
        tap("choice_mood2")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["choice_energy3"].waitForExistence(timeout: 5))
        for _ in 0..<24 { if app.buttons["save"].exists { break }; tap("skip") }
        tap("save")
        tap("review")
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["昨日・1食分（引継ぎ）"].exists)
        XCTAssertTrue(app.staticTexts["今日・多め（引継ぎ）"].exists)
        XCTAssertTrue(app.staticTexts["3〜6日前・長時間（引継ぎ）"].exists)
        XCTAssertFalse(app.staticTexts["今やっている（引継ぎ）"].exists)
        XCTAssertFalse(app.staticTexts["多い"].exists, "Backlog is not filled from the previous record")
        XCTAssertFalse(app.buttons["historyNextPage"].exists)
        capture("carried-history")
        tap("closeReview")
        tap("choice_mood3"); tap("skip"); tap("skip"); tap("skip"); tap("skip")
        XCTAssertTrue(app.staticTexts["carryPreview"].exists)
        tap("clearAnswer")
        XCTAssertFalse(app.staticTexts["carryPreview"].exists)
        XCTAssertFalse(app.buttons["clearAnswer"].isEnabled)
        for _ in 0..<24 { if app.buttons["save"].exists { break }; tap("skip") }
        tap("save"); tap("review")
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertFalse(app.staticTexts["昨日・1食分（引継ぎ）"].exists)
        tap("deleteRecord"); app.buttons["削除する"].tap()
        XCTAssertTrue(app.staticTexts["2 / 2件"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["昨日・1食分（引継ぎ）"].exists)
        tap("closeReview")
    }
}

// Exercise dynamic questions across relaunch, skip, hide, review, and display modes.
extension MoodLogUITests {
    @MainActor func testCustomQuestionAndMemoDisplay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        func tap(_ id: String) {
            if id.hasPrefix("choice_clock"), let minutes = Int(id.dropFirst("choice_clock".count)) {
                let bedtime = app.staticTexts["question"].label.contains("寝た")
                let normal = bedtime ? "18:00〜翌5:30" : "3:00〜14:30"
                let inNormal = bedtime ? (minutes >= 1080 || minutes < 360) : (minutes >= 180 && minutes < 900)
                if (app.staticTexts["clockWindow"].label == normal) != inNormal { app.buttons["clockWindowToggle"].tap() }
                let angle = Double(minutes % 720) / 720 * .pi * 2 - .pi / 2
                app.otherElements["clockDial"].coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)).tap()
                return
            }
            if app.state != .runningForeground { app.activate() }
            let button = app.buttons[id]
            if !button.exists { XCTAssertTrue(button.waitForExistence(timeout: 5), id) }
            if id == "deleteCustom" && !button.isHittable { app.scrollViews["itemSettingsScroll"].swipeUp() }
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true AND hittable == true"), object: button)
            if !button.isEnabled || !button.isHittable { XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, id) }
            let question = app.staticTexts["question"]
            let previous = question.exists ? question.label : ""
            button.tap()
            let advances = id == "skip" || id == "back" || id == "substanceNotUsed" || ["choice_", "nutrition_", "range_", "conversation_", "event_", "pleasant_", "substance_"].contains { id.hasPrefix($0) }
            if advances && !previous.isEmpty {
                let progressed = NSPredicate { _, _ in !question.exists || question.label != previous || app.alerts.count > 0 }
                let wait = XCTNSPredicateExpectation(predicate: progressed, object: nil)
                if XCTWaiter.wait(for: [wait], timeout: 1) != .completed && button.exists {
                    // An OS interruption can consume the first tap. Retry only while
                    // the same question is still visible, never on the next question.
                    if app.state != .runningForeground { app.activate() }
                    if question.exists && question.label == previous { button.tap() }
                }
            }
        }
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        tap("customSettings")
        XCTAssertFalse(app.staticTexts["気分との関係を知りたいことを、自分の質問に。"].exists)
        capture("custom-empty")
        tap("addCustom")
        XCTAssertTrue(app.staticTexts["項目名"].exists)
        capture("custom-editor")
        app.descendants(matching: .any).matching(identifier: "customTitle").firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "customTitle").firstMatch.typeText("Coffee")
        tap("customNext"); tap("kind_options"); tap("customNext")
        app.textViews["customOptions"].tap()
        app.textViews["customOptions"].typeText("None\n1 cup\n2 cups")
        tap("customNext")
        XCTAssertTrue(app.staticTexts["Coffee"].waitForExistence(timeout: 5))
        capture("custom-settings")
        tap("closeCustom")
        tap("choice_mood4"); tap("choice_energy3"); tap("choice_hunger3")
        for _ in 0..<24 { if app.buttons["choice_option2"].exists { break }; tap("skip") }
        XCTAssertTrue(app.buttons["choice_option2"].waitForExistence(timeout: 5))
        capture("custom-question")
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["choice_option2"].waitForExistence(timeout: 5), "Restore custom step by stable ID")
        tap("choice_option1")
        XCTAssertFalse(app.buttons["keyboardMemo"].exists)
        XCTAssertEqual(app.textViews.count, 0)
        tap("save")
        tap("customSettings")
        let visibility = app.switches["customEnabled"]
        XCTAssertEqual(visibility.value as? String, "1")
        visibility.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(visibility.value as? String, "0")
        tap("closeCustom")
        tap("review")
        XCTAssertTrue(app.staticTexts["Coffee"].exists, "Custom rows remain in the same graph")
        XCTAssertFalse(app.buttons["次の項目"].exists)
        capture("custom-timeline")
        app.segmentedControls["reviewTabs"].buttons["比較"].tap()
        tap("factorMenu"); app.buttons["Coffee"].tap()
        XCTAssertTrue(app.staticTexts["1 cup"].waitForExistence(timeout: 5))
        capture("custom-comparison")
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertFalse(app.buttons["historyNextPage"].exists)
        XCTAssertTrue(app.staticTexts["Coffee"].exists)
        XCTAssertTrue(app.staticTexts["1 cup"].exists)
        if !app.staticTexts["Coffee"].isHittable { app.scrollViews["historyItems"].swipeUp() }
        XCTAssertTrue(app.staticTexts["Coffee"].isHittable)
        capture("custom-history")
        tap("closeReview")
        tap("customSettings"); tap("deleteCustom"); app.buttons["削除する"].tap()
        XCTAssertTrue(app.staticTexts["追加項目なし"].waitForExistence(timeout: 5))
        tap("closeCustom")
        tap("review"); app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["Coffee"].exists, "Deleting a question preserves its historical answers")
        tap("closeReview")
        app.terminate(); app.launch()
        for _ in 0..<24 { if app.buttons["save"].exists { break }; tap("skip") }
        XCTAssertTrue(app.buttons["voice"].waitForExistence(timeout: 5), "Hidden custom question must be omitted")
    }
}

extension MoodLogUITests {
    @MainActor func testUnifiedTimelineAndFastSkip() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        func tap(_ id: String) {
            if id.hasPrefix("choice_clock"), let minutes = Int(id.dropFirst("choice_clock".count)) {
                let bedtime = app.staticTexts["question"].label.contains("寝た")
                let normal = bedtime ? "18:00〜翌5:30" : "3:00〜14:30"
                let inNormal = bedtime ? (minutes >= 1080 || minutes < 360) : (minutes >= 180 && minutes < 900)
                if (app.staticTexts["clockWindow"].label == normal) != inNormal { app.buttons["clockWindowToggle"].tap() }
                let angle = Double(minutes % 720) / 720 * .pi * 2 - .pi / 2
                app.otherElements["clockDial"].coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)).tap()
                return
            }
            let button = app.buttons[id]
            if !button.exists { XCTAssertTrue(button.waitForExistence(timeout: 5), id) }
            button.tap()
        }
        for i in 0..<8 {
            tap("choice_mood\(1 + i % 5)")
            if i == 3 { tap("skip") } else { tap("choice_energy\(1 + (i + 2) % 5)") }
            tap("choice_hunger\(1 + i % 5)")
            tap("choice_clock1410"); tap(i % 2 == 0 ? "choice_clock420" : "choice_clock360")
            if i > 0 { XCTAssertTrue(app.staticTexts["carryPreview"].exists) }
            tap(i % 2 == 0 ? "nutrition_today_1" : "nutrition_yesterday_2")
            tap("nutrition_yesterday_1")
            selectDateRange(app, offset: i % 2 == 0 ? 0 : -3)
            tap("choice_inProgress"); tap("choice_backlog2"); tap("conversation_today_1")
            tap(i % 2 == 0 ? "eventNone" : "event_yesterday_1")
            tap("pleasant_today_1")
            for _ in 0..<3 { tap("skip") }
            XCTAssertEqual(app.textViews.count, 0)
            tap("save")
        }
        tap("review")
        XCTAssertTrue(app.staticTexts["直近7回の記録"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["気分"].exists)
        XCTAssertTrue(app.staticTexts["気力"].exists)
        XCTAssertTrue(app.staticTexts["睡眠"].exists)
        XCTAssertTrue(app.staticTexts["つらい出来事"].exists)
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = "unified-timeline"; a.lifetime = .keepAlways; add(a)
        let cell = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline_builtin-2_")).firstMatch
        XCTAssertTrue(cell.isHittable); cell.tap()
        XCTAssertTrue(app.staticTexts["timelineDetail"].exists || app.otherElements["timelineDetail"].exists)
        tap("olderChart")
        XCTAssertTrue(app.staticTexts["過去の1回の記録"].exists)
        tap("newerChart"); tap("closeReview")
        let skip = app.buttons["skip"]
        for _ in 0..<16 { skip.tap() }
        XCTAssertTrue(app.buttons["save"].exists)
        for _ in 0..<4 { tap("back") }
        XCTAssertTrue(app.buttons["pleasantNone"].exists)
        let b = XCTAttachment(screenshot: app.screenshot()); b.name = "icon-progress"; b.lifetime = .keepAlways; add(b)
    }

    @MainActor func testDeviceQuickRecord() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        XCTAssertTrue(app.buttons["choice_mood4"].waitForExistence(timeout: 10))
        app.buttons["choice_mood4"].tap()
        app.buttons["choice_energy3"].tap()
        XCTAssertTrue(app.buttons["choice_hunger1"].isHittable)
        XCTAssertTrue(app.buttons["choice_hunger5"].isHittable)
        let hunger = XCTAttachment(screenshot: app.screenshot()); hunger.name = "device-hunger"; hunger.lifetime = .keepAlways; add(hunger)
        app.buttons["choice_hunger5"].tap()
        app.buttons["back"].tap()
        app.buttons["choice_hunger2"].tap()
        for _ in 0..<8 { app.buttons["skip"].tap() }
        XCTAssertTrue(app.buttons["event_older_2"].isHittable)
        let negative = XCTAttachment(screenshot: app.screenshot()); negative.name = "device-salient-difficult"; negative.lifetime = .keepAlways; add(negative)
        app.buttons["event_older_2"].tap()
        XCTAssertTrue(app.buttons["pleasant_older_2"].isHittable)
        let positive = XCTAttachment(screenshot: app.screenshot()); positive.name = "device-salient-pleasant"; positive.lifetime = .keepAlways; add(positive)
        app.buttons["pleasant_today_1"].tap()
        for _ in 0..<3 { app.buttons["skip"].tap() }
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["keyboardMemo"].exists)
        XCTAssertEqual(app.textViews.count, 0)
        for _ in 0..<4 { app.buttons["back"].tap() }
        XCTAssertTrue(app.buttons["pleasant_older_2"].isHittable)
        app.buttons["pleasant_yesterday_2"].tap()
        for _ in 0..<3 { app.buttons["skip"].tap() }
        app.buttons["save"].tap()
        app.buttons["review"].tap()
        XCTAssertTrue(app.staticTexts["直近1回の記録"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "device-timeline"; shot.lifetime = .keepAlways; add(shot)
        app.segmentedControls["reviewTabs"].buttons["比較"].tap()
        app.buttons["factorMenu"].tap(); app.buttons["空腹"].tap()
        XCTAssertTrue(app.staticTexts["空腹と気力"].exists)
        XCTAssertTrue(app.staticTexts["とても空腹"].isHittable)
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["少し空腹"].exists)
        XCTAssertFalse(app.buttons["historyNextPage"].exists)
        XCTAssertTrue(app.staticTexts["もっと前・とてもつらかった"].exists)
        XCTAssertTrue(app.staticTexts["昨日・とても楽しかった"].exists)
        app.buttons["closeReview"].tap()
    }
}


extension MoodLogUITests {
    @MainActor private func selectDateRange(_ app: XCUIApplication, offset: Int) {
        let id: String
        switch offset {
        case 0: id = "today"
        case 1: id = "tomorrow"
        case -1: id = "yesterday"
        case -2, 2: id = "two"
        case -6 ... -3, 3...6: id = "threeToSix"
        case -14 ... -7, 7...14: id = "weekToTwo"
        default: id = "older"
        }
        XCTAssertTrue(app.buttons["range_\(id)"].isHittable)
        app.buttons["range_\(id)"].tap()
    }
}


extension MoodLogUITests {
    @MainActor func testClockDialCenterAndMidnight() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        for _ in 0..<3 { app.buttons["skip"].tap() }
        let dial = app.otherElements["clockDial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        let center = dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()
        XCTAssertTrue(app.staticTexts["question"].label.contains("寝た"), "A tap at the pivot does not choose an arbitrary hour")
        let angle = Double(23) * Double.pi / 12 - Double.pi / 2
        center.press(forDuration: 0.1, thenDragTo: dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)))
        XCTAssertTrue(app.staticTexts["question"].label.contains("起きた"), "Dragging from the pivot can move the hand")
        app.buttons["back"].tap()
        XCTAssertEqual(app.staticTexts["clockTime"].label, "23:30")
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "18:00〜翌5:30")
        let half = Double.pi / 12 - Double.pi / 2
        dial.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(half) * 0.415, dy: 0.5 + sin(half) * 0.415)).tap()
        app.buttons["back"].tap()
        XCTAssertEqual(app.staticTexts["clockTime"].label, "0:30")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "clock-midnight-half"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["noSleep"].tap()
        XCTAssertTrue(app.buttons["nutrition_today_0"].waitForExistence(timeout: 5))
    }
}


extension MoodLogUITests {
    @MainActor func testClockWindowRanges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        for _ in 0..<3 { app.buttons["skip"].tap() }
        func select(_ hour: Double) {
            let angle = hour / 12 * .pi * 2 - .pi / 2
            app.otherElements["clockDial"].coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)).tap()
        }
        for (hour, label) in [(11.0, "23:00"), (0.0, "0:00"), (1.0, "1:00")] {
            XCTAssertEqual(app.staticTexts["clockWindow"].label, "18:00〜翌5:30")
            select(hour); app.buttons["back"].tap()
            XCTAssertEqual(app.staticTexts["clockTime"].label, label)
        }
        app.buttons["clockWindowToggle"].tap()
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "6:00〜17:30")
        select(2)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "14:00に寝た")).firstMatch.exists, "Daytime sleep remains selectable explicitly")
        app.buttons["back"].tap()
        XCTAssertEqual(app.staticTexts["clockTime"].label, "23:00")
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "18:00〜翌5:30", "A daytime draft must not make bedtime open in the daytime window")
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.staticTexts["clockWindow"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "18:00〜翌5:30")
        XCTAssertEqual(app.staticTexts["clockTime"].label, "23:00")
        let bedtimeShot = XCTAttachment(screenshot: app.screenshot()); bedtimeShot.name = "bedtime-night-after-daytime-draft"; bedtimeShot.lifetime = .keepAlways; add(bedtimeShot)
        select(11.5)
        for (hour, label) in [(5.0, "5:00"), (6.0, "6:00"), (0.0, "12:00"), (1.0, "13:00")] {
            XCTAssertEqual(app.staticTexts["clockWindow"].label, "3:00〜14:30")
            select(hour); app.buttons["back"].tap()
            XCTAssertEqual(app.staticTexts["clockTime"].label, label)
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "wake-window-noon"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["clockWindowToggle"].tap()
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "15:00〜翌2:30")
        select(3); app.buttons["back"].tap()
        XCTAssertEqual(app.staticTexts["clockTime"].label, "15:00")
        XCTAssertEqual(app.staticTexts["clockWindow"].label, "15:00〜翌2:30")
    }
}

extension MoodLogUITests {
    @MainActor func testReviewEditingAndComparison() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        XCTAssertLessThan(app.buttons["choice_mood5"].frame.minY, app.buttons["choice_mood1"].frame.minY)
        app.buttons["choice_mood5"].tap()
        XCTAssertLessThan(app.buttons["choice_energy5"].frame.minY, app.buttons["choice_energy1"].frame.minY)
        app.buttons["choice_energy5"].tap()
        app.buttons["choice_hunger4"].tap()
        while !app.buttons["save"].exists {
            if app.buttons["choice_backlog4"].exists { app.buttons["choice_backlog4"].tap() }
            else if app.buttons["event_yesterday_2"].exists { app.buttons["event_yesterday_2"].tap() }
            else if app.buttons["pleasant_today_2"].exists { app.buttons["pleasant_today_2"].tap() }
            else { app.buttons["skip"].tap() }
        }
        app.buttons["save"].tap()
        app.buttons["review"].tap()
        let tabs = app.segmentedControls["reviewTabs"]
        tabs.buttons["記録"].tap()
        let originalDate = app.staticTexts["historyDate"].label
        app.buttons["editRecord"].tap()
        XCTAssertTrue(app.buttons["editChoice_mood1"].waitForExistence(timeout: 5))
        app.buttons["editChoice_mood1"].tap()
        app.buttons["editCancel"].tap()
        XCTAssertTrue(app.staticTexts["良い"].waitForExistence(timeout: 5), "Cancel must not change the saved record")
        app.buttons["editRecord"].tap()
        app.buttons["editChoice_mood2"].tap()
        app.buttons["editSave"].tap()
        XCTAssertTrue(app.staticTexts["やや悪い"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["historyDate"].label, originalDate)
        XCTAssertTrue(app.staticTexts["1 / 1件"].exists, "Editing does not create another record")
        tabs.buttons["グラフ"].tap()
        let iron = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline_builtin-3_")).firstMatch
        XCTAssertTrue(iron.waitForExistence(timeout: 5)); iron.tap()
        app.buttons["timelineEdit"].tap()
        XCTAssertTrue(app.buttons["nutrition_yesterday_2"].waitForExistence(timeout: 5), "Editing a selected cell opens its question")
        app.buttons["nutrition_yesterday_2"].tap()
        app.buttons["editSave"].tap()
        let trendShot = XCTAttachment(screenshot: app.screenshot()); trendShot.name = "timeline-answer-tones"; trendShot.lifetime = .keepAlways; add(trendShot)
        tabs.buttons["比較"].tap()
        app.buttons["factorMenu"].tap()
        app.buttons["鉄分"].tap()
        XCTAssertTrue(app.segmentedControls["comparisonAmount"].waitForExistence(timeout: 5))
        app.segmentedControls["comparisonAmount"].buttons["多め"].tap()
        XCTAssertTrue(app.otherElements["comparisonGraph"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "comparison-mood-energy-amount"; shot.lifetime = .keepAlways; add(shot)
        tabs.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["昨日・多め"].exists)
        let historyShot = XCTAttachment(screenshot: app.screenshot()); historyShot.name = "edited-history"; historyShot.lifetime = .keepAlways; add(historyShot)
        app.buttons["closeReview"].tap()
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        app.buttons["review"].tap(); app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["やや悪い"].exists)
        XCTAssertTrue(app.staticTexts["昨日・多め"].exists)
        XCTAssertEqual(app.staticTexts["historyDate"].label, originalDate)
        XCTAssertTrue(app.staticTexts["1 / 1件"].exists)
    }
}

extension MoodLogUITests {
    @MainActor func testConcreteCarryAndFirstQuestion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launch()
        func tap(_ id: String) { XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5)); app.buttons[id].tap() }
        func clock(_ hour: Double) {
            let angle = hour / 12 * .pi * 2 - .pi / 2
            app.otherElements["clockDial"].coordinate(withNormalizedOffset: CGVector(dx: 0.5 + cos(angle) * 0.415, dy: 0.5 + sin(angle) * 0.415)).tap()
        }
        XCTAssertFalse(app.buttons["firstQuestion"].isEnabled)
        tap("choice_mood4"); tap("choice_energy3"); tap("choice_hunger2")
        clock(11.5); clock(7)
        tap("nutrition_today_2")
        tap("firstQuestion")
        XCTAssertTrue(app.staticTexts["question"].label.contains("気分"))
        XCTAssertTrue(app.buttons["clearAnswer"].isEnabled, "Returning to the first question retains its answer")
        XCTAssertFalse(app.buttons["firstQuestion"].isEnabled)
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.staticTexts["question"].label.contains("気分"), "The first-question position persists after relaunch")
        tap("choice_mood4"); tap("choice_energy3"); tap("choice_hunger2")
        XCTAssertEqual(app.staticTexts["clockTime"].label, "23:30", "The sleep answer survives returning to the first question")
        clock(11.5); clock(7); tap("nutrition_today_2")
        while !app.buttons["save"].exists {
            if app.buttons["choice_backlog2"].exists { tap("choice_backlog2") }
            else if app.buttons["event_today_2"].exists { tap("event_today_2") }
            else if app.buttons["pleasant_today_0"].exists { tap("pleasant_today_0") }
            else { tap("skip") }
        }
        tap("save")
        tap("choice_mood2"); tap("choice_energy4"); tap("choice_hunger4"); tap("skip"); tap("skip")
        XCTAssertTrue(app.buttons["skip"].label.contains("今日・多め"))
        XCTAssertTrue(app.buttons["skip"].label.contains("を使って次へ"))
        XCTAssertTrue(app.buttons["skip"].isHittable)
        Thread.sleep(forTimeInterval: 1)
        let carry = XCTAttachment(screenshot: app.screenshot()); carry.name = "concrete-carry-button"; carry.lifetime = .keepAlways; add(carry)
        tap("skip")
        while !app.buttons["save"].exists {
            if app.buttons["choice_backlog4"].exists { tap("choice_backlog4") }
            else if app.buttons["event_today_0"].exists { tap("event_today_0") }
            else if app.buttons["pleasant_today_2"].exists { tap("pleasant_today_2") }
            else { tap("skip") }
        }
        tap("firstQuestion")
        XCTAssertTrue(app.staticTexts["question"].label.contains("気分"), "The final save screen can return to the first question")
        tap("choice_mood2")
        while !app.buttons["save"].exists {
            if app.buttons["choice_energy4"].exists { tap("choice_energy4") }
            else if app.buttons["choice_hunger4"].exists { tap("choice_hunger4") }
            else if app.buttons["choice_backlog4"].exists { tap("choice_backlog4") }
            else if app.buttons["event_today_0"].exists { tap("event_today_0") }
            else if app.buttons["pleasant_today_2"].exists { tap("pleasant_today_2") }
            else { tap("skip") }
        }
        tap("save"); tap("review")
        XCTAssertTrue(app.staticTexts["timelineShadeLegend"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let shade = XCTAttachment(screenshot: app.screenshot()); shade.name = "single-hue-answer-shades"; shade.lifetime = .keepAlways; add(shade)
        let eventCells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline_builtin-13_"))
        XCTAssertEqual(eventCells.count, 2)
        for cell in eventCells.allElementsBoundByIndex {
            XCTAssertFalse(cell.label.hasPrefix("+")); XCTAssertFalse(cell.label.hasPrefix("−"))
        }
        app.segmentedControls["reviewTabs"].buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["今日・多め（引継ぎ）"].exists, "The concrete carry button saves the displayed answer")
    }
}
