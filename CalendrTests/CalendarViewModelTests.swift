//
//  CalendarViewModelTests.swift
//  CalendrTests
//
//  Created by Paker on 09/01/21.
//

import XCTest
import RxSwift
@testable import Calendr

class CalendarViewModelTests: XCTestCase {

    let disposeBag = DisposeBag()
    
    let dateSubject = PublishSubject<Date>()
    let hoverSubject = PublishSubject<Date?>()
    let calendarsSubject = PublishSubject<[String]>()

    private let calendarService = MockCalendarServiceProvider()

    let dateProvider = MockDateProvider()

    let notificationCenter = NotificationCenter()

    lazy var viewModel = CalendarViewModel(
        dateObservable: dateSubject,
        hoverObservable: hoverSubject,
        enabledCalendars: calendarsSubject,
        calendarService: calendarService,
        dateProvider: dateProvider,
        notificationCenter: notificationCenter
    )

    var lastValue: [CalendarCellViewModel]?

    override func setUp() {

        viewModel
            .asObservable()
            .bind { [weak self] in
                self?.lastValue = $0
            }
            .disposed(by: disposeBag)

        calendarsSubject.onNext([])
    }

    func testMonthSpan() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        guard let cellViewModels = lastValue else {
            return XCTFail()
        }

        let inMonth = cellViewModels.filter(\.inMonth)

        XCTAssertEqual(inMonth.count, 31)
        XCTAssertEqual(inMonth.first.map(\.date), .make(year: 2021, month: 1, day: 1))
        XCTAssertEqual(inMonth.last.map(\.date), .make(year: 2021, month: 1, day: 31))
    }

    func testDateSpan_firstWeekDaySunday() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        guard let cellViewModels = lastValue else {
            return XCTFail()
        }

        XCTAssertEqual(cellViewModels.count, 42)
        XCTAssertEqual(cellViewModels.first.map(\.date), .make(year: 2020, month: 12, day: 27))
        XCTAssertEqual(cellViewModels.last.map(\.date), .make(year: 2021, month: 2, day: 6))
    }

    func testDateSpan_firstWeekDayMonday() {

        dateProvider.m_calendar.firstWeekday = 2

        notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        guard let cellViewModels = lastValue else {
            return XCTFail()
        }

        XCTAssertEqual(cellViewModels.count, 42)
        XCTAssertEqual(cellViewModels.first.map(\.date), .make(year: 2020, month: 12, day: 28))
        XCTAssertEqual(cellViewModels.last.map(\.date), .make(year: 2021, month: 2, day: 7))
    }

    func testWeekDays_firstWeekDaySunday() {

        var weekDays: [WeekDay]?

        viewModel.weekDays
            .bind { weekDays = $0 }
            .disposed(by: disposeBag)

        let expected = ["S", "M", "T", "W", "T", "F", "S"]

        XCTAssertEqual(weekDays?.map(\.title), expected)
        XCTAssertEqual(weekDays?.enumerated().filter(\.element.isWeekend).map(\.offset), [0, 6])
    }

    func testWeekDays_firstWeekDayMonday() {

        dateProvider.m_calendar.firstWeekday = 2

        notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)

        var weekDays: [WeekDay]?

        viewModel.weekDays
            .bind { weekDays = $0 }
            .disposed(by: disposeBag)

        let expected = ["M", "T", "W", "T", "F", "S", "S"]

        XCTAssertEqual(weekDays?.map(\.title), expected)
        XCTAssertEqual(weekDays?.enumerated().filter(\.element.isWeekend).map(\.offset), [5, 6])
    }

    func testWeekNumbers_gregorianCalendar() {

        var weekNumbers: [Int]?

        viewModel.weekNumbers
            .bind { weekNumbers = $0 }
            .disposed(by: disposeBag)

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))
        XCTAssertEqual(weekNumbers, Array(1...6))

        dateSubject.onNext(.make(year: 2021, month: 2, day: 1))
        XCTAssertEqual(weekNumbers, Array(6...11))
    }

    // Monday is the default first day of week for ISO8601
    func testWeekNumbers_iso8601Calendar_firstWeekDayMonday() {

        dateProvider.m_calendar = Calendar(identifier: .iso8601)

        var weekNumbers: [Int]?

        viewModel.weekNumbers
            .bind { weekNumbers = $0 }
            .disposed(by: disposeBag)

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))
        XCTAssertEqual(weekNumbers, Array([52, 53, 1, 2, 3, 4]))

        dateSubject.onNext(.make(year: 2021, month: 2, day: 1))
        XCTAssertEqual(weekNumbers, Array(4...9))
    }

    func testWeekNumbers_iso8601Calendar_firstWeekDaySunday() {

        dateProvider.m_calendar = Calendar(identifier: .iso8601)
        dateProvider.m_calendar.firstWeekday = 1

        var weekNumbers: [Int]?

        viewModel.weekNumbers
            .bind { weekNumbers = $0 }
            .disposed(by: disposeBag)

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))
        XCTAssertEqual(weekNumbers, Array([53, 1, 2, 3, 4, 5]))

        dateSubject.onNext(.make(year: 2021, month: 2, day: 1))
        XCTAssertEqual(weekNumbers, Array(5...10))
    }

    func testHoverDistinctly() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        (1...5).map {
            Date.make(year: 2021, month: 1, day: $0)
        }
        .forEach { date in
            hoverSubject.onNext(date)

            guard let hovered = lastValue?.filter(\.isHovered) else {
                return XCTFail()
            }

            XCTAssertEqual(hovered.count, 1)
            XCTAssertEqual(hovered.first.map(\.date), date)
        }
    }

    func testUnhover() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        hoverSubject.onNext(.make(year: 2021, month: 1, day: 1))
        XCTAssertTrue(hasHoveredDate)

        hoverSubject.onNext(nil)
        XCTAssertFalse(hasHoveredDate)
    }

    func testUnhoverAfterMonthChange() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        hoverSubject.onNext(.make(year: 2021, month: 1, day: 1))
        XCTAssertTrue(hasHoveredDate)

        dateSubject.onNext(.make(year: 2021, month: 1, day: 2))
        XCTAssertTrue(hasHoveredDate)

        dateSubject.onNext(.make(year: 2021, month: 2, day: 2))
        XCTAssertFalse(hasHoveredDate)
    }

    var hasHoveredDate: Bool {
        lastValue?.filter(\.isHovered).isEmpty == false
    }

    func testSelectDateDistinctly() {

        (1...5).map {
            Date.make(year: 2021, month: 1, day: $0)
        }
        .forEach { date in
            dateSubject.onNext(date)

            guard let selected = lastValue?.filter(\.isSelected) else {
                return XCTFail()
            }

            XCTAssertEqual(selected.count, 1)
            XCTAssertEqual(selected.first.map(\.date), date)
        }
    }

    func testTodayVisibility() {

        dateProvider.now = .make(year: 2020, month: 12, day: 31)

        let expectedPositions: [(date: Date, position: Int?)] = [
            (.make(year: 2020, month: 12, day: 1), 32),
            (.make(year: 2021, month: 1, day: 1), 4),
            (.make(year: 2021, month: 2, day: 1), nil)
        ]

        for (date, position) in expectedPositions {
            dateSubject.onNext(date)

            XCTAssertEqual(lastValue?.map(\.date).lastIndex(of: dateProvider.now), position, "\(date)")
        }
    }

    func testTodayChange() {

        let dates: [Date] = [
            .make(year: 2021, month: 1, day: 1),
            .make(year: 2021, month: 1, day: 2),
            .make(year: 2021, month: 2, day: 1)
        ]

        for date in dates {
            dateProvider.now = date
            dateSubject.onNext(date)

            XCTAssertEqual(lastValue?.first(where: \.isToday).map(\.date), date, "\(date)")
        }
    }

    func testTimezoneChange() {

        let timezone = TimeZone(abbreviation: "UTC-1")!

        dateProvider.m_calendar.timeZone = timezone
        dateProvider.now = .make(year: 2021, month: 1, day: 1, hour: 23, timezone: timezone)

        dateSubject.onNext(dateProvider.now)

        XCTAssertEqual(lastValue?.firstIndex(where: \.isToday), 5)

        dateProvider.m_calendar.timeZone = TimeZone(identifier: "UTC")!

        dateSubject.onNext(dateProvider.now)

        XCTAssertEqual(lastValue?.firstIndex(where: \.isToday), 6)
    }

    func testEventsPerDate() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        let expectedEvents: [(date: Date, events: [String])] = [
            (.make(year: 2021, month: 1, day: 1), ["Event 1"]),
            (.make(year: 2021, month: 1, day: 2), ["Event 1", "Event 2", "Event 3"]),
            (.make(year: 2021, month: 1, day: 3), ["Event 1", "Event 4"]),
        ]

        for (date, expected) in expectedEvents {
            let events = lastValue?
                .first(where: { $0.date == date })
                .flatMap(\.events)?
                .map(\.title)

            XCTAssertEqual(events, expected, "\(date)")
        }
    }

    func testEventDotsPerDate() {

        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))

        let expectedEvents: [(date: Date, events: Set<CGColor>)] = [
            (.make(year: 2021, month: 1, day: 1), [.white]),
            (.make(year: 2021, month: 1, day: 2), [.white, .black]),
            (.make(year: 2021, month: 1, day: 3), [.white, .clear]),
        ]

        for (date, expected) in expectedEvents {
            let events = lastValue?
                .first(where: { $0.date == date })
                .flatMap(\.dots)

            XCTAssertEqual(events?.count, expected.count, "\(date)")
            XCTAssertEqual(events.map(Set.init), expected, "\(date)")
        }
    }

    func testServiceProviderEventsDateRange() {

        var ranges: [[Date]] = []

        calendarService.spyEventsObservable.bind {
            ranges.append([$0.start, $0.end])
        }
        .disposed(by: disposeBag)

        calendarsSubject.onNext(["1"])
        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))
        dateSubject.onNext(.make(year: 2021, month: 1, day: 2))
        dateSubject.onNext(.make(year: 2021, month: 2, day: 1))

        XCTAssertEqual(ranges, [
            [.make(year: 2020, month: 12, day: 27), .make(year: 2021, month: 2, day: 6)], // calendar
            [.make(year: 2021, month: 1, day: 31), .make(year: 2021, month: 3, day: 13)] // month change
        ])
    }

    func testServiceProviderEventsCalendars() {

        var calendars: [[String]] = []

        calendarService.spyEventsObservable.map(\.calendars).bind {
            calendars.append($0)
        }
        .disposed(by: disposeBag)

        calendarsSubject.onNext(["1", "2", "3"])
        dateSubject.onNext(.make(year: 2021, month: 1, day: 1))
        dateSubject.onNext(.make(year: 2021, month: 2, day: 1))
        calendarsSubject.onNext(["1", "3"])

        XCTAssertEqual(calendars, [
            ["1", "2", "3"], // calendar
            ["1", "2", "3"], // month change
            ["1", "3"] // calendar
        ])
    }
}

private typealias EventsArgs = (start: Date, end: Date, calendars: [String])

private class MockCalendarServiceProvider: CalendarServiceProviding {

    let (changeObservable, changeObserver) = PublishSubject<Void>.pipe()
    let (spyEventsObservable, spyEventsObserver) = PublishSubject<EventsArgs>.pipe()

    var m_calendars: [CalendarModel]
    var m_events: [EventModel]

    init() {
        m_calendars = [
            .init(identifier: "1", account: "A1", title: "Calendar 1", color: .white),
            .init(identifier: "2", account: "A2", title: "Calendar 2", color: .black),
            .init(identifier: "3", account: "A3", title: "Calendar 3", color: .clear)
        ]

        m_events = [
            .make(
                start: .make(year: 2021, month: 1, day: 1),
                end: .make(year: 2021, month: 1, day: 4),
                isAllDay: true,
                title: "Event 1",
                calendar: m_calendars[0]
            ),
            .make(
                start: .make(year: 2021, month: 1, day: 2),
                end: .make(year: 2021, month: 1, day: 2),
                isAllDay: true,
                title: "Event 2",
                calendar: m_calendars[0]
            ),
            .make(
                start: .make(year: 2021, month: 1, day: 2, hour: 8),
                end: .make(year: 2021, month: 1, day: 2, hour: 9),
                isAllDay: false,
                title: "Event 3",
                calendar: m_calendars[1]
            ),
            .make(
                start: .make(year: 2021, month: 1, day: 3, hour: 14),
                end: .make(year: 2021, month: 1, day: 3, hour: 15),
                isAllDay: false,
                title: "Event 4",
                calendar: m_calendars[2]
            )
        ]
    }

    func calendars() -> Observable<[CalendarModel]> {
        return .just(m_calendars)
    }

    func events(from start: Date, to end: Date, calendars: [String]) -> Observable<[EventModel]> {
        spyEventsObserver.onNext((start: start, end: end, calendars: calendars))
        return .just(m_events)
    }
}
