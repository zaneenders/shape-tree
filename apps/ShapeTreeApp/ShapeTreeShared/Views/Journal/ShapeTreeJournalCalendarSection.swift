import ShapeTreeClient
import SwiftUI

/// Re-fires `task(id:)` whenever the visible month changes or a calendar reload is requested.
struct CalendarLoadIdentity: Equatable {
  var monthStart: TimeInterval
  var nonce: Int
}

struct ShapeTreeJournalCalendarSection: View {
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
      monthHeader

      if let calErr = journalModel.journalCalendarError, !calErr.isEmpty {
        Text(calErr)
          .font(.caption2)
          .foregroundStyle(.orange)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 6)
          .padding(.bottom, 6)
      }

      weekdayHeaderRow
      dayGrid
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

  private var monthHeader: some View {
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
  }

  private var weekdayHeaderRow: some View {
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
  }

  private var dayGrid: some View {
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

struct ShapeTreeJournalDayCell: View {
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
        backgroundShape

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

  @ViewBuilder
  private var backgroundShape: some View {
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
