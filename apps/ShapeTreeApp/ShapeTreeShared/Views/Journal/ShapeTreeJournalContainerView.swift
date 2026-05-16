import ShapeTreeClient
import SwiftUI

#if os(macOS)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum ShapeTreeJournalPalette {
  static let accentBlue = Color(red: 0, green: 122 / 255, blue: 1)
  static let sidebar = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
  static let contentPanel = Color(red: 18 / 255, green: 18 / 255, blue: 19 / 255)
  static let entryCard = Color(red: 40 / 255, green: 40 / 255, blue: 42 / 255)
  static let hairline = Color.white.opacity(0.08)
}

// MARK: - Local journal day keys (device calendar — matches `journal_day` on append)

enum ShapeTreeJournalLocalFormatting {
  static var deviceCalendar: Calendar { .autoupdatingCurrent }

  static func dayTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.autoupdatingCurrent
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  /// Device-calendar `yy-MM-dd`; matches the `journal_day` key the view model sends on append.
  static func dayKey(for date: Date) -> String {
    JournalPathCodec.journalDayKey(for: date, calendar: deviceCalendar)
  }

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
final class ShapeTreeJournalCalendarModel {
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
