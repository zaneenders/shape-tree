import Foundation
import Logging
import ScribeCore
import Sit
import Workflow

#if canImport(System)
import System
#else
import SystemPackage
#endif

// MARK: - Step result types (Codable for workflow caching)

private struct PullResult: Codable {
  let pulledAt: Date
}

private struct ReadResult: Codable {
  let entryText: String
  let entryCount: Int
}

private struct SummarizeResult: Codable {
  let summary: String
}

private struct WriteResult: Codable {
  let path: String
}

// MARK: - Public output

public struct DailySummaryOutput: Sendable {
  public let dayKey: String
  public let summary: String
  public let entryCount: Int

  public init(dayKey: String, summary: String, entryCount: Int) {
    self.dayKey = dayKey
    self.summary = summary
    self.entryCount = entryCount
  }
}

// MARK: - Service

/// Produces an LLM-generated summary of one day's journal entries,
/// cached via `WorkflowContext` so repeated requests for the same
/// day replay from the configured step store.
public struct DailySummaryService: Sendable {

  private let journalStore: JournalStore
  private let journalRepoPath: String
  private let sit: Sit
  private let workflowStore: any StepStore
  public let summariesDirectory: URL
  private let log: Logger
  private let llmURL: String
  private let agentModel: String
  private let llmToken: String?
  private let workingDirectory: String

  public init(
    journalStore: JournalStore,
    journalRepoPath: String,
    sit: Sit,
    workflowStore: any StepStore,
    summariesDirectory: URL,
    log: Logger,
    llmURL: String,
    agentModel: String,
    llmToken: String?,
    workingDirectory: String
  ) {
    self.journalStore = journalStore
    self.journalRepoPath = journalRepoPath
    self.sit = sit
    self.workflowStore = workflowStore
    self.summariesDirectory = summariesDirectory
    self.log = log
    self.llmURL = llmURL
    self.agentModel = agentModel
    self.llmToken = llmToken
    self.workingDirectory = workingDirectory
  }

  // MARK: - Summarize

  public func summarizeDay(dayKey: String, force: Bool = false) async throws -> DailySummaryOutput {
    let workflowID = "daily-summary-\(dayKey)"
    if force {
      log.info("event=summary.reset day=\(dayKey)")
      try await workflowStore.reset(workflowID: workflowID)
    }
    log.info("event=summary.start day=\(dayKey) force=\(force)")
    let ctx = WorkflowContext(id: workflowID, store: workflowStore, log: log)

    // Step 1 — Pull journal repo
    let pull = try await ctx.step {
      try await sit.pullRebaseIfClean(cwd: FilePath(journalRepoPath), log: log)
      return PullResult(pulledAt: Date())
    }
    log.info("event=summary.pull day=\(dayKey) pulledAt=\(pull.pulledAt)")

    // Step 2 — Read today's entries
    let read = try await ctx.step {
      if let detail = try await journalStore.entryDetail(dayKey: dayKey) {
        return ReadResult(entryText: detail.content, entryCount: detail.lineCount)
      }
      return ReadResult(entryText: "", entryCount: 0)
    }

    // Step 3 — Summarize (or short-circuit if no entries)
    let summary = try await ctx.step {
      guard !read.entryText.isEmpty else {
        return SummarizeResult(summary: "No journal entries for \(dayKey).")
      }

      let config = ScribeConfig(
        agentModel: agentModel,
        contextWindow: 8192,
        contextWindowThreshold: 0.8,
        serverURL: llmURL,
        apiKey: llmToken,
        tools: [],
        workingDirectory: workingDirectory)
      let agent = try ScribeAgent(
        configuration: config,
        systemPrompt: Self.summarizationPrompt)
      let stream = await agent.prompt(read.entryText, log: log)
      let result = try await stream.result.value
      let text =
        result.messages.last(where: { $0.role == .assistant })?.content
        ?? "(no assistant response)"
      return SummarizeResult(summary: text)
    }

    // Step 4 — Write to summaries directory
    let writeResult = try await ctx.step {
      let fileURL = summariesDirectory.appendingPathComponent("\(dayKey).md", isDirectory: false)
      let fm = FileManager.default
      try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      guard let data = summary.summary.data(using: .utf8) else {
        throw DailySummaryError.utf8EncodingFailed
      }
      try data.write(to: fileURL, options: .atomic)
      log.info("event=summary.write day=\(dayKey) path=\(fileURL.path)")
      return WriteResult(path: fileURL.path)
    }

    log.info("event=summary.complete day=\(dayKey) path=\(writeResult.path)")

    return DailySummaryOutput(
      dayKey: dayKey,
      summary: summary.summary,
      entryCount: read.entryCount)
  }

  // MARK: - Prompt

  private static let summarizationPrompt = """
    You are a thoughtful journal summarizer. Given one day's journal entries, produce a concise summary in Markdown.

    Include:
    - A brief narrative overview (2–3 sentences)
    - Key topics and themes as bullet points
    - Any decisions, questions, or insights worth preserving

    Keep the tone warm and reflective, matching the journal's voice.
    Do not mention that you are an AI or that this is a summary of a summary.
    """
}

// MARK: - Errors

public enum DailySummaryError: Error, Sendable, CustomStringConvertible {
  case utf8EncodingFailed
  case invalidDayKey(String)

  public var description: String {
    switch self {
    case .utf8EncodingFailed:
      "Summary text is not valid UTF-8."
    case .invalidDayKey(let key):
      "Invalid day key: \(key). Expected yy-MM-dd."
    }
  }
}
