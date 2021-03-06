//
//  GeneralSettingsViewController.swift
//  Calendr
//
//  Created by Paker on 28/01/21.
//

import RxCocoa
import RxSwift

class GeneralSettingsViewController: NSViewController {

    private let disposeBag = DisposeBag()

    private let viewModel: SettingsViewModel

    private let showMenuBarIconCheckbox = Checkbox(title: Strings.Settings.MenuBar.showIcon)
    private let showMenuBarDateCheckbox = Checkbox(title: Strings.Settings.MenuBar.showDate)
    private let showWeekNumbersCheckbox = Checkbox(title: Strings.Settings.Calendar.showWeekNumbers)
    private let fadePastEventsRadio = Radio(title: Strings.Settings.Events.Finished.fade)
    private let hidePastEventsRadio = Radio(title: Strings.Settings.Events.Finished.hide)
    private let dateFormatDropdown = Dropdown()

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        setUpBindings()
    }

    override func loadView() {
        view = NSView()

        let stackView = NSStackView(views: [
            makeSection(title: Strings.Settings.menuBar, content: menuBarContent),
            makeSection(title: Strings.Settings.calendar, content: showWeekNumbersCheckbox),
            makeSection(title: Strings.Settings.events, content: eventsContent),
            makeSection(title: Strings.Settings.transparency, content: transparencySlider)
        ])
        .with(spacing: Constants.contentSpacing)
        .with(orientation: .vertical)

        view.addSubview(stackView)

        stackView.edges(to: view)
    }

    private lazy var menuBarContent: NSView = {

        let checkboxes = NSStackView(views: [
            showMenuBarIconCheckbox, showMenuBarDateCheckbox
        ])

        let dateFormat = NSStackView(views: [
            Label(text: "\(Strings.Settings.MenuBar.dateFormat):"),
            dateFormatDropdown,
            Label(
                text: " \(Strings.Settings.MenuBar.DateFormat.info)",
                font: .systemFont(ofSize: 10, weight: .light)
            )
        ])
        .with(orientation: .vertical)

        return NSStackView(views: [checkboxes, dateFormat])
            .with(spacing: Constants.contentSpacing)
            .with(orientation: .vertical)
    }()

    private lazy var eventsContent: NSView = {
        NSStackView(views: [
            Label(text: "\(Strings.Settings.Events.finished):"), fadePastEventsRadio, hidePastEventsRadio
        ])
    }()

    private let transparencySlider: NSSlider = {
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 5, target: nil, action: nil)
        slider.allowsTickMarkValuesOnly = true
        slider.numberOfTickMarks = 6
        slider.controlSize = .small
        slider.refusesFirstResponder = true
        return slider
    }()

    private func makeSection(title: String, content: NSView) -> NSView {

        let label = Label(text: title, font: .systemFont(ofSize: 13, weight: .semibold))

        let divider: NSView = .spacer(height: 1)
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor

        let stackView = NSStackView(views: [
            label,
            divider,
            NSStackView(views: [.spacer(width: 0), content, .spacer(width: 0)])
        ])
        .with(orientation: .vertical)
        .with(alignment: .left)
        .with(spacing: 6)

        stackView.setCustomSpacing(12, after: divider)

        return stackView
    }

    private func setUpBindings() {

        bind(
            control: showMenuBarIconCheckbox,
            observable: viewModel.statusItemSettings.map(\.showIcon),
            observer: viewModel.toggleStatusItemIcon
        )

        bind(
            control: showMenuBarDateCheckbox,
            observable: viewModel.statusItemSettings.map(\.showDate),
            observer: viewModel.toggleStatusItemDate
        )

        bind(
            control: showWeekNumbersCheckbox,
            observable: viewModel.showWeekNumbers,
            observer: viewModel.toggleWeekNumbers
        )

        bind(
            control: fadePastEventsRadio,
            observable: viewModel.showPastEvents,
            observer: viewModel.togglePastEvents
        )

        bind(
            control: hidePastEventsRadio,
            observable: viewModel.showPastEvents.map(\.isFalse),
            observer: viewModel.togglePastEvents.mapObserver(\.isFalse)
        )

        viewModel.popoverTransparency
            .bind(to: transparencySlider.rx.integerValue)
            .disposed(by: disposeBag)

        transparencySlider.rx.value
            .skip(1)
            .map(Int.init)
            .bind(to: viewModel.transparencyObserver)
            .disposed(by: disposeBag)

        let dateFormatStyle = dateFormatDropdown.rx.controlProperty(
            getter: { (dropdown: NSPopUpButton) -> DateFormatter.Style in
                DateFormatter.Style(rawValue: UInt(dropdown.indexOfSelectedItem + 1)) ?? .none
            },
            setter: { (dropdown: NSPopUpButton, style: DateFormatter.Style) in
                dropdown.selectItem(at: Int(style.rawValue) - 1)
            }
        )

        dateFormatStyle
            .skip(1)
            .bind(to: viewModel.statusItemDateStyleObserver)
            .disposed(by: disposeBag)

        viewModel.dateFormatOptions
            .withLatestFrom(viewModel.statusItemSettings.map(\.dateStyle)) { ($0, $1) }
            .bind { [dateFormatDropdown] options, dateStyle in
                dateFormatDropdown.removeAllItems()
                dateFormatDropdown.addItems(withTitles: options)
                dateFormatStyle.onNext(dateStyle)
            }
            .disposed(by: disposeBag)
    }

    private func bind(control: NSButton, observable: Observable<Bool>, observer: AnyObserver<Bool>) {
        observable
            .map { $0 ? .on : .off }
            .bind(to: control.rx.state)
            .disposed(by: disposeBag)

        control.rx.state
            .skip(1)
            .map { $0 == .on }
            .bind(to: observer)
            .disposed(by: disposeBag)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum Constants {

    static let contentSpacing: CGFloat = 16
}
