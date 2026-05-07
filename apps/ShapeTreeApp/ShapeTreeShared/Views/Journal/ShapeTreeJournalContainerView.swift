import ShapeTreeClient
import SwiftUI

// MARK: - UTC journal day keys (aligned with server paths)

private enum ShapeTreeJournalUTCFormatting {
  static var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }

  static func dayKey(for date: Date) -> String {
    let cal = utcCalendar
    let yy = cal.component(.year, from: date) % 100
    let mm = cal.component(.month, from: date)
    let dd = cal.component(.day, from: date)
    return String(format: "%02d-%02d-%02d", yy, mm, dd)
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
    entriesByDay[ShapeTreeJournalUTCFormatting.dayKey(for: date)]
  }

  func loadEntries() async {
    let calendar = Calendar.current
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
      let startDate = calendar.date(byAdding: .day, value: -7, to: monthInterval.start),
      let endDate = calendar.date(byAdding: .day, value: 7, to: monthInterval.end)
    else { return }

    let startKey = ShapeTreeJournalUTCFormatting.dayKey(for: startDate)
    let endKey = ShapeTreeJournalUTCFormatting.dayKey(for: endDate)

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
    } catch {
      entriesByDay = [:]
    }
  }

  func previousMonth() {
    guard let d = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return }
    currentMonth = d
  }

  func nextMonth() {
    guard let d = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) else { return }
    currentMonth = d
  }
}

// MARK: - Container

struct ShapeTreeJournalContainerView: View {
  @Bindable var journalModel: ShapeTreeViewModel

  @State private var selectedDate: Date = Date()
  @State private var scrollOffset: CGFloat = 0
  @State private var isTodayComposerVisible = false
  @State private var entryRefreshToken = UUID()
  @State private var calendarReloadNonce = 0
  @State private var scrollToTopTrigger: UUID?

  private static let journalComposerBottomId = "journalComposerBottom"

  private var showsJournalFloatingOverlays: Bool {
    guard Calendar.current.isDateInToday(selectedDate) else { return false }
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

  var body: some View {
    coreLayout
      .onChange(of: journalModel.journalStatus) { _, newStatus in
        guard let newStatus,
          newStatus.localizedCaseInsensitiveContains("saved markdown")
        else { return }
        entryRefreshToken = UUID()
        calendarReloadNonce += 1
        dismissTodayComposer()
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
          journalModel: journalModel,
          calendarReloadNonce: calendarReloadNonce,
          selectedDate: $selectedDate,
          onDateSelected: { date in
            withAnimation {
              selectedDate = date
            }
          }
        )
        .frame(maxWidth: 360)
        .padding()
      }
      .frame(maxWidth: 400)
      .background(Color.secondary.opacity(0.03))

      Divider()

      ScrollViewReader { proxy in
        ZStack(alignment: .bottomTrailing) {
          ScrollView {
            VStack(alignment: .leading, spacing: 12) {
              dateHeaderMac

              ShapeTreeJournalEntryPreviewView(
                journalModel: journalModel,
                date: selectedDate,
                entryRefreshToken: entryRefreshToken,
                onWriteToday: { openComposerAndScrollToBottom(proxy: proxy) }
              )

              if Calendar.current.isDateInToday(selectedDate), isTodayComposerVisible {
                ShapeTreeJournalEntryComposer(viewModel: journalModel)
                  .shapeTreeJournalInlineComposerChrome()
              }

              Spacer(minLength: journalScrollBottomSpacerMinLength)

              Color.clear
                .frame(height: 1)
                .id(Self.journalComposerBottomId)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
          }

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
      if !Calendar.current.isDateInToday(newDate) {
        dismissTodayComposer()
      }
    }
  }

  @ViewBuilder
  private var iOSLayout: some View {
    ZStack(alignment: .top) {
      ScrollViewReader { proxy in
        ZStack(alignment: .bottomTrailing) {
          ScrollView {
            VStack(spacing: 0) {
              ShapeTreeJournalCalendarSection(
                journalModel: journalModel,
                calendarReloadNonce: calendarReloadNonce,
                selectedDate: $selectedDate,
                onDateSelected: { date in
                  withAnimation {
                    selectedDate = date
                  }
                }
              )
              .id("calendar")

              VStack(alignment: .leading, spacing: 8) {
                dateHeaderIOS

                ShapeTreeJournalEntryPreviewView(
                  journalModel: journalModel,
                  date: selectedDate,
                  entryRefreshToken: entryRefreshToken,
                  onWriteToday: { openComposerAndScrollToBottom(proxy: proxy) }
                )
                .padding(.horizontal)

                if Calendar.current.isDateInToday(selectedDate), isTodayComposerVisible {
                  ShapeTreeJournalEntryComposer(viewModel: journalModel)
                    .shapeTreeJournalInlineComposerChrome()
                    .padding(.horizontal)
                }

                Spacer(minLength: journalScrollBottomSpacerMinLength)

                Color.clear
                  .frame(height: 1)
                  .id(Self.journalComposerBottomId)
              }
              #if os(iOS)
              .background(Color(.systemBackground))
              #endif
            }
          }
          #if os(iOS)
          .scrollDismissesKeyboard(.interactively)
          .safeAreaPadding(.bottom, isTodayComposerVisible ? 8 : 2)
          #endif
          .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
          } action: { _, offset in
            scrollOffset = offset
          }
          .onChange(of: scrollToTopTrigger) { _, _ in
            withAnimation(.smooth) {
              proxy.scrollTo("calendar", anchor: .top)
            }
          }

          if showsJournalFloatingOverlays {
            VStack(alignment: .trailing, spacing: 12) {
              if scrollOffset > 300 {
                Button {
                  scrollToTopTrigger = UUID()
                } label: {
                  HStack(spacing: 6) {
                    Image(systemName: "chevron.up")
                    Text("Calendar")
                  }
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .background(
                    Capsule()
                      .fill(Color.accentColor)
                  )
                  .shadow(radius: 4, x: 0, y: 2)
                }
              }

              ShapeTreeJournalFloatingEditButton(isComposerVisible: isTodayComposerVisible) {
                floatingEditTapped(proxy: proxy)
              }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 8)
          }
        }
      }
    }
    .onChange(of: selectedDate) { _, newDate in
      if !Calendar.current.isDateInToday(newDate) {
        dismissTodayComposer()
      }
    }
  }

  private var dateHeaderMac: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(selectedDate.formatted(date: .complete, time: .omitted))
          .font(.title2)
          .fontWeight(.bold)

        if Calendar.current.isDateInToday(selectedDate) {
          Text("Today")
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
            .fontWeight(.medium)
        }
      }
      Spacer()
    }
    .padding(.top, 12)
  }

  private var dateHeaderIOS: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(selectedDate.formatted(date: .complete, time: .omitted))
          .font(.title3)
          .fontWeight(.bold)

        if Calendar.current.isDateInToday(selectedDate) {
          Text("Today")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
      }
      Spacer()
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  private func openTodayComposer() {
    guard !isTodayComposerVisible else { return }
    journalModel.journalDraft = ""
    journalModel.journalError = nil
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
      Image(systemName: isComposerVisible ? "xmark.circle.fill" : "square.and.pencil")
        .font(.system(size: 20, weight: .semibold))
        .frame(width: 52, height: 52)
    }
    .buttonStyle(.borderedProminent)
    .tint(.accentColor)
    .clipShape(Circle())
    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
  }
}

// MARK: - Calendar section

private struct CalendarLoadIdentity: Equatable {
  var monthStart: TimeInterval
  var nonce: Int
}

private struct ShapeTreeJournalCalendarSection: View {
  let journalModel: ShapeTreeViewModel
  let calendarReloadNonce: Int
  @Binding var selectedDate: Date
  let onDateSelected: (Date) -> Void

  @State private var calendarModel: ShapeTreeJournalCalendarModel

  init(
    journalModel: ShapeTreeViewModel,
    calendarReloadNonce: Int,
    selectedDate: Binding<Date>,
    onDateSelected: @escaping (Date) -> Void
  ) {
    self.journalModel = journalModel
    self.calendarReloadNonce = calendarReloadNonce
    self._selectedDate = selectedDate
    self.onDateSelected = onDateSelected
    self._calendarModel = State(initialValue: ShapeTreeJournalCalendarModel(journalModel: journalModel))
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Button(action: previousMonth) {
          Image(systemName: "chevron.left")
            .font(.body)
            .foregroundStyle(Color.accentColor)
        }

        Spacer()

        Text(monthYearString)
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundStyle(Color.primary)

        Spacer()

        Button(action: nextMonth) {
          Image(systemName: "chevron.right")
            .font(.body)
            .foregroundStyle(Color.accentColor)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(Color.secondary.opacity(0.05))

      HStack {
        ForEach(weekdaySymbols, id: \.self) { symbol in
          Text(symbol)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 8)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
        ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
          if let date {
            ShapeTreeJournalDayCell(
              date: date,
              isToday: isToday(date),
              isSelected: isSelected(date),
              entrySummary: calendarModel.entry(for: date)
            )
            .frame(height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
              onDateSelected(date)
            }
          } else {
            Color.clear
              .frame(height: 44)
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, 4)
      .padding(.bottom, 8)
    }
    .task(
      id: CalendarLoadIdentity(
        monthStart:
          Calendar.current.dateInterval(of: .month, for: calendarModel.currentMonth)?.start.timeIntervalSince1970 ?? 0,
        nonce: calendarReloadNonce)
    ) {
      await calendarModel.loadEntries()
    }
  }

  private var monthYearString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: calendarModel.currentMonth)
  }

  private var weekdaySymbols: [String] {
    DateFormatter().shortWeekdaySymbols
  }

  private var daysInMonth: [Date?] {
    let calendar = Calendar.current
    let month = calendarModel.currentMonth

    guard let monthInterval = calendar.dateInterval(of: .month, for: month),
      let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
    else {
      return []
    }

    var dates: [Date?] = []
    var currentDate = firstWeek.start

    while currentDate < monthInterval.start {
      dates.append(nil)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
    }

    while currentDate < monthInterval.end {
      dates.append(currentDate)
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
    }

    while dates.count % 7 != 0 {
      dates.append(nil)
    }

    return dates
  }

  private func isToday(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date)
  }

  private func isSelected(_ date: Date) -> Bool {
    Calendar.current.isDate(date, inSameDayAs: selectedDate)
  }

  private func previousMonth() {
    withAnimation {
      calendarModel.previousMonth()
    }
  }

  private func nextMonth() {
    withAnimation {
      calendarModel.nextMonth()
    }
  }
}

// MARK: - Entry preview

private struct ShapeTreeJournalEntryPreviewView: View {
  let journalModel: ShapeTreeViewModel
  let date: Date
  let entryRefreshToken: UUID
  let onWriteToday: () -> Void

  @State private var isLoading = false
  @State private var detail: Components.Schemas.JournalEntryDetailResponse?
  @State private var loadError: String?

  private var entryLoadTaskId: String {
    "\(ShapeTreeJournalUTCFormatting.dayKey(for: date))-\(entryRefreshToken.uuidString)"
  }

  private var previewSectionFont: Font {
    #if os(macOS)
      .system(size: 18)
    #elseif os(iOS)
      .system(.body, design: .monospaced)
    #else
      .body
    #endif
  }

  private var entryPreviewCardPadding: CGFloat {
    #if os(iOS)
      10
    #else
      16
    #endif
  }

  private var entryPreviewCardCornerRadius: CGFloat {
    #if os(iOS)
      8
    #else
      12
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
        VStack(spacing: 12) {
          ProgressView()
          Text("Loading entry...")
            .font(.caption)
            .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
      } else if let loadError {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundStyle(.orange)
          Text(loadError)
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
      } else if let detail {
        VStack(alignment: .leading, spacing: 8) {
          let wordText = detail.word_count == 1 ? "word" : "words"
          let lineText = detail.line_count == 1 ? "line" : "lines"
          Text("\(detail.word_count) \(wordText) · \(detail.line_count) \(lineText)")
            #if os(iOS)
            .font(.caption)
            #else
            .font(.subheadline)
            #endif
            .foregroundStyle(Color.secondary)

          Divider()

          JournalEntrySectionedBody(
            sections: JournalEntrySectioning.sections(from: detail.content),
            textFont: previewSectionFont,
            lineSpacing: 4
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(entryPreviewCardPadding)
        .background(
          RoundedRectangle(cornerRadius: entryPreviewCardCornerRadius)
            .fill(Color.secondary.opacity(0.05))
        )
      } else {
        VStack(spacing: 12) {
          Image(systemName: "doc.text")
            #if os(iOS)
            .font(.title2)
            #else
            .font(.largeTitle)
            #endif
            .foregroundStyle(Color.secondary)
          Text("No entry for this date")
            .font(.subheadline)
            .foregroundStyle(Color.secondary)

          if Calendar.current.isDateInToday(date) {
            Button("Write today's entry") {
              onWriteToday()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
          }
        }
        .frame(maxWidth: .infinity, minHeight: entryPreviewEmptyMinHeight)
      }
    }
    .task(id: entryLoadTaskId) {
      await load()
    }
  }

  private func load() async {
    isLoading = true
    loadError = nil
    detail = nil
    defer { isLoading = false }

    let key = ShapeTreeJournalUTCFormatting.dayKey(for: date)

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

// MARK: - Day cell

private struct ShapeTreeJournalDayCell: View {
  let date: Date
  let isToday: Bool
  let isSelected: Bool
  let entrySummary: Components.Schemas.JournalEntrySummary?

  private var dayNumber: String {
    String(Calendar.current.component(.day, from: date))
  }

  private var dotSize: CGFloat {
    guard let summary = entrySummary else { return 4 }
    let size = min(8, max(4, CGFloat(summary.word_count) / 50))
    return size
  }

  var body: some View {
    ZStack {
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .fill(Color.accentColor.opacity(0.2))
      } else if isToday {
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.accentColor, lineWidth: 2)
      } else {
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
      }

      VStack(spacing: 2) {
        Text(dayNumber)
          .font(.callout)
          .fontWeight(isToday || isSelected ? .bold : .regular)
          .foregroundStyle(isSelected ? Color.accentColor : (isToday ? Color.accentColor : Color.primary))

        Circle()
          .fill(entrySummary != nil ? Color.accentColor : Color.clear)
          .frame(width: dotSize, height: dotSize)
      }
    }
  }
}
