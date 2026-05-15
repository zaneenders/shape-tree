import ShapeTreeClient
import SwiftUI

#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Journal visual chrome (Scribe-like dark layout)

private enum ShapeTreeJournalPalette {
  static let accentBlue = Color(red: 0, green: 122 / 255, blue: 1)
  static let sidebar = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
  static let contentPanel = Color(red: 18 / 255, green: 18 / 255, blue: 19 / 255)
  static let entryCard = Color(red: 40 / 255, green: 40 / 255, blue: 42 / 255)
  static let hairline = Color.white.opacity(0.08)
}

// MARK: - Local journal day keys (device calendar — matches `journal_day` on append)

private enum ShapeTreeJournalLocalFormatting {
  static var deviceCalendar: Calendar { .autoupdatingCurrent }

  static func dayTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.autoupdatingCurrent
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  static func dayKey(for date: Date) -> String {
    let cal = deviceCalendar
    let yy = cal.component(.year, from: date) % 100
    let mm = cal.component(.month, from: date)
    let dd = cal.component(.day, from: date)
    return String(format: "%02d-%02d-%02d", yy, mm, dd)
  }

  /// Keeps calendar day (`d`) when advancing months, clamped to destination month length (e.g. May 31 → Jun 30).
  static func constrainDayToMonth(dayFrom selected: Date, monthStart anchor: Date) -> Date {
    let cal = deviceCalendar
    guard let dayRange = cal.range(of: .day, in: .month, for: anchor) else { return anchor }
    var c = cal.dateComponents([.year, .month], from: anchor)
    let d = cal.component(.day, from: selected)
    c.day = min(max(d, dayRange.lowerBound), dayRange.upperBound)
    return cal.date(from: c) ?? anchor
  }
}

// MARK: - Calendar model

@Observable
@MainActor
private final class ShapeTreeJournalCalendarModel {
  let journalModel: ShapeTreeViewModel
  var currentMonth: Date = Date()
  private(set) var entriesByDay: [String: Components.Schemas.JournalEntrySummary] = [:]

  init(journalModel: ShapeTreeViewModel) {
    self.journalModel = journalModel
  }

  func entry(for date: Date) -> Components.Schemas.JournalEntrySummary? {
    entriesByDay[ShapeTreeJournalLocalFormatting.dayKey(for: date)]
  }

  func loadEntries() async {
    let calendar = ShapeTreeJournalLocalFormatting.deviceCalendar
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
      let startDate = calendar.date(byAdding: .day, value: -7, to: monthInterval.start),
      let endDate = calendar.date(byAdding: .day, value: 7, to: monthInterval.end)
    else { return }

    let startKey = ShapeTreeJournalLocalFormatting.dayKey(for: startDate)
    let endKey = ShapeTreeJournalLocalFormatting.dayKey(for: endDate)

    guard !journalModel.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      entriesByDay = [:]
      return
    }

    do {
      let rows = try await journalModel.fetchJournalEntrySummaries(
        startDayKey: startKey,
        endDayKey: endKey)
      var dict: [String: Components.Schemas.JournalEntrySummary] = [:]
      for row in rows {
        dict[row.date] = row
      }
      entriesByDay = dict
      journalModel.clearJournalCalendarError()
    } catch {
      entriesByDay = [:]
      journalModel.reportJournalCalendarLoadFailure(error)
    }
  }

  func previousMonth() {
    guard let d = ShapeTreeJournalLocalFormatting.deviceCalendar.date(byAdding: .month, value: -1, to: currentMonth)
    else { return }
    currentMonth = d
  }

  func nextMonth() {
    guard let d = ShapeTreeJournalLocalFormatting.deviceCalendar.date(byAdding: .month, value: 1, to: currentMonth)
    else { return }
    currentMonth = d
  }
}

// MARK: - Container

struct ShapeTreeJournalContainerView: View {
  @Bindable var journalModel: ShapeTreeViewModel
  @Environment(\.colorScheme) private var colorScheme

  @State private var calendarModel: ShapeTreeJournalCalendarModel

  @State private var selectedDate: Date = Date()
  @State private var scrollOffset: CGFloat = 0
  @State private var isTodayComposerVisible = false
  @State private var entryRefreshToken = UUID()
  @State private var calendarReloadNonce = 0

  private static let journalComposerBottomId = "journalComposerBottom"

  init(journalModel: ShapeTreeViewModel) {
    self.journalModel = journalModel
    _calendarModel = State(initialValue: ShapeTreeJournalCalendarModel(journalModel: journalModel))
  }

  private var deepJournalChrome: Bool {
    colorScheme == .dark
  }

  private var showsJournalFloatingOverlays: Bool {
    guard ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(selectedDate) else { return false }
    #if os(iOS)
    return !isTodayComposerVisible
    #else
    return true
    #endif
  }

  private var journalScrollBottomSpacerMinLength: CGFloat {
    #if os(iOS)
    return isTodayComposerVisible ? 160 : 100
    #else
    return isTodayComposerVisible ? 120 : 100
    #endif
  }

  private var editorialBackground: Color {
    if deepJournalChrome { return ShapeTreeJournalPalette.contentPanel }
    #if os(macOS)
    return Color(nsColor: .textBackgroundColor)
    #elseif canImport(UIKit)
    return Color(uiColor: UIColor.systemBackground)
    #else
    return Color(white: 0.95)
    #endif
  }

  var body: some View {
    coreLayout
      .onChange(of: journalModel.journalStatus) { _, newStatus in
        guard let newStatus,
          newStatus.localizedCaseInsensitiveContains("saved markdown")
        else { return }
        // Defer: mutating several @State values in one onChange pass trips
        // “tried to update multiple times per frame” for Optional<String> observers.
        Task { @MainActor in
          entryRefreshToken = UUID()
          calendarReloadNonce += 1
          dismissTodayComposer()
        }
      }
  }

  @ViewBuilder
  private var coreLayout: some View {
    #if os(macOS)
    macOSLayout
    #else
    iOSLayout
    #endif
  }

  @ViewBuilder
  private var macOSLayout: some View {
    HStack(spacing: 0) {
      ScrollView {
        ShapeTreeJournalCalendarSection(
          calendarModel: calendarModel,
          selectedDate: $selectedDate,
          journalModel: journalModel,
          calendarReloadNonce: calendarReloadNonce,
          deepChrome: deepJournalChrome
        )
        .frame(maxWidth: 380)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
      }
      .scrollIndicators(.visible)
      .frame(maxWidth: 400)

      Divider()
        .frame(width: 1)
        .background(deepJournalChrome ? ShapeTreeJournalPalette.hairline : Color.secondary.opacity(0.2))

      ScrollViewReader { proxy in
        ZStack(alignment: .bottomTrailing) {
          macJournalScroll(proxy: proxy)

          if showsJournalFloatingOverlays {
            ShapeTreeJournalFloatingEditButton(isComposerVisible: isTodayComposerVisible) {
              floatingEditTapped(proxy: proxy)
            }
            .padding(20)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onChange(of: selectedDate) { _, newDate in
      if !ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(newDate) {
        dismissTodayComposer()
      }
    }
  }

  @ViewBuilder
  private var iOSLayout: some View {
    ScrollViewReader { proxy in
      ZStack(alignment: .bottomTrailing) {
        ScrollView {
          VStack(spacing: 14) {
            ShapeTreeJournalCalendarSection(
              calendarModel: calendarModel,
              selectedDate: $selectedDate,
              journalModel: journalModel,
              calendarReloadNonce: calendarReloadNonce,
              deepChrome: deepJournalChrome
            )
            .id("calendar")
            .padding(.horizontal, 12)
            .padding(.top, 8)

            iOSJournalInnerContent(proxy: proxy)
          }
          .padding(.bottom, 8)
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaPadding(.bottom, isTodayComposerVisible ? 8 : 2)
        #endif
        .scrollContentBackground(.hidden)
        .background(editorialBackground)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
          geometry.contentOffset.y
        } action: { _, offset in
          scrollOffset = offset
        }

        if showsJournalFloatingOverlays {
          VStack(alignment: .trailing, spacing: 12) {
            if scrollOffset > 320 {
              scrollToTopButton(proxy: proxy)
            }
            ShapeTreeJournalFloatingEditButton(isComposerVisible: isTodayComposerVisible) {
              floatingEditTapped(proxy: proxy)
            }
          }
          .padding(.trailing, 12)
          .padding(.bottom, 8)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: selectedDate) { _, newDate in
      if !ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(newDate) {
        dismissTodayComposer()
      }
    }
  }

  private func scrollToTopButton(proxy: ScrollViewProxy) -> some View {
    Button {
      withAnimation(.smooth) {
        proxy.scrollTo("calendar", anchor: .top)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "chevron.up")
        Text("Top")
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        Capsule()
          .fill(Color.accentColor)
      )
      .shadow(radius: 4, x: 0, y: 2)
    }
  }

  private func macJournalScroll(proxy: ScrollViewProxy) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        dateHeaderMac
          .id("journalContentTop")

        ShapeTreeJournalEntryPreviewView(
          journalModel: journalModel,
          date: selectedDate,
          entryRefreshToken: entryRefreshToken,
          deepChrome: deepJournalChrome,
          onWriteToday: { openComposerAndScrollToBottom(proxy: proxy) }
        )

        if ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(selectedDate), isTodayComposerVisible {
          ShapeTreeJournalEntryComposer(
            viewModel: journalModel,
            deepChrome: deepJournalChrome,
            journalFilingDate: selectedDate,
            onComposerCancel: { dismissTodayComposer() }
          )
          .shapeTreeJournalInlineComposerChrome(deepChrome: deepJournalChrome)
        }

        Spacer(minLength: journalScrollBottomSpacerMinLength)

        Color.clear
          .frame(height: 1)
          .id(Self.journalComposerBottomId)
      }
      .padding(.horizontal, 28)
      .padding(.vertical, 20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollContentBackground(.hidden)
    .background(editorialBackground)
  }

  private func iOSJournalInnerContent(proxy: ScrollViewProxy) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      dateHeaderIOS
        .id("journalContentTop")

      ShapeTreeJournalEntryPreviewView(
        journalModel: journalModel,
        date: selectedDate,
        entryRefreshToken: entryRefreshToken,
        deepChrome: deepJournalChrome,
        onWriteToday: { openComposerAndScrollToBottom(proxy: proxy) }
      )
      .padding(.horizontal, 16)

      if ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(selectedDate), isTodayComposerVisible {
        ShapeTreeJournalEntryComposer(
          viewModel: journalModel,
          deepChrome: deepJournalChrome,
          journalFilingDate: selectedDate,
          onComposerCancel: { dismissTodayComposer() }
        )
        .shapeTreeJournalInlineComposerChrome(deepChrome: deepJournalChrome)
        .padding(.horizontal, 16)
      }

      Spacer(minLength: journalScrollBottomSpacerMinLength)

      Color.clear
        .frame(height: 1)
        .id(Self.journalComposerBottomId)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var dateHeaderMac: some View {
    let isToday = ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(selectedDate)
    let titleColor = deepJournalChrome ? Color.white.opacity(0.95) : Color.primary

    return HStack {
      VStack(alignment: .leading, spacing: 8) {
        Text(ShapeTreeJournalLocalFormatting.dayTitle(for: selectedDate))
          .font(.system(size: 30, weight: .bold))
          .foregroundStyle(titleColor)

        if isToday {
          Text("Today")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ShapeTreeJournalPalette.accentBlue)
        }
      }
      Spacer()
    }
    .padding(.top, 4)
  }

  private var dateHeaderIOS: some View {
    let isToday = ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(selectedDate)
    let titleColor = deepJournalChrome ? Color.white.opacity(0.95) : Color.primary

    return HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text(ShapeTreeJournalLocalFormatting.dayTitle(for: selectedDate))
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(titleColor)

        if isToday {
          Text("Today")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ShapeTreeJournalPalette.accentBlue)
        }
      }
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
  }

  private func openTodayComposer() {
    guard !isTodayComposerVisible else { return }
    journalModel.journalDraft = ""
    journalModel.journalError = nil
    journalModel.journalCalendarError = nil
    isTodayComposerVisible = true
  }

  private func openComposerAndScrollToBottom(proxy: ScrollViewProxy) {
    if !isTodayComposerVisible {
      openTodayComposer()
    }
    scrollJournalToBottom(proxy: proxy)
  }

  private func scrollJournalToBottom(proxy: ScrollViewProxy) {
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(50))
      withAnimation(.smooth) {
        proxy.scrollTo(Self.journalComposerBottomId, anchor: .bottom)
      }
    }
  }

  private func floatingEditTapped(proxy: ScrollViewProxy) {
    if isTodayComposerVisible {
      dismissTodayComposer()
    } else {
      openComposerAndScrollToBottom(proxy: proxy)
    }
  }

  private func dismissTodayComposer() {
    isTodayComposerVisible = false
  }
}

// MARK: - Floating edit

private struct ShapeTreeJournalFloatingEditButton: View {
  let isComposerVisible: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: isComposerVisible ? "xmark" : "square.and.pencil")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Color.white.opacity(0.92))
        .frame(width: 46, height: 46)
        .background(Circle().fill(Color(red: 0.26, green: 0.26, blue: 0.29)))
        .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Month calendar grid

private struct CalendarLoadIdentity: Equatable {
  var monthStart: TimeInterval
  var nonce: Int
}

private struct ShapeTreeJournalCalendarSection: View {
  @Bindable var calendarModel: ShapeTreeJournalCalendarModel
  @Binding var selectedDate: Date
  var journalModel: ShapeTreeViewModel
  var calendarReloadNonce: Int
  var deepChrome: Bool

  private static let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
    return formatter
  }()

  private var weekdayColumnLabels: [String] {
    let cal = ShapeTreeJournalLocalFormatting.deviceCalendar
    let symbols = cal.shortWeekdaySymbols
    return (0..<7).map { i in
      let idx = (cal.firstWeekday - 1 + i) % 7
      return symbols[idx]
    }
  }

  private var gridDays: [Date?] {
    let calendar = ShapeTreeJournalLocalFormatting.deviceCalendar
    guard let monthInterval = calendar.dateInterval(of: .month, for: calendarModel.currentMonth) else { return [] }
    let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
    let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7

    var days: [Date?] = Array(repeating: nil, count: leadingPadding)
    var d = monthInterval.start
    while d < monthInterval.end {
      days.append(d)
      guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
      d = next
    }
    return days
  }

  private var sidebarBg: Color {
    deepChrome ? ShapeTreeJournalPalette.sidebar : Color.secondary.opacity(0.04)
  }

  private let gridColumns = Array(repeating: GridItem(.flexible(minimum: 28), spacing: 6), count: 7)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Button(action: previousMonth) {
          Image(systemName: "chevron.left")
            .font(.caption.weight(.bold))
            .foregroundStyle(deepChrome ? ShapeTreeJournalPalette.accentBlue : Color.accentColor)
        }
        .buttonStyle(.plain)

        Text(Self.monthYearFormatter.string(from: calendarModel.currentMonth))
          .font(.headline.weight(.semibold))
          .foregroundStyle(deepChrome ? Color.white.opacity(0.92) : Color.primary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)

        Button(action: nextMonth) {
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(deepChrome ? ShapeTreeJournalPalette.accentBlue : Color.accentColor)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 8)

      if let calErr = journalModel.journalCalendarError, !calErr.isEmpty {
        Text(calErr)
          .font(.caption2)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 6)
          .padding(.bottom, 6)
      }

      LazyVGrid(columns: gridColumns, spacing: 6) {
        ForEach(Array(weekdayColumnLabels.enumerated()), id: \.offset) { _, symbol in
          Text(symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(deepChrome ? Color.white.opacity(0.42) : Color.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 2)
      .padding(.bottom, 4)

      LazyVGrid(columns: gridColumns, spacing: 6) {
        ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
          if let day {
            ShapeTreeJournalDayCell(
              date: day,
              isSelected: ShapeTreeJournalLocalFormatting.deviceCalendar.isDate(day, inSameDayAs: selectedDate),
              isToday: ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(day),
              hasEntry: calendarModel.entry(for: day) != nil,
              deepChrome: deepChrome
            ) {
              withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = day
              }
            }
          } else {
            Color.clear
              .frame(height: ShapeTreeJournalDayCell.cellHeight)
          }
        }
      }
      .padding(.horizontal, 2)
      .padding(.bottom, 4)
    }
    .padding(.horizontal, 4)
    .background(sidebarBg)
    .task(
      id: CalendarLoadIdentity(
        monthStart:
          ShapeTreeJournalLocalFormatting.deviceCalendar.dateInterval(of: .month, for: calendarModel.currentMonth)?
          .start
          .timeIntervalSince1970 ?? 0,
        nonce: calendarReloadNonce)
    ) {
      await calendarModel.loadEntries()
    }
  }

  private func previousMonth() {
    withAnimation(.easeInOut(duration: 0.18)) {
      calendarModel.previousMonth()
      selectedDate = ShapeTreeJournalLocalFormatting.constrainDayToMonth(
        dayFrom: selectedDate,
        monthStart: calendarModel.currentMonth)
    }
  }

  private func nextMonth() {
    withAnimation(.easeInOut(duration: 0.18)) {
      calendarModel.nextMonth()
      selectedDate = ShapeTreeJournalLocalFormatting.constrainDayToMonth(
        dayFrom: selectedDate,
        monthStart: calendarModel.currentMonth)
    }
  }
}

private struct ShapeTreeJournalDayCell: View {
  static let cellHeight: CGFloat = 42

  let date: Date
  let isSelected: Bool
  let isToday: Bool
  let hasEntry: Bool
  let deepChrome: Bool
  let action: () -> Void

  private var dayNumber: String {
    String(ShapeTreeJournalLocalFormatting.deviceCalendar.component(.day, from: date))
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        if isSelected {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
              deepChrome
                ? ShapeTreeJournalPalette.accentBlue.opacity(0.92)
                : Color.accentColor.opacity(0.28))
        } else if isToday {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(ShapeTreeJournalPalette.accentBlue, lineWidth: 1.5)
        } else if deepChrome {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        } else {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }

        VStack(spacing: 3) {
          Text(dayNumber)
            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
            .foregroundStyle(dayNumberColor)

          Circle()
            .fill(dotColor)
            .frame(width: 4, height: 4)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: Self.cellHeight)
    }
    #if os(macOS)
    .buttonStyle(.borderless)
    #else
    .buttonStyle(.plain)
    #endif
  }

  private var dayNumberColor: Color {
    if isSelected {
      return deepChrome ? Color.white : Color.primary
    }
    return deepChrome ? Color.white.opacity(0.93) : Color.primary
  }

  private var dotColor: Color {
    guard hasEntry else { return .clear }
    if isSelected {
      return deepChrome ? Color.white.opacity(0.9) : Color.accentColor
    }
    return ShapeTreeJournalPalette.accentBlue.opacity(deepChrome ? 0.9 : 0.85)
  }
}

// MARK: - Entry preview

private struct ShapeTreeJournalEntryPreviewView: View {
  let journalModel: ShapeTreeViewModel
  let date: Date
  let entryRefreshToken: UUID
  let deepChrome: Bool
  let onWriteToday: () -> Void

  @State private var isLoading = false
  @State private var detail: Components.Schemas.JournalEntryDetailResponse?
  @State private var loadError: String?

  private var entryLoadTaskId: String {
    "\(ShapeTreeJournalLocalFormatting.dayKey(for: date))-\(entryRefreshToken.uuidString)"
  }

  private var previewSectionFont: Font {
    #if os(macOS)
    .system(size: 17)
    #elseif os(iOS)
    .body
    #else
    .body
    #endif
  }

  private var entryPreviewEmptyMinHeight: CGFloat {
    #if os(iOS)
    120
    #else
    200
    #endif
  }

  var body: some View {
    Group {
      if isLoading {
        loadingBlock
      } else if let loadError {
        errorBlock(error: loadError)
      } else if let detail {
        entryDetailBlock(detail: detail)
      } else {
        emptyBlock
      }
    }
    .task(id: entryLoadTaskId) {
      await load()
    }
  }

  private var loadingBlock: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading entry...")
        .font(.caption)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.5) : Color.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func errorBlock(error: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.orange)
      Text(error)
        .font(.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.55) : Color.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func entryDetailBlock(detail: Components.Schemas.JournalEntryDetailResponse) -> some View {
    let wordText = detail.word_count == 1 ? "word" : "words"
    let lineText = detail.line_count == 1 ? "line" : "lines"

    return VStack(alignment: .leading, spacing: 16) {
      Text("\(detail.word_count) \(wordText) — \(detail.line_count) \(lineText)")
        #if os(iOS)
      .font(.caption)
        #else
      .font(.subheadline)
        #endif
        .foregroundStyle(deepChrome ? Color.white.opacity(0.45) : Color.secondary)

      JournalEntrySectionedBody(
        sections: JournalEntrySectioning.sections(from: detail.content),
        textFont: previewSectionFont,
        lineSpacing: 5,
        sectionSeparator: .scribeSpacing
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .tint(ShapeTreeJournalPalette.accentBlue)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var emptyBlock: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text")
        #if os(iOS)
      .font(.title2)
        #else
      .font(.largeTitle)
        #endif
        .foregroundStyle(deepChrome ? Color.white.opacity(0.38) : Color.secondary)
      Text("No entry for this date")
        .font(.subheadline)
        .foregroundStyle(deepChrome ? Color.white.opacity(0.5) : Color.secondary)

      if ShapeTreeJournalLocalFormatting.deviceCalendar.isDateInToday(date) {
        Button("Write today's entry") {
          onWriteToday()
        }
        .buttonStyle(.borderedProminent)
        .tint(ShapeTreeJournalPalette.accentBlue)
        .controlSize(.small)
      }
    }
    .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
  }

  private func load() async {
    isLoading = true
    loadError = nil
    detail = nil
    defer { isLoading = false }

    let key = ShapeTreeJournalLocalFormatting.dayKey(for: date)

    guard !journalModel.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      loadError = "Enter a ShapeTree server URL in Chat first."
      return
    }

    do {
      detail = try await journalModel.fetchJournalEntryDetailIfPresent(dayKey: key)
    } catch {
      loadError = error.localizedDescription
    }
  }
}
