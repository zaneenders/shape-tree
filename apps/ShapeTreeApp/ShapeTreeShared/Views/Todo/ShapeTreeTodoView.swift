import NodeTreeAPI
import SwiftUI

enum ShapeTreeTodoPalette {
  static let accentBlue = Color(red: 0, green: 122 / 255, blue: 1)
  static let sidebar = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
  static let contentPanel = Color(red: 18 / 255, green: 18 / 255, blue: 19 / 255)
  static let hairline = Color.white.opacity(0.08)
}

struct ShapeTreeTodoView: View {
  @Bindable var viewModel: ShapeTreeViewModel
  @Environment(\.colorScheme) private var colorScheme

  @State private var selectedItemID: String?
  @State private var editTitle: String = ""
  @State private var editNotes: String = ""
  @State private var editStatus: ShapeTreeViewModel.TodoItemStatus = .open
  @State private var newItemTitle: String = ""
  @State private var reloadNonce = 0
  @State private var breakDownItem: ShapeTreeViewModel.TodoItem?
  @State private var breakDownSteps: [String] = [""]
  @State private var breakDownExistingSteps: [ShapeTreeTodoBreakDownExistingStep] = []
  @State private var showArchivedItems = false

  private var deepChrome: Bool { colorScheme == .dark }

  private var treeRoots: [ShapeTreeTodoDisplayNode] {
    ShapeTreeTodoTree.roots(from: viewModel.todoItems, showArchived: showArchivedItems)
  }

  private var archivedItems: [ShapeTreeViewModel.TodoItem] {
    ShapeTreeTodoTree.archivedItems(from: viewModel.todoItems)
  }

  private var activeItemCount: Int {
    ShapeTreeTodoTree.activeItems(from: viewModel.todoItems).count
  }

  private var selectedItem: ShapeTreeViewModel.TodoItem? {
    guard let selectedItemID else { return nil }
    return viewModel.todoItems.first { $0.id == selectedItemID }
  }

  private var addParentID: Components.Schemas.ParentId {
    .root(.init(kind: .root))
  }

  private var composerAttachmentHint: String? {
    "Adds to top level"
  }

  private var showsComposer: Bool {
    viewModel.connectionState == .online
  }

  var body: some View {
    ZStack {
      coreLayout

      if viewModel.isTodoWorking {
        ZStack {
          Color.black.opacity(0.06)
          ProgressView("Working…")
            .padding(.vertical, 28)
            .padding(.horizontal, 40)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
    .task(id: reloadNonce) {
      await viewModel.refreshTodoItems()
      syncEditorFromSelection()
    }
    .onChange(of: viewModel.connectionState) { oldState, newState in
      guard oldState != .online, newState == .online else { return }
      reloadNonce += 1
    }
    .onChange(of: selectedItemID) { _, _ in
      syncEditorFromSelection()
    }
    .sheet(item: $breakDownItem) { item in
      ShapeTreeTodoBreakDownSheet(
        parentTitle: item.title,
        existingSteps: breakDownExistingSteps,
        stepTitles: $breakDownSteps,
        onCancel: { breakDownItem = nil },
        onSave: {
          Task {
            if await viewModel.breakDownTodoItem(id: item.id, stepTitles: breakDownSteps) != nil {
              breakDownItem = nil
              reloadNonce += 1
            }
          }
        },
        onDrillIntoExisting: { childID in
          Task { await drillIntoExistingBreakDown(childID: childID) }
        },
        onDrillIntoNewStep: { index in
          Task { await drillIntoNewStepBreakDown(at: index) }
        }
      )
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

  private var panelBackground: Color {
    if deepChrome { return ShapeTreeTodoPalette.contentPanel }
    #if os(macOS)
    return Color(nsColor: .textBackgroundColor)
    #elseif canImport(UIKit)
    return Color(uiColor: .systemBackground)
    #else
    return Color(white: 0.95)
    #endif
  }

  private var sidebarBackground: Color {
    if deepChrome { return ShapeTreeTodoPalette.sidebar }
    return Color(white: deepChrome ? 0.12 : 0.96)
  }

  // MARK: - macOS

  private var macOSLayout: some View {
    HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        todoHeader
        Divider().overlay(ShapeTreeTodoPalette.hairline)
        listScroll
        if showsComposer {
          Divider().overlay(ShapeTreeTodoPalette.hairline)
          todoComposer
        }
      }
      .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
      .background(sidebarBackground)

      Divider().overlay(ShapeTreeTodoPalette.hairline)

      detailPanel
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(panelBackground)
    }
  }

  // MARK: - iOS

  private var iOSLayout: some View {
    VStack(spacing: 0) {
      todoHeader
      Divider()
      listScroll
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      if selectedItem != nil {
        iosListDetailSeparator
        iosDetailPanel
      }
      if showsComposer {
        Divider()
        todoComposer
      }
    }
    .background(panelBackground)
  }

  private var iosListDetailSeparator: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(Color.primary.opacity(0.12))
        .frame(height: 1)
      LinearGradient(
        colors: [Color.primary.opacity(0.06), Color.clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 10)
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder
  private var iosDetailPanel: some View {
    ScrollView {
      selectedDetailEditor
        .padding(16)
    }
    .frame(maxWidth: .infinity, maxHeight: 300)
    .background(iosDetailPanelBackground)
  }

  private var iosDetailPanelBackground: Color {
    #if canImport(UIKit)
    Color(uiColor: .secondarySystemGroupedBackground)
    #else
    panelBackground
    #endif
  }

  private var todoHeader: some View {
    HStack(alignment: .center, spacing: 8) {
      Group {
        if let todoError = viewModel.todoError {
          Text(todoError)
            .foregroundStyle(.red)
        } else {
          Text(activeListStatusLine)
            .foregroundStyle(.secondary)
        }
      }
      .font(.caption)
      .lineLimit(2)
      .frame(maxWidth: .infinity, alignment: .leading)

      if !archivedItems.isEmpty {
        showArchivedChip
      }

      Button {
        reloadNonce += 1
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.caption)
      }
      .buttonStyle(.borderless)
      .disabled(viewModel.connectionState != .online)
      .accessibilityLabel("Reload todos")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var activeListStatusLine: String {
    let archivedCount = archivedItems.count
    if archivedCount > 0, !showArchivedItems {
      return "\(activeItemCount) active · \(archivedCount) hidden"
    }
    return viewModel.todoStatus ?? "\(activeItemCount) active"
  }

  private var showArchivedChip: some View {
    Button {
      showArchivedItems.toggle()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: showArchivedItems ? "archivebox.fill" : "archivebox")
          .font(.caption2)
        Text(showArchivedItems ? "On" : "\(archivedItems.count)")
          .font(.caption2.weight(.semibold))
          .monospacedDigit()
      }
      .foregroundStyle(showArchivedItems ? ShapeTreeTodoPalette.accentBlue : .secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        showArchivedItems
          ? ShapeTreeTodoPalette.accentBlue.opacity(0.14)
          : Color.primary.opacity(0.06),
        in: Capsule()
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(showArchivedItems ? "Hide archived todos" : "Show archived todos")
    #if os(macOS)
    .help(showArchivedItems ? "Hide archived items in the list" : "Show archived items inline")
    #endif
  }

  private var todoComposer: some View {
    ShapeTreeTodoComposerView(
      text: $newItemTitle,
      attachmentHint: composerAttachmentHint,
      isFieldDisabled: viewModel.connectionState != .online,
      isSendDisabled: viewModel.connectionState != .online || viewModel.isTodoWorking,
      onSend: { await addItem() }
    )
  }

  private var listScroll: some View {
    Group {
      if viewModel.connectionState != .online {
        todoCompactPlaceholder(
          title: "Offline",
          systemImage: "wifi.slash",
          description: "Connect to your ShapeTree server to load todos."
        )
      } else if treeRoots.isEmpty && !viewModel.isTodoWorking {
        todoCompactPlaceholder(
          title: "No todos yet",
          systemImage: "checklist",
          description: archivedItems.isEmpty
            ? "Type below to add your first todo."
            : "Turn on Show archived to see archived items, or add a new todo below."
        )
      } else {
        todoTreeList
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var todoTreeList: some View {
    List(selection: $selectedItemID) {
      OutlineGroup(treeRoots, children: \.outlineChildren) { node in
        todoRowLabel(node)
      }
    }
    #if os(macOS)
    .listStyle(.sidebar)
    #else
    .listStyle(.plain)
    #endif
  }

  private func todoRowLabel(_ node: ShapeTreeTodoDisplayNode) -> some View {
    let displayStatus = ShapeTreeTodoStatusStyle.displayStatus(
      for: node.item,
      items: viewModel.todoItems
    )
    let statusColor = ShapeTreeTodoStatusStyle.color(for: displayStatus)
    let hasChildren = ShapeTreeTodoTree.hasChildren(itemID: node.id, items: viewModel.todoItems)

    return HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(statusColor)
        .frame(width: 3)
        .padding(.vertical, 3)

      HStack(spacing: 8) {
        statusLeadingControls(
          item: node.item,
          displayStatus: displayStatus,
          color: statusColor,
          hasChildren: hasChildren
        )

        Text(node.item.title)
        .strikethrough(displayStatus == .completed || displayStatus == .archived)
        .foregroundStyle(displayStatus == .archived ? .secondary : .primary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.leading, 8)
    }
    .tag(node.id)
    .todoRowActions(
      item: node.item,
      onArchive: { Task { await archiveItem(node.item) } },
      onRestore: { Task { await restoreItem(node.item) } }
    )
  }

  @ViewBuilder
  private func statusLeadingControls(
    item: ShapeTreeViewModel.TodoItem,
    displayStatus: ShapeTreeTodoDisplayStatus,
    color: Color,
    hasChildren: Bool
  ) -> some View {
    if hasChildren {
      statusBadge(label: displayStatus.label, color: color)
    } else if item.status == .archive {
      Button {
        Task { await restoreItem(item) }
      } label: {
        Image(systemName: "arrow.uturn.backward.circle")
          .font(.system(size: 18))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .disabled(viewModel.connectionState != .online)
      .accessibilityLabel("Restore to active")
    } else {
      HStack(spacing: 2) {
        Button {
          Task { await viewModel.toggleTodoCompleted(item) }
        } label: {
          Image(
            systemName: item.status == .completed ? "checkmark.circle.fill" : "circle"
          )
          .font(.system(size: 18))
          .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.connectionState != .online)
        .accessibilityLabel(item.status == .completed ? "Mark incomplete" : "Mark complete")

        Button {
          Task { await archiveItem(item) }
        } label: {
          Image(systemName: "archivebox")
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.connectionState != .online)
        .accessibilityLabel("Archive")
        #if os(macOS)
        .help("Archive")
        #endif
      }
    }
  }

  private func statusBadge(label: String, color: Color) -> some View {
    Text(label)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(color.opacity(0.18), in: Capsule())
  }

  @ViewBuilder
  private var selectedDetailEditor: some View {
    if let selectedItem {
      let hasChildren = ShapeTreeTodoTree.hasChildren(
        itemID: selectedItem.id,
        items: viewModel.todoItems
      )
      let displayStatus = ShapeTreeTodoStatusStyle.displayStatus(
        for: selectedItem,
        items: viewModel.todoItems
      )
      let statusColor = ShapeTreeTodoStatusStyle.color(for: displayStatus)
      let canComplete = ShapeTreeTodoTree.canMarkCompleted(
        itemID: selectedItem.id,
        items: viewModel.todoItems
      )
      let isArchived = selectedItem.status == .archive

      VStack(alignment: .leading, spacing: 16) {
        Text(isArchived ? "Archived todo" : "Edit todo")
          .font(.title2.weight(.semibold))

        if isArchived {
          Text("Restore this item to return it to your active list.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Button("Restore to active", systemImage: "arrow.uturn.backward") {
            Task { await restoreItem(selectedItem) }
          }
        } else if hasChildren {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Text("Status")
                .font(.subheadline.weight(.medium))
              statusBadge(label: displayStatus.label, color: statusColor)
            }
            Text(
              canComplete
                ? "All subtasks are settled."
                : "Based on subtasks — finish or archive them to complete this item."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if canComplete, (selectedItem.status ?? .open) != .completed {
              Button("Mark complete", systemImage: "checkmark.circle") {
                Task {
                  _ = await viewModel.updateTodoItem(id: selectedItem.id, status: .completed)
                  reloadNonce += 1
                }
              }
            }
          }
        } else {
          statusEditor(
            selection: $editStatus,
            canComplete: canComplete
          )
        }

        TextField("Title", text: $editTitle)
          .textFieldStyle(.roundedBorder)

        TextField("Notes", text: $editNotes, axis: .vertical)
          .lineLimit(4...12)
          .textFieldStyle(.roundedBorder)

        HStack {
          Button("Save", systemImage: "square.and.arrow.down") {
            Task { await saveSelected() }
          }
          .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)

          if displayStatus != .completed && displayStatus != .archived {
            Button("Break down…", systemImage: "list.bullet.indent") {
              presentBreakDown(for: selectedItem)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  @ViewBuilder
  private var detailPanel: some View {
    if selectedItem != nil {
      selectedDetailEditor
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      todoCompactPlaceholder(
        title: "Select a todo",
        systemImage: "checklist",
        description: "Choose an item in the tree to edit it.",
        topLeading: true
      )
      .padding(20)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private func todoCompactPlaceholder(
    title: String,
    systemImage: String,
    description: String,
    topLeading: Bool = false
  ) -> some View {
    VStack(alignment: topLeading ? .leading : .center, spacing: 6) {
      Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
      Text(description)
        .font(.caption)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(topLeading ? .leading : .center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: topLeading ? .topLeading : .center)
  }

  private func syncEditorFromSelection() {
    guard let item = selectedItem else {
      editTitle = ""
      editNotes = ""
      editStatus = .open
      return
    }
    editTitle = item.title
    editNotes = item.notes ?? ""
    editStatus = item.status ?? .open
  }

  private func presentBreakDown(for item: ShapeTreeViewModel.TodoItem) {
    breakDownExistingSteps = existingBreakDownSteps(for: item)
    breakDownSteps = [""]
    breakDownItem = item
  }

  private func drillIntoExistingBreakDown(childID: String) async {
    guard let parent = breakDownItem else { return }
    if await savePendingBreakDownSteps(for: parent) == nil,
      !breakDownSteps.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).allSatisfy(\.isEmpty)
    {
      return
    }
    guard let child = viewModel.todoItems.first(where: { $0.id == childID }) else { return }
    presentBreakDown(for: child)
  }

  private func drillIntoNewStepBreakDown(at stepIndex: Int) async {
    guard let parent = breakDownItem, stepIndex < breakDownSteps.count else { return }

    let nonEmptyEntries = breakDownSteps.enumerated().compactMap { index, title -> Int? in
      title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : index
    }
    guard let createdIndex = nonEmptyEntries.firstIndex(of: stepIndex) else { return }

    guard let created = await savePendingBreakDownSteps(for: parent) else { return }
    guard createdIndex < created.count else { return }

    presentBreakDown(for: created[createdIndex])
  }

  @discardableResult
  private func savePendingBreakDownSteps(
    for parent: ShapeTreeViewModel.TodoItem
  ) async -> [ShapeTreeViewModel.TodoItem]? {
    let hasPending = !breakDownSteps
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .allSatisfy(\.isEmpty)
    guard hasPending else { return [] }
    let created = await viewModel.breakDownTodoItem(id: parent.id, stepTitles: breakDownSteps)
    if created != nil {
      reloadNonce += 1
      breakDownExistingSteps = existingBreakDownSteps(for: parent)
    }
    return created
  }

  private func existingBreakDownSteps(
    for item: ShapeTreeViewModel.TodoItem
  ) -> [ShapeTreeTodoBreakDownExistingStep] {
    ShapeTreeTodoTree.sortedDirectChildren(parentID: item.id, items: viewModel.todoItems).map { child in
      let subtaskCount = ShapeTreeTodoTree.directChildren(
        parentID: child.id,
        items: viewModel.todoItems
      ).count
      return ShapeTreeTodoBreakDownExistingStep(
        id: child.id,
        title: child.title,
        subtaskCount: subtaskCount,
        displayStatus: ShapeTreeTodoStatusStyle.displayStatus(
          for: child,
          items: viewModel.todoItems
        )
      )
    }
  }

  private func addItem() async {
    let title = newItemTitle
    let parent = addParentID
    let created = await viewModel.createTodoItem(title: title, parentID: parent)
    if created != nil {
      newItemTitle = ""
    }
  }

  private func statusEditor(
    selection: Binding<ShapeTreeViewModel.TodoItemStatus>,
    canComplete: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Status")
        .font(.subheadline.weight(.medium))

      HStack(spacing: 6) {
        statusEditChip(
          title: "Open",
          displayStatus: ShapeTreeTodoDisplayStatus.open,
          isSelected: selection.wrappedValue == .open,
          action: { selection.wrappedValue = .open }
        )
        statusEditChip(
          title: "Completed",
          displayStatus: ShapeTreeTodoDisplayStatus.completed,
          isSelected: selection.wrappedValue == .completed,
          isDisabled: !canComplete,
          action: { selection.wrappedValue = .completed }
        )
        statusEditChip(
          title: "Archive",
          displayStatus: ShapeTreeTodoDisplayStatus.archived,
          isSelected: selection.wrappedValue == .archive,
          action: { selection.wrappedValue = .archive }
        )
      }

      if !canComplete {
        Text("Complete subtasks or archive them before marking this done.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func statusEditChip(
    title: String,
    displayStatus: ShapeTreeTodoDisplayStatus,
    isSelected: Bool,
    isDisabled: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    let color = ShapeTreeTodoStatusStyle.color(for: displayStatus)
    return Button(action: action) {
      Text(title)
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? color : .secondary)
        .background(
          isSelected ? color.opacity(0.22) : Color.primary.opacity(0.06),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(isSelected ? color.opacity(0.55) : Color.clear, lineWidth: 1)
        }
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }

  private func saveSelected() async {
    guard let id = selectedItemID else { return }
    let notes = editNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasChildren = ShapeTreeTodoTree.hasChildren(itemID: id, items: viewModel.todoItems)
    let ok = await viewModel.updateTodoItem(
      id: id,
      title: editTitle.trimmingCharacters(in: .whitespacesAndNewlines),
      status: hasChildren ? nil : editStatus,
      notes: notes.isEmpty ? nil : notes
    )
    if ok {
      reloadNonce += 1
    }
  }

  private func archiveItem(_ item: ShapeTreeViewModel.TodoItem) async {
    let ok = await viewModel.archiveTodoItem(item)
    if ok {
      if selectedItemID == item.id { selectedItemID = nil }
      reloadNonce += 1
    }
  }

  private func restoreItem(_ item: ShapeTreeViewModel.TodoItem) async {
    let ok = await viewModel.restoreTodoItem(item)
    if ok {
      selectedItemID = item.id
      reloadNonce += 1
    }
  }
}

extension ShapeTreeViewModel.TodoItem: Identifiable {}

// MARK: - Swipe & context menu

private extension View {
  @ViewBuilder
  func todoRowActions(
    item: ShapeTreeViewModel.TodoItem,
    onArchive: @escaping () -> Void,
    onRestore: @escaping () -> Void
  ) -> some View {
    let isArchived = item.status == .archive
    self
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        if isArchived {
          Button(action: onRestore) {
            Label("Restore", systemImage: "arrow.uturn.backward")
          }
          .tint(ShapeTreeTodoPalette.accentBlue)
        } else {
          Button(role: .none, action: onArchive) {
            Label("Archive", systemImage: "archivebox")
          }
          .tint(.gray)
        }
      }
      .contextMenu {
        if isArchived {
          Button("Restore to active", systemImage: "arrow.uturn.backward", action: onRestore)
        } else {
          Button("Archive", systemImage: "archivebox", action: onArchive)
        }
      }
  }
}
