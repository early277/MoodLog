import Foundation

@main struct ModelTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MoodLogTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = DiskRepository(url: directory.appendingPathComponent("records.json"))
        let initial = try repo.read()
        precondition(initial.isEmpty)
        var first = LogRecord()
        first[.iron] = Choices.nutrition(day: Choices.recency[1], amount: 2)
        first[.b12] = Choices.nutrition(day: Choices.recency[0], amount: 1)
        first[.energy] = Answer(Choice("energy2", "少ない", 2))
        first[.sleep] = Answer(Choice("sleep15", "7.5h", 7.5))
        first.note = "改行\n日本語・音声メモ"
        try repo.write([first])
        let loaded = try repo.read()
        precondition(loaded == [first], "Round-trip must preserve independent nutrient amount and recency")
        precondition(loaded[0][.iron]?.amount == 2 && loaded[0][.iron]?.dayRange == DayRange(lower: 1, upper: 1))
        var second = first; second.id = UUID(); second[.energy] = Answer(Choice("energy4", "ある", 4))
        var third = first; third.id = UUID(); third.date = Calendar.current.date(byAdding: .day, value: 1, to: first.date)!
        third[.energy] = Answer(Choice("energy5", "十分ある", 5))
        let summary = Statistics.summary([first, second, third], outcome: .energy, factor: .sleep, recent: true)
        precondition(summary.days == 2 && summary.mean == 4, "Daily means must prevent repeated logs from dominating")
        third[.sleep] = nil
        precondition(Statistics.summary([third], outcome: .energy, factor: .sleep, recent: false).days == 0, "Missing answers must not be counted as zero")
        third[.sleep] = Answer(Choice("over12", "12h超"))
        precondition(Statistics.summary([third], outcome: .energy, factor: .sleep, recent: true).days == 1, "Open-ended sleep category is still known to exceed 7h")
        try Data("broken".utf8).write(to: repo.url)
        do { _ = try repo.read(); fatalError("Corrupt file must throw") } catch {}
        precondition(Choices.forQuestion(.sleepStart).count == 48)
        precondition(Choices.forQuestion(.sleepEnd).last?.label == "23:30")
        precondition(Choices.recency.count * Choices.amounts.count == 18)
        precondition(Question.flow.count == 18 && !Question.flow.contains(.sleep))
        precondition(Question.restoredStep(3, version: 0) == 5)
        precondition(Question.restoredStep(9, version: 0) == 17)
        precondition(Question.restoredStep(2, version: 0) == 3)
        precondition(Question.restoredStep(3, version: 2) == 4)
        precondition(Question.iron.rawValue == 3 && Question.conversation.rawValue == 8)
        precondition(SleepClock.duration(start: 1410, end: 420) == 450)
        precondition(SleepClock.duration(start: 540, end: 1020) == 480)
        precondition(SleepClock.duration(start: 0, end: 30) == 30)
        precondition(SleepClock.duration(start: 420, end: 420) == nil)
        precondition(SleepClock.duration(start: -1, end: 420) == nil)
        var clockRecord = LogRecord()
        precondition(clockRecord.setSleep(Answer(Choice("clock1410", "23:30", 1410)), for: .sleepStart))
        precondition(clockRecord.setSleep(Answer(Choice("clock420", "7:00", 420)), for: .sleepEnd))
        precondition(clockRecord[.sleep]?.value == 7.5)
        precondition(clockRecord.sleepHistoryLabel == "23:30→7:00（7時間30分）")
        try repo.write([clockRecord]); let clockLoaded = try repo.read()
        precondition(clockLoaded == [clockRecord])
        precondition(!clockRecord.setSleep(Answer(Choice("clock1410", "23:30", 1410)), for: .sleepEnd))
        precondition(clockRecord[.sleep]?.value == 7.5, "Rejected input must not overwrite a valid interval")
        precondition(clockRecord.setSleep(nil, for: .sleepStart))
        precondition(clockRecord[.sleep] == nil && clockRecord[.sleepEnd] == nil)
        precondition(clockRecord.setSleep(Answer(Choice("clock420", "7:00", 420)), for: .sleepEnd))
        precondition(clockRecord[.sleep] == nil && clockRecord.sleepHistoryLabel == "—→7:00")
        precondition(clockRecord.setSleep(Answer(Choice("noSleep", "寝ていない")), for: .sleepStart))
        precondition(clockRecord[.sleep]?.value == 0 && clockRecord[.sleepEnd] == nil)

        let oldJSON = #"{"id":"00000000-0000-0000-0000-000000000001","date":1000,"answers":{"2":{"code":"sleep15","label":"7.5h","value":7.5},"3":{"code":"yesterday_1","label":"昨日・1食分","value":1,"amount":1},"8":{"code":"no","label":"話していない","value":0}},"note":"以前の記録"}"#
        var oldRecord = try JSONDecoder().decode(LogRecord.self, from: Data(oldJSON.utf8))
        precondition(oldRecord[.sleep]?.value == 7.5 && oldRecord[.iron]?.amount == 1)
        precondition(oldRecord[.conversation]?.code == "no" && oldRecord.note == "以前の記録")
        oldRecord[.energy] = Answer(Choice("energy3", "普通", 3))
        precondition(Statistics.summary([oldRecord], outcome: .energy, factor: .conversation, recent: false).days == 0)
        oldRecord[.conversation] = Answer(Choice("yes", "話した", 1))
        precondition(Statistics.summary([oldRecord], outcome: .energy, factor: .conversation, recent: true).days == 1)
        oldRecord[.conversation] = Answer(Choices.recency[1])
        precondition(Statistics.summary([oldRecord], outcome: .energy, factor: .conversation, recent: true).days == 1)
        oldRecord[.conversation] = Answer(Choices.recency[2])
        precondition(Statistics.summary([oldRecord], outcome: .energy, factor: .conversation, recent: false).days == 1)
        precondition(Question.restoredStep(10, version: 2) == 17)
        precondition(Question.difficultEvent.rawValue == 12)
        let custom = CustomItem(title: "最後に外出したのは？", kind: .recency)
        var customRecord = LogRecord()
        customRecord.customAnswers = [custom.id.uuidString: CustomResponse(item: custom, answer: Answer(Choices.recency[1]))]
        customRecord[.energy] = Answer(Choice("energy2", "少ない", 2))
        customRecord[.difficultEvent] = Choices.event(day: Choices.recency[0], intensity: 2)
        customRecord.note = "今日はコーヒーを飲んだ。\n30分散歩した。"
        customRecord.noteUsesHiragana = true
        try repo.write([customRecord])
        let customLoaded = try repo.read()
        precondition(customLoaded == [customRecord])
        precondition(customLoaded[0].customAnswers?[custom.id.uuidString]?.item.title == custom.title)
        precondition(oldRecord.customAnswers == nil && oldRecord.noteUsesHiragana == nil)
        let group = Statistics.customSummary([customRecord], outcome: .energy, item: custom)[1]
        precondition(group.days == 1 && group.mean == 2)
        precondition(Statistics.customSummary([oldRecord], outcome: .energy, item: custom).allSatisfy { $0.days == 0 })
        precondition(CustomItem.validation(title: " ", kind: .recency, options: []) != nil)
        precondition(CustomItem.validation(title: "量", kind: .options, options: ["なし", "なし"]) != nil)
        precondition(CustomItem.validation(title: "量", kind: .options, options: ["なし", "あり"]) == nil)
        precondition(NoteText.hiragana("今日は散歩した。") == "きょうはさんぽした。")
        precondition(NoteText.hiragana("コーヒー\n30分 ABC ☕️").contains("こーひー\n30"))
        precondition(NoteText.hiragana("ABC 123\n☕️") == "ABC 123\n☕️")
        precondition(customRecord.note.contains("今日は"), "Display conversion must retain original text")
        precondition(NoteText.hiragana("帰省と規制") == "きせいときせい")
        var repeated = customRecord; repeated.id = UUID(); repeated[.energy] = Answer(Choice("energy4", "ある", 4))
        var tomorrow = customRecord; tomorrow.id = UUID(); tomorrow.date = Calendar.current.date(byAdding: .day, value: 1, to: customRecord.date)!
        tomorrow[.energy] = Answer(Choice("energy5", "十分ある", 5))
        let dailyCustom = Statistics.customSummary([customRecord, repeated, tomorrow], outcome: .energy, item: custom)[1]
        precondition(dailyCustom.days == 2 && dailyCustom.mean == 4)
        var noEvent = customRecord; noEvent[.difficultEvent] = Answer(Choice("none", "特にない"))
        precondition(Statistics.summary([noEvent], outcome: .energy, factor: .difficultEvent, recent: false).days == 1)
        precondition(CustomItem(title: "程度", kind: .scale).choices.count == 5)
        precondition(CustomItem(title: "有無", kind: .yesNo).choices.map(\.value) == [1, 0])
        precondition(Question.restoredStep(10, version: 3) == 12)
        precondition(Question.restoredStep(11, version: 3) == 17)
        precondition(!Question.flow.contains(.difficultEvent))
        precondition(customRecord[.salientDifficultEvent] == nil, "Legacy last event is not a salient event")
        precondition(Statistics.summary([customRecord], outcome: .energy, factor: .salientDifficultEvent, recent: true).days == 0)
        var salient = customRecord
        salient[.salientDifficultEvent] = Choices.event(day: Choices.recency[5], intensity: 2)
        salient[.pleasantEvent] = Choices.event(day: Choices.recency[1], intensity: 1, pleasant: true)
        try repo.write([salient])
        let salientLoaded = try repo.read()
        precondition(salientLoaded == [salient])
        precondition(salient[.pleasantEvent]?.label == "昨日・かなり楽しかった")
        precondition(Statistics.summary([salient], outcome: .energy, factor: .salientDifficultEvent, recent: false).days == 1)
        precondition(Statistics.summary([salient], outcome: .energy, factor: .pleasantEvent, recent: true).days == 1)
        precondition(TimelineModel.rows(customItems: [], records: [LogRecord()]).count == 11)
        let rows = TimelineModel.rows(customItems: [], records: [customRecord])
        precondition(rows.count == 12 && rows.last?.customID == custom.id)
        precondition(!rows.contains { $0.question == .difficultEvent }, "The legacy last difficult event is hidden from review")
        precondition(rows.contains { $0.question == .salientDifficultEvent }, "The currently salient difficult event stays available")
        let ironRow = rows.first { $0.question == .iron }!
        precondition(ironRow.compactLabel(in: customRecord) == "—", "Historical records are not retroactively filled")
        precondition(ironRow.compactLabel(in: first) == "昨日\n多め")
        precondition(rows.first { $0.question == .sleep }!.compactLabel(in: first) == "7.5h")
        var future = LogRecord(); future[.nextWork] = Answer(Choice("two", "2日後", 2))
        precondition(TimelineModel.rows(customItems: [], records: [future]).first { $0.question == .nextWork }!.compactLabel(in: future) == "2日後")
        let sequence = (0..<9).map { index -> LogRecord in
            var r = LogRecord(); r.date = Date(timeIntervalSince1970: Double(index * 60)); return r
        }
        precondition(TimelineModel.window(sequence, page: 0).map(\.date) == Array(sequence.suffix(7)).map(\.date))
        precondition(TimelineModel.window(sequence, page: 1).map(\.date) == Array(sequence.prefix(2)).map(\.date))
        precondition(Question.hunger.rawValue == 15 && Question.flow[2] == .hunger)
        precondition(Question.restoredStep(2, version: 4) == 3)
        precondition(Question.restoredStep(2, version: 5) == 2)
        precondition(oldRecord[.hunger] == nil)
        let hungerChoices = Choices.forQuestion(.hunger)
        first[.hunger] = Answer(hungerChoices[4]); second[.hunger] = Answer(hungerChoices[4]); third[.hunger] = Answer(hungerChoices[4])
        let hungry = Statistics.choiceSummary([first, second, third, oldRecord], outcome: .energy, factor: .hunger)
        precondition(hungry.count == 5 && hungry[4].days == 2 && hungry[4].mean == 4)
        precondition(hungry[0].days == 0 && hungry[0].mean == nil, "Missing hunger is not no hunger")
        second[.hunger] = Answer(hungerChoices[0])
        try repo.write([first, second]); let hungerLoaded = try repo.read()
        precondition(hungerLoaded[0][.hunger]?.value == 5 && hungerLoaded[1][.hunger]?.value == 1)
        precondition(rows.first { $0.question == .hunger }!.compactLabel(in: second) == "なし")
        var dateCalendar = Calendar(identifier: .gregorian)
        dateCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let march8 = CalendarSelection.date("2026-03-08", calendar: dateCalendar)!
        let march9 = CalendarSelection.date("2026-03-09", calendar: dateCalendar)!
        precondition(march9.timeIntervalSince(march8) == 23 * 3600)
        let dayAnswer = CalendarSelection.answer(march8, now: march9, future: false, calendar: dateCalendar)!
        precondition(dayAnswer.value == 1 && dayAnswer.calendarDate == "2026-03-08", "Days are calendar days across DST")
        precondition(CalendarSelection.answer(march9, now: march8, future: false, calendar: dateCalendar) == nil)
        precondition(CalendarSelection.answer(march8, now: march9, future: true, calendar: dateCalendar) == nil)
        precondition(CalendarSelection.date("2026-02-30", calendar: dateCalendar) == nil)
        let leap = CalendarSelection.date("2024-02-01", calendar: dateCalendar)!
        precondition(CalendarSelection.cells(leap, calendar: dateCalendar).compactMap { $0 }.count == 29)
        let sixWeeks = CalendarSelection.date("2026-05-01", calendar: dateCalendar)!
        let cells = CalendarSelection.cells(sixWeeks, calendar: dateCalendar)
        precondition(cells.count == 42 && cells[4] == nil && cells[5] != nil && cells[35] != nil)
        var dated = LogRecord(); dated[.exercise] = dayAnswer
        dated[.nextWork] = CalendarSelection.answer(march9, now: march8, future: true, calendar: dateCalendar)
        try repo.write([dated]); let datedLoaded = try repo.read()
        precondition(datedLoaded == [dated] && oldRecord[.conversation]?.calendarDate == nil)
        precondition(dated.refreshCalendarAnswers(at: march9, calendar: dateCalendar))
        precondition(dated[.exercise]?.value == 1 && dated[.nextWork]?.value == 0)
        let priorDateRecord = dated
        let march10 = CalendarSelection.date("2026-03-10", calendar: dateCalendar)!
        precondition(!dated.refreshCalendarAnswers(at: march10, calendar: dateCalendar))
        precondition(dated == priorDateRecord, "Invalid date refresh must not partially modify a draft")
        dated[.nextWork] = nil
        precondition(dated.refreshCalendarAnswers(at: march10, calendar: dateCalendar) && dated[.exercise]?.value == 2)
        let hours = (0..<3).flatMap { ClockPeriods.hours($0) }
        precondition(hours.sorted() == Array(0..<24) && Set(hours).count == 24)
        precondition(ClockPeriods.period(for: 23 * 60) == ClockPeriods.period(for: 30))
        precondition(ClockPeriods.period(for: 5 * 60) == ClockPeriods.period(for: 6 * 60))
        for minute in stride(from: 0, to: 1440, by: 30) {
            precondition(ClockPeriods.hours(ClockPeriods.period(for: minute)).contains(minute / 60))
        }
        let october = CalendarSelection.date("2026-10-01", calendar: dateCalendar)!
        let approximate = ApproximateDates.choices(future: false)[3].answer(on: october, calendar: dateCalendar)
        precondition(approximate.dayRange == DayRange(lower: 3, upper: 6) && approximate.value == nil && approximate.calendarDate == nil)
        var rough = LogRecord(); rough[.energy] = Answer(Choice("energy3", "普通", 3)); rough[.exercise] = approximate
        try repo.write([rough]); let roughLoaded = try repo.read()
        precondition(roughLoaded == [rough])
        precondition(Statistics.summary([rough], outcome: .energy, factor: .exercise, recent: false).days == 1)
        rough[.exercise]!.dayRange = DayRange(lower: 1, upper: 4)
        precondition(Statistics.summary([rough], outcome: .energy, factor: .exercise, recent: true).days == 0)
        precondition(Statistics.summary([rough], outcome: .energy, factor: .exercise, recent: false).days == 0, "Ranges spanning the boundary are not assigned an invented midpoint")
        let oldRange = ApproximateDates.choices(future: false)[5].answer(on: october, calendar: dateCalendar)
        rough[.exercise] = oldRange
        precondition(Statistics.summary([rough], outcome: .energy, factor: .exercise, recent: false).days == 1)
        let nextDay = dateCalendar.date(byAdding: .day, value: 1, to: october)!
        precondition(ApproximateDates.refreshed(approximate, now: nextDay, future: false, calendar: dateCalendar)?.dayRange == DayRange(lower: 4, upper: 7))
        let tomorrowRange = ApproximateDates.choices(future: true)[1].answer(on: october, calendar: dateCalendar)
        precondition(ApproximateDates.refreshed(tomorrowRange, now: nextDay, future: true, calendar: dateCalendar)?.dayRange == DayRange(lower: 0, upper: 0))
        precondition(ApproximateDates.refreshed(ApproximateDates.choices(future: true)[0].answer(on: october, calendar: dateCalendar), now: nextDay, future: true, calendar: dateCalendar) == nil)
        let visible = ApproximateDates.visibleDates(now: october, future: false, calendar: dateCalendar)
        precondition(visible.count == 21 && visible.contains(october))
        precondition(visible.contains { CalendarSelection.key($0, calendar: dateCalendar) == "2026-09-30" })
        precondition(ApproximateDates.choices(future: false)[3].dateLabel(on: october, future: false, calendar: dateCalendar) == "9/25〜9/28")
        for (days, group) in [(0, 0), (1, 1), (2, 2), (3, 3), (6, 3), (7, 4), (14, 4), (15, 5), (100, 5)] {
            let date = dateCalendar.date(byAdding: .day, value: -days, to: october)!
            precondition(ApproximateDates.group(for: date, now: october, future: false, calendar: dateCalendar) == group)
        }
        // Carry-forward is based on calendar days and preserves quantities and provenance.
        precondition(Choices.recency.map(\.label) == ["今日", "昨日", "2日前", "3〜6日前", "1〜2週間前", "もっと前"])
        var prior = LogRecord(); prior.date = october
        prior[.iron] = Answer(Choice("yesterday_2", "昨日・多め", 1), amount: 2) // legacy answer
        prior[.b12] = Choices.matrix(day: Choices.recency[0], amount: 1, suffix: "1食分", on: october)
        prior[.exercise] = approximate
        prior[.nextObligation] = tomorrowRange
        prior[.lastWork] = Answer(Choice("working", "勤務中", 0))
        prior[.conversation] = Choices.conversation(day: Choices.recency[1], amount: 2, on: october)
        prior[.salientDifficultEvent] = Choices.matrix(day: Choices.recency[0], amount: 2, suffix: "とてもつらかった", on: october)
        prior[.energy] = Answer(Choice("energy4", "ある", 4))
        prior[.hunger] = Answer(Choice("hunger2", "少し空腹", 2))
        prior[.sleep] = Answer(Choice("sleep7", "7時間", 7))
        prior.customAnswers = [custom.id.uuidString: CustomResponse(item: custom, answer: approximate)]
        var blank = LogRecord(); blank.date = nextDay
        let carried = AnswerCarryForward.filling(blank, from: [prior], customItems: [custom], calendar: dateCalendar)
        precondition(carried[.iron]?.label == "2日前・多め" && carried[.iron]?.amount == 2)
        precondition(carried[.iron]?.inheritedFrom == prior.id && carried[.iron]?.value == nil)
        precondition(carried[.exercise]?.dayRange == DayRange(lower: 4, upper: 7))
        precondition(carried[.conversation]?.label == "2日前・長時間")
        precondition(carried[.b12]?.label == "昨日・1食分")
        precondition(carried[.salientDifficultEvent]?.label == "昨日・とてもつらかった")
        precondition(carried[.nextObligation]?.label == "今日")
        precondition(carried[.lastWork] == nil && carried[.energy] == nil && carried[.hunger] == nil && carried[.sleep] == nil)
        precondition(carried.customAnswers?[custom.id.uuidString]?.answer.dayRange == DayRange(lower: 4, upper: 7))
        try repo.write([carried, prior]); let carryLoaded = try repo.read()
        precondition(carryLoaded == [carried, prior])
        let dayAfter = dateCalendar.date(byAdding: .day, value: 2, to: october)!
        blank.date = dayAfter
        let twice = AnswerCarryForward.filling(blank, from: [prior, carried], calendar: dateCalendar)
        precondition(twice[.iron]?.label == "3日前・多め" && twice[.iron]?.inheritedFrom == prior.id)
        precondition(twice[.nextObligation] == nil, "Expired plans are not assumed completed")
        precondition(twice[.exercise]?.dayRange == DayRange(lower: 5, upper: 8), "Repeated carry must not widen or round ranges")
        blank[.iron] = Choices.matrix(day: Choices.recency[0], amount: 0, suffix: "少し", on: dayAfter)
        let overridden = AnswerCarryForward.filling(blank, from: [carried], calendar: dateCalendar)
        precondition(overridden[.iron] == blank[.iron] && overridden[.iron]?.inheritedFrom == nil)
        var barrier = prior; barrier.id = UUID(); barrier.date = nextDay
        barrier[.salientDifficultEvent] = Answer(Choice("none", "特にない"))
        precondition(AnswerCarryForward.answer(for: .salientDifficultEvent, records: [prior, barrier], now: dayAfter, calendar: dateCalendar) == nil)
        precondition(AnswerCarryForward.answer(for: .iron, records: [prior], now: march9, calendar: dateCalendar) == nil)
        let openLegacy = Answer(Choice("weekPlus_1", "1週間以上前・1食分", 7), amount: 1)
        precondition(AnswerCarryForward.normalized(openLegacy, recordedAt: october, now: nextDay, calendar: dateCalendar)?.dayRange == DayRange(lower: 8, upper: nil))
        let dstCarry = AnswerCarryForward.normalized(Answer(Choice("yesterday_2", "昨日・多め", 1), amount: 2), recordedAt: march8, now: march9, calendar: dateCalendar)
        precondition(dstCarry?.label == "2日前・多め", "Carry must use calendar days across DST")
        var midnightMatrix = prior
        precondition(midnightMatrix.refreshCalendarAnswers(at: nextDay, calendar: dateCalendar))
        precondition(midnightMatrix[.b12]?.label == "昨日・1食分")
        precondition(midnightMatrix.customAnswers?[custom.id.uuidString]?.answer.dayRange == DayRange(lower: 4, upper: 7))
        var customRangeRecord = carried; customRangeRecord[.energy] = Answer(Choice("energy3", "普通", 3))
        let partialGroup = Statistics.customSummary([customRangeRecord], outcome: .energy, item: custom, calendar: dateCalendar)
        precondition(partialGroup.allSatisfy { $0.days == 0 }, "Straddling custom ranges do not enter either bucket")
        customRangeRecord.customAnswers?[custom.id.uuidString]?.answer = Answer(Choice("fourToSix", "4〜6日前", 5))
        let legacyCustomGroups = Statistics.customSummary([customRangeRecord], outcome: .energy, item: custom, calendar: dateCalendar)
        precondition(legacyCustomGroups[3].days == 1 && legacyCustomGroups[3].mean == 3, "Old custom date ranges remain comparable")
        var cleared = LogRecord(); cleared.date = nextDay
        cleared.markCleared(RecordingStep.builtin(.iron).id, cleared: true)
        cleared.markCleared(RecordingStep.custom(custom).id, cleared: true)
        let clearedResult = AnswerCarryForward.filling(cleared, from: [prior], customItems: [custom], calendar: dateCalendar)
        precondition(clearedResult[.iron] == nil && clearedResult.customAnswers?[custom.id.uuidString] == nil)
        precondition(AnswerCarryForward.answer(for: .iron, records: [prior, clearedResult], now: dayAfter, calendar: dateCalendar) == nil, "Cleared responses must not reappear on later records")
        precondition(AnswerCarryForward.customAnswer(for: custom, records: [prior, clearedResult], now: dayAfter, calendar: dateCalendar) == nil)
        cleared.markCleared(RecordingStep.builtin(.iron).id, cleared: false)
        precondition(AnswerCarryForward.filling(cleared, from: [prior], calendar: dateCalendar)[.iron] != nil)
        try repo.write([clearedResult]); let clearedLoaded = try repo.read()
        precondition(clearedLoaded == [clearedResult] && oldRecord.clearedSteps == nil)
        precondition(Question.caffeine.rawValue == 16 && Question.tobacco.rawValue == 18)
        precondition(Question.restoredStep(13, version: 5) == 17)
        var stimulant = LogRecord(); stimulant.date = october
        stimulant[.caffeine] = Choices.matrix(day: Choices.recency[0], amount: 2, suffix: "多め", on: october)
        var laterStimulant = LogRecord(); laterStimulant.date = nextDay
        precondition(AnswerCarryForward.filling(laterStimulant, from: [stimulant], calendar: dateCalendar)[.caffeine]?.label == "昨日・多め")
        precondition(AnswerCarryForward.filling(laterStimulant, from: [stimulant], excluding: [.caffeine], calendar: dateCalendar)[.caffeine] == nil)
        stimulant[.caffeine] = Answer(Choice("notUsed", "普段は取らない"))
        precondition(AnswerCarryForward.filling(laterStimulant, from: [stimulant], calendar: dateCalendar)[.caffeine] == nil)
        precondition(TimelineModel.rows(customItems: [], records: [stimulant]).contains { $0.question == .caffeine })
        try repo.write([stimulant]); let substanceLoaded = try repo.read()
        precondition(substanceLoaded == [stimulant] && oldRecord[.caffeine] == nil)
        precondition(Question.lastObligation.rawValue == 19 && Question.nextObligation.rawValue == 20 && Question.backlog.rawValue == 21)
        precondition(!Question.flow.contains(.lastWork) && !Question.flow.contains(.nextWork))
        precondition(Question.restoredStep(8, version: 6) == 8 && Question.restoredStep(10, version: 6) == 11)
        var legacyWork = LogRecord(); legacyWork.date = march8
        legacyWork[.lastWork] = ApproximateDates.choices(future: false)[0].answer(on: march8, calendar: dateCalendar)
        legacyWork[.nextWork] = tomorrowRange
        var newDraft = LogRecord(); newDraft.date = march9
        let migratedCarry = AnswerCarryForward.filling(newDraft, from: [legacyWork], calendar: dateCalendar)
        precondition(migratedCarry[.lastObligation] == nil && migratedCarry[.nextObligation] == nil, "Work-only history must not become obligation answers")
        precondition(migratedCarry[.lastWork] == nil && migratedCarry[.nextWork] == nil, "Legacy work is no longer filled into new records")
        var obligation = legacyWork
        obligation[.lastObligation] = ApproximateDates.choices(future: false)[0].answer(on: march8, calendar: dateCalendar)
        obligation[.nextObligation] = ApproximateDates.choices(future: true)[1].answer(on: march8, calendar: dateCalendar)
        obligation[.backlog] = Answer(Choices.forQuestion(.backlog)[4])
        let obligationCarry = AnswerCarryForward.filling(newDraft, from: [obligation], calendar: dateCalendar)
        precondition(obligationCarry[.lastObligation]?.label == "昨日" && obligationCarry[.nextObligation]?.label == "今日")
        precondition(obligationCarry[.backlog] == nil, "Current backlog is never filled")
        obligation[.lastObligation] = Answer(Choice("inProgress", "今やっている"))
        precondition(AnswerCarryForward.answer(for: .lastObligation, records: [obligation], now: march9, calendar: dateCalendar) == nil)
        obligation[.mood] = Answer(Choice("mood3", "普通", 3))
        let backlogGroups = Statistics.choiceSummary([obligation], outcome: .mood, factor: .backlog, calendar: dateCalendar)
        precondition(backlogGroups.count == 5 && backlogGroups[4].days == 1 && backlogGroups[4].mean == 3)
        precondition(Statistics.summary([obligation], outcome: .mood, factor: .backlog, recent: false, calendar: dateCalendar).days == 0)
        try repo.write([obligation]); let obligationLoaded = try repo.read(); precondition(obligationLoaded == [obligation])
        for tick in 0..<24 {
            let angle = Double(tick) * Double.pi / 12 - Double.pi / 2
            precondition(ClockDialSelection.step(x: cos(angle), y: sin(angle)) == tick)
            precondition(ClockDialSelection.minutes(step: tick, start: 0) == tick * 30)
            precondition(ClockDialSelection.minutes(step: tick, start: 720) == tick * 30 + 720)
        }
        precondition(ClockDialSelection.step(x: -0.01, y: -1) == 0)
        precondition(ClockDialSelection.step(x: 0.01, y: -1) == 0)
        precondition(ClockDialSelection.minutes(step: 0, start: 0) == 0)
        precondition(ClockDialSelection.minutes(step: 0, start: 720) == 720)
        for question in [Question.sleepStart, .sleepEnd] {
            var covered = Set<Int>()
            for alternate in [false, true] {
                let start = ClockDialSelection.start(for: question, alternate: alternate)
                let values = (0..<24).map { ClockDialSelection.minutes(step: $0, start: start) }
                precondition(Set(values).count == 24)
                for value in values {
                    precondition(ClockDialSelection.contains(value, start: start))
                    precondition(value % 720 / 30 == values.firstIndex(of: value)!)
                    covered.insert(value)
                }
            }
            precondition(covered == Set(stride(from: 0, to: 1440, by: 30)))
        }
        let bedtimeStart = ClockDialSelection.defaultStart(for: .sleepStart)
        let wakeStart = ClockDialSelection.defaultStart(for: .sleepEnd)
        precondition(ClockDialSelection.minutes(step: 22, start: bedtimeStart) == 1380)
        precondition(ClockDialSelection.minutes(step: 0, start: bedtimeStart) == 0)
        precondition(ClockDialSelection.minutes(step: 2, start: bedtimeStart) == 60)
        for minutes in [300, 360, 720, 780] {
            precondition(ClockDialSelection.minutes(step: minutes % 720 / 30, start: wakeStart) == minutes)
        }
        precondition(ClockDialSelection.contains(330, start: bedtimeStart) && !ClockDialSelection.contains(360, start: bedtimeStart))
        precondition(ClockDialSelection.contains(870, start: wakeStart) && !ClockDialSelection.contains(900, start: wakeStart))
        precondition(ClockDialSelection.label(start: bedtimeStart) == "18:00〜翌5:30")
        precondition(ClockDialSelection.label(start: wakeStart) == "3:00〜14:30")
        testComparisonGroups()
        testAnswerShades()
        print("Hiragana sample: \(customRecord.displayedNote)")
        print("PASS: persistence, sleep clock arithmetic, midnight/daytime sleep, invalidation, legacy records/drafts, recency comparison, missing values, answer shading")
    }

    static func testComparisonGroups() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let day = CalendarSelection.date("2026-10-01", calendar: calendar)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        func record(_ date: Date, mood: Double?, energy: Double?) -> LogRecord {
            var result = LogRecord(); result.date = date
            if let mood { result[.mood] = Answer(Choice("mood\(Int(mood))", "気分", mood)) }
            if let energy { result[.energy] = Answer(Choice("energy\(Int(energy))", "気力", energy)) }
            return result
        }
        var a = record(day, mood: 1, energy: nil)
        var b = record(day.addingTimeInterval(3600), mood: 5, energy: 2)
        var c = record(tomorrow, mood: 5, energy: 4)
        for index in 0..<3 {
            let answer = Choices.matrix(day: Choices.recency[0], amount: 1, suffix: "1食分", on: index == 2 ? tomorrow : day)
            if index == 0 { a[.iron] = answer }
            if index == 1 { b[.iron] = answer }
            if index == 2 { c[.iron] = answer }
        }
        let missingFactor = record(day, mood: 5, energy: 5)
        let daily = ComparisonModel.groups(records: [a, b, c, missingFactor], factor: .iron, calendar: calendar)
        precondition(daily.count == 6 && daily[0].mood.days == 2 && daily[0].energy.days == 2)
        precondition(daily[0].mood.mean == 4 && daily[0].energy.mean == 3, "Each outcome ignores its missing scores and averages days before the whole period")
        precondition(daily[1].mood.mean == nil && daily[1].energy.days == 0, "Empty categories remain missing, not zero")
        let exactAmount = ComparisonModel.groups(records: [a, b, c], factor: .iron, amount: 1, calendar: calendar)
        precondition(exactAmount[0].mood.mean == 4)
        var small = a; small.id = UUID(); small[.iron]?.amount = 0
        let smallAmount = ComparisonModel.groups(records: [small, b, c], factor: .iron, amount: 0, calendar: calendar)
        precondition(smallAmount[0].mood.days == 1 && smallAmount[0].mood.mean == 1 && smallAmount[0].energy.mean == nil)
        precondition(ComparisonModel.groups(records: [a, b, c], factor: .iron, amount: 2, calendar: calendar).allSatisfy { $0.mood.days == 0 && $0.energy.days == 0 })

        var straddling = a; straddling.date = tomorrow
        straddling[.iron] = ApproximateDates.choices(future: false)[3].answer(on: day, calendar: calendar)
        precondition(ComparisonModel.groups(records: [straddling], factor: .iron, calendar: calendar).allSatisfy { $0.mood.days == 0 && $0.energy.days == 0 }, "A 3–6 day answer becomes 4–7 and cannot be assigned to either category")
        var bounded = straddling
        bounded[.iron]?.dayRange = DayRange(lower: 3, upper: 5)
        let normalized = ComparisonModel.groups(records: [bounded], factor: .iron, calendar: calendar)
        precondition(normalized[3].mood.days == 1 && normalized[3].mood.mean == 1, "Normalize to record date, rather than the original reference or the current day")
        bounded[.iron]?.rangeReferenceDate = nil
        precondition(ComparisonModel.groups(records: [bounded], factor: .iron, calendar: calendar).allSatisfy { $0.mood.days == 0 }, "Invalid dated answers must not fall back to their stale category code")
        var legacy = a; legacy[.iron] = Answer(Choice("fourToSix_2", "4〜6日前・多め", 5), amount: 2)
        precondition(ComparisonModel.groups(records: [legacy], factor: .iron, calendar: calendar)[3].mood.mean == 1)
        legacy[.iron] = Answer(Choice("weekPlus_2", "1週間以上前・多め", 7), amount: 2)
        precondition(ComparisonModel.groups(records: [legacy], factor: .iron, calendar: calendar).allSatisfy { $0.mood.days == 0 }, "An open-ended 7+ range spans two categories and has no invented midpoint")

        var progress = a; progress[.lastObligation] = Answer(Choice("inProgress", "今やっている"))
        let progressGroups = ComparisonModel.groups(records: [progress], factor: .lastObligation, calendar: calendar)
        precondition(progressGroups.count == 7 && progressGroups.last?.id == "inProgress" && progressGroups.last?.mood.mean == 1)
        var notUsed = a; notUsed[.caffeine] = Answer(Choice("notUsed", "普段は取らない"))
        precondition(ComparisonModel.groups(records: [notUsed], factor: .caffeine, calendar: calendar).last?.id == "notUsed")
        precondition(ComparisonModel.groups(records: [notUsed], factor: .caffeine, amount: 1, calendar: calendar).count == 6, "No-use responses are undated states without an amount")
        var planned = a; planned.date = tomorrow
        planned[.nextObligation] = ApproximateDates.choices(future: true)[1].answer(on: day, calendar: calendar)
        let futureGroups = ComparisonModel.groups(records: [planned], factor: .nextObligation, calendar: calendar)
        precondition(futureGroups[0].mood.days == 1 && futureGroups[1].label == "明日", "Future dates count down to the record date")

        a[.sleep] = Answer(Choice("noSleep", "寝ていない", 0))
        b[.sleep] = Answer(Choice("clockDuration", "7時間", 7))
        c[.sleep] = Answer(Choice("over12", "12時間超"))
        let sleep = ComparisonModel.groups(records: [a, b, c, missingFactor], factor: .sleep, calendar: calendar)
        precondition(sleep[0].mood.days == 1 && sleep[0].mood.mean == 1)
        precondition(sleep[1].mood.days == 2 && sleep[1].mood.mean == 5 && sleep[1].energy.mean == 3)
        a[.hunger] = Answer(Choices.forQuestion(.hunger)[4])
        b[.hunger] = a[.hunger]; c[.hunger] = a[.hunger]
        let hunger = ComparisonModel.groups(records: [a, b, c], factor: .hunger, calendar: calendar)
        precondition(hunger[4].mood.mean == 4 && hunger[4].energy.mean == 3 && hunger[4].mood.days == 2)
        a[.backlog] = Answer(Choices.forQuestion(.backlog)[0])
        precondition(ComparisonModel.groups(records: [a], factor: .backlog, calendar: calendar)[0].mood.mean == 1)

        let custom = CustomItem(title: "音楽を聴いた？", kind: .yesNo)
        for index in 0..<3 {
            let response = CustomResponse(item: custom, answer: Answer(custom.choices[0]))
            if index == 0 { a.customAnswers = [custom.id.uuidString: response] }
            if index == 1 { b.customAnswers = [custom.id.uuidString: response] }
            if index == 2 { c.customAnswers = [custom.id.uuidString: response] }
        }
        let customGroups = ComparisonModel.groups(records: [a, b, c], item: custom, calendar: calendar)
        precondition(customGroups[0].mood.mean == 4 && customGroups[0].energy.mean == 3 && customGroups[0].energy.days == 2)
        precondition(customGroups[1].mood.mean == nil)
        let recency = CustomItem(title: "外に出たのは？", kind: .recency)
        straddling.customAnswers = [recency.id.uuidString: CustomResponse(item: recency, answer: straddling[.iron]!)]
        precondition(ComparisonModel.groups(records: [straddling], item: recency, calendar: calendar).allSatisfy { $0.mood.days == 0 })
        straddling.customAnswers?[recency.id.uuidString]?.answer = Answer(Choice("never", "該当なし"))
        precondition(ComparisonModel.groups(records: [straddling], item: recency, calendar: calendar).last?.mood.mean == 1)
    }

    static func testAnswerShades() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let day = CalendarSelection.date("2026-10-01", calendar: calendar)!
        func shade(_ answer: Answer?, _ question: Question?, kind: CustomItem.Kind? = nil) -> Double {
            AnswerShade.opacity(of: answer, question: question, customKind: kind, recordedAt: day, calendar: calendar)
        }
        precondition(shade(nil, .iron) == 0, "Missing values must stay unfilled rather than looking like a recorded amount")
        for code in ["none", "notUsed", "noObligation", "noWork", "never", "no", "noSleep"] {
            precondition(shade(Answer(Choice(code, "なし")), .caffeine) == AnswerShade.absentOpacity)
        }
        for question in [Question.iron, .b12, .conversation, .salientDifficultEvent, .pleasantEvent, .caffeine, .alcohol, .tobacco] {
            let amounts = (0...2).map { amount in
                shade(Choices.matrix(day: Choices.recency[0], amount: amount, suffix: "量", on: day), question)
            }
            precondition(amounts[0] < amounts[1] && amounts[1] < amounts[2])
            for amount in 0...2 {
                let older = Choices.matrix(day: Choices.recency[5], amount: amount, suffix: "量", on: day)
                precondition(shade(older, question) == amounts[amount], "Date and amount must not be combined into an invented intensity")
            }
        }
        for question in [Question.hunger, .backlog] {
            let shades = Choices.forQuestion(question).map { shade(Answer($0), question) }
            precondition(zip(shades, shades.dropFirst()).allSatisfy(<))
            precondition(shades.first == AnswerShade.absentOpacity)
        }
        for question in [Question.exercise, .lastObligation, .nextObligation] {
            let shades = ApproximateDates.choices(future: question.isFuture).map { shade($0.answer(on: day, calendar: calendar), question) }
            precondition(zip(shades, shades.dropFirst()).allSatisfy(>))
            precondition(shade(Answer(Choice("today", "今日")), question) == shades[0], "Legacy recency codes keep the same scale")
            let older = CalendarSelection.date(question.isFuture ? "2026-10-03" : "2026-09-29", calendar: calendar)!
            let dated = CalendarSelection.answer(older, now: day, future: question.isFuture, calendar: calendar)!
            precondition(shade(dated, question) == shades[2], "Actual calendar dates are measured from the saved record")
        }
        var shifted = ApproximateDates.choices(future: false)[1].answer(on: day.addingTimeInterval(-86400), calendar: calendar)
        precondition(shade(shifted, .exercise) == shade(ApproximateDates.choices(future: false)[2].answer(on: day, calendar: calendar), .exercise))
        shifted.dayRange = DayRange(lower: 4, upper: 7); shifted.rangeReferenceDate = CalendarSelection.key(day, calendar: calendar)
        precondition(shade(shifted, .exercise) == AnswerShade.neutralOpacity, "A range crossing categories must not invent a precise date")
        shifted.dayRange = DayRange(lower: 3, upper: 2)
        precondition(shade(shifted, .exercise) == AnswerShade.neutralOpacity)
        shifted.dayRange = DayRange(lower: 2, upper: 2); shifted.rangeReferenceDate = nil
        precondition(shade(shifted, .exercise) == AnswerShade.neutralOpacity, "Invalid date ranges must not use stale category codes")
        precondition(shade(Answer(Choice("inProgress", "今やっている")), .lastObligation) > shade(Answer(Choice("unscheduled", "未定")), .nextObligation))
        precondition(shade(Answer(Choice("clockDuration", "4時間", 4)), .sleep) == shade(Answer(Choice("clockDuration", "9時間", 9)), .sleep), "Sleep shade must not imply a recommended number of hours")
        let scale = CustomItem(title: "任意の程度", kind: .scale)
        let scaleShades = scale.choices.map { shade(Answer($0), nil, kind: .scale) }
        precondition(zip(scaleShades, scaleShades.dropFirst()).allSatisfy(<))
        precondition(shade(Answer(Choice("yes", "はい", 1)), nil, kind: .yesNo) > shade(Answer(Choice("no", "いいえ", 0)), nil, kind: .yesNo))
        precondition(shade(Answer(Choice("option0", "任意")), nil, kind: .options) == AnswerShade.neutralOpacity)
        for value in [-1.0, 6.0, Double.nan, Double.infinity] {
            precondition(shade(Answer(Choice("invalid", "不明", value)), .hunger) == AnswerShade.neutralOpacity)
        }
        precondition(shade(Answer(Choice("today_3", "不明"), amount: 3), .iron) == AnswerShade.neutralOpacity)
    }
}
