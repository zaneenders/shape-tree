import SwiftUI

struct ShapeTreeTodoBreakDownExistingStep: Identifiable, Sendable {
  let id: String
  let title: String
  let subtaskCount: Int
  let displayStatus: ShapeTreeTodoDisplayStatus
}

/// Collects subtask titles for continuation-style decomposition of a parent todo.
struct ShapeTreeTodoBreakDownSheet: View {
  let parentTitle: String
  let existingSteps: [ShapeTreeTodoBreakDownExistingStep]
  @Binding var stepTitles: [String]
  let onCancel: () -> Void
  let onSave: () -> Void
  let onDrillIntoExisting: (String) -> Void
  let onDrillIntoNewStep: (Int) -> Void

  #if os(iOS)
  @FocusState private var focusedStepIndex: Int?
  #else
  @State private var focusedStepIndex: Int?
  @State private var focusGeneration = 0
  #endif

  var body: some View {
    NavigationStack {
      Form {
        introSection
        existingSection
        newStepsSection
      }
      .onAppear {
        if focusedStepIndex == nil, !stepTitles.isEmpty {
          focusStep(at: 0)
        }
      }
      .navigationTitle("Break down")
      #if os(macOS)
      .formStyle(.grouped)
      .frame(minWidth: 440, minHeight: existingSteps.isEmpty ? 300 : 380)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Skip", role: .cancel, action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save steps", action: onSave)
            .disabled(
              stepTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.allSatisfy(\.isEmpty)
            )
        }
      }
    }
  }

  private var introSection: some View {
    Section {
      Text("Split “\(parentTitle)” into smaller steps.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var existingSection: some View {
    if !existingSteps.isEmpty {
      Section {
        ForEach(existingSteps) { step in
          existingStepRow(step)
        }
      } header: {
        Text("Existing")
      } footer: {
        Text("New lines below are added alongside these.")
          .font(.caption)
      }
    }
  }

  private var newStepsSection: some View {
    Section {
      ForEach(stepTitles.indices, id: \.self) { index in
        stepField(at: index)
      }
      .onDelete { offsets in
        stepTitles.remove(atOffsets: offsets)
        clampFocusedStepIndex()
      }

      Button("Add line", systemImage: "plus") {
        appendStep(focus: true)
      }
    } footer: {
      Text("Tab or Return moves to the next line.")
        .font(.caption)
    }
  }

  @ViewBuilder
  private func stepField(at index: Int) -> some View {
    #if os(macOS)
    ShapeTreeTodoBreakDownStepField(
      text: $stepTitles[index],
      focusGeneration: focusedStepIndex == index ? focusGeneration : 0,
      onTab: { focusNextStep(from: index) },
      onShiftTab: { focusPreviousStep(from: index) },
      onBreakDown: { onDrillIntoNewStep(index) }
    )
    #else
    ShapeTreeTodoBreakDownStepField(
      text: $stepTitles[index],
      focusedStepIndex: $focusedStepIndex,
      index: index,
      requestFocus: focusedStepIndex == index,
      onTab: { focusNextStep(from: index) },
      onShiftTab: { focusPreviousStep(from: index) },
      onBreakDown: { onDrillIntoNewStep(index) }
    )
    #endif
  }

  private func existingStepRow(_ step: ShapeTreeTodoBreakDownExistingStep) -> some View {
    let statusColor = ShapeTreeTodoStatusStyle.color(for: step.displayStatus)

    return HStack(alignment: .center, spacing: 8) {
      VStack(alignment: .leading, spacing: 3) {
        Text(step.title)
          .lineLimit(2)

        if step.subtaskCount > 0 {
          Label(
            "\(step.subtaskCount) subtask\(step.subtaskCount == 1 ? "" : "s")",
            systemImage: "list.bullet.indent"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 8)

      Text(step.displayStatus.label)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(statusColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.18), in: Capsule())

      Button {
        onDrillIntoExisting(step.id)
      } label: {
        Image(systemName: "list.bullet.indent")
          .font(.body)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel("Break down \(step.title)")
      #if os(macOS)
      .help("Break down this step further")
      #endif
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(existingStepAccessibilityLabel(step))
  }

  private func focusStep(at index: Int) {
    guard stepTitles.indices.contains(index) else { return }
    #if os(iOS)
    focusedStepIndex = nil
    DispatchQueue.main.async {
      focusedStepIndex = index
    }
    #else
    focusedStepIndex = index
    focusGeneration += 1
    #endif
  }

  private func focusNextStep(from index: Int) {
    let next = index + 1
    if next < stepTitles.count {
      focusStep(at: next)
    } else {
      appendStep(focus: true)
    }
  }

  private func focusPreviousStep(from index: Int) {
    guard index > 0 else { return }
    focusStep(at: index - 1)
  }

  private func appendStep(focus: Bool) {
    stepTitles.append("")
    if focus {
      focusStep(at: stepTitles.count - 1)
    }
  }

  private func clampFocusedStepIndex() {
    guard let focused = focusedStepIndex else { return }
    if stepTitles.isEmpty {
      focusedStepIndex = nil
    } else if focused >= stepTitles.count {
      focusStep(at: stepTitles.count - 1)
    }
  }

  private func existingStepAccessibilityLabel(_ step: ShapeTreeTodoBreakDownExistingStep) -> String {
    var parts = [step.title, step.displayStatus.label]
    if step.subtaskCount > 0 {
      parts.append("\(step.subtaskCount) subtasks")
    }
    return parts.joined(separator: ", ")
  }
}
