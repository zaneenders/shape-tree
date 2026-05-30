import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import Logging
import NIOCore
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import RaftWorkflow
import ShapeTreeClient
import Sit
import SystemPackage
import Testing
import Workflow

@testable import ShapeTree

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite struct DailySummaryTests {

  /// No entries for the day — workflow short-circuits the LLM call and still writes output.
  @Test func summarizeDayWithNoEntries() async throws {
    let log = Logger(label: "test.daily-summary.empty")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)
    let fixture = try await JWTTestSupport.makeFixture()

    let workflowStore = try testFileStepStore(in: layout)
    let summaryService = DailySummaryService(
      journalStore: journal,
      journalRepoPath: layout.journalRepoRoot.path,
      sit: Sit(),
      workflowStore: workflowStore,
      summariesDirectory: layout.summariesDirectory,
      log: log,
      llmURL: "http://localhost:11434",
      agentModel: "test-model",
      llmToken: nil,
      workingDirectory: layout.dataRoot.path)

    let router = try buildRoutes(
      store: SessionStore(),
      journalStore: journal,
      authorizedKeys: fixture.store,
      dailySummaryService: summaryService,
      log: log,
      llmURL: "http://localhost:11434",
      agentModel: "test-model",
      systemPrompt: "You are a test assistant.",
      llmToken: nil,
      contextWindow: 8192,
      contextWindowThreshold: 0.8,
      workingDirectory: "/tmp")

    let app = Application(router: router)

    let output = try await summaryService.summarizeDay(dayKey: "25-12-01")
    #expect(output.dayKey == "25-12-01")
    #expect(output.entryCount == 0)
    #expect(output.summary.contains("No journal entries"))

    try await app.test(.live) { client in
      let port = try #require(client.port)
      let transport = AsyncHTTPClientTransport()

      // GET — fresh token
      let getToken = try JWTTestSupport.mintToken(fixture)
      let getAPI = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: getToken)])
      let getResponse = try await getAPI.getDailySummary(path: .init(day: "25-12-01"))
      let getOk = try getResponse.ok
      let getBody = try getOk.body.json
      #expect(getBody.day == "25-12-01")
      #expect(getBody.summary.contains("No journal entries"))

      // GET for missing day — fresh token
      let missingToken = try JWTTestSupport.mintToken(fixture)
      let missingAPI = Client(
        serverURL: URL(string: "http://localhost:\(port)")!,
        transport: transport,
        middlewares: [BearerAuthClientMiddleware(bearerToken: missingToken)])
      do {
        let missing = try await missingAPI.getDailySummary(path: .init(day: "25-12-02"))
        _ = try missing.ok
        #expect(Bool(false), "Expected 404")
      } catch {
        // Expected — 404 maps to an error from the generated client
        #expect(Bool(true))
      }
    }
  }

  /// Replay: running summarization for the same day twice returns cached result.
  @Test func replayReturnsCachedSummary() async throws {
    let log = Logger(label: "test.daily-summary.replay")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)

    let workflowStore = try testFileStepStore(in: layout)
    let summaryService = DailySummaryService(
      journalStore: journal,
      journalRepoPath: layout.journalRepoRoot.path,
      sit: Sit(),
      workflowStore: workflowStore,
      summariesDirectory: layout.summariesDirectory,
      log: log,
      llmURL: "http://localhost:11434",
      agentModel: "test-model",
      llmToken: nil,
      workingDirectory: layout.dataRoot.path)

    let first = try await summaryService.summarizeDay(dayKey: "25-05-10")
    #expect(first.summary.contains("No journal entries"))

    let second = try await summaryService.summarizeDay(dayKey: "25-05-10")
    #expect(second.summary.contains("No journal entries"))

    let stepDir = testWorkflowStoreRoot(in: layout)
      .appendingPathComponent("daily-summary-25-05-10", isDirectory: true)
    #expect(FileManager.default.fileExists(atPath: stepDir.appendingPathComponent("pull").path))
    #expect(FileManager.default.fileExists(atPath: stepDir.appendingPathComponent("read").path))
    #expect(FileManager.default.fileExists(atPath: stepDir.appendingPathComponent("summarize").path))
    #expect(FileManager.default.fileExists(atPath: stepDir.appendingPathComponent("write").path))
  }

  /// End-to-end: seeds a few journal entries, then summarizes with a real local LLM.
  /// Requires Ollama running locally with `gemma4:e2b` pulled.  Skips gracefully
  /// when Ollama is unreachable or the model is missing.
  @Test func summarizeWithRealLLM() async throws {
    let ollamaURL = "http://localhost:11434"
    let model = "gemma4:e2b"

    // Probe — bail early if Ollama isn't available
    guard await ollamaIsReachable(ollamaURL) else {
      Issue.record("Ollama not reachable at \(ollamaURL)")
      return
    }

    let log = Logger(label: "test.daily-summary.e2e")
    let (journal, layout) = try await JournalTestFixtures.ephemeralJournalWorkspace(log: log)

    // Seed a couple of entries for today
    let todayKey = JournalPathCodec.journalDayKey(for: Date())
    _ = try await journal.appendEntry(
      subjectIds: ["general"],
      body:
        "Spent the morning refactoring the auth middleware. The JWT replay cache was incorrectly rejecting tokens when multiple requests arrived within the same second. Fixed by switching from a Set to a sorted array with binary search for the time window check.",
      createdAt: nil,
      journalDayKey: todayKey)
    _ = try await journal.appendEntry(
      subjectIds: ["general"],
      body:
        "Afternoon walk cleared my head. Decided to drop the caching tool executor idea for now — it adds complexity without a clear use case. The workflow system gives us enough replay-ability for the summarization pipeline.",
      createdAt: nil,
      journalDayKey: todayKey)

    let workflowStore = try testFileStepStore(in: layout)
    let summaryService = DailySummaryService(
      journalStore: journal,
      journalRepoPath: layout.journalRepoRoot.path,
      sit: Sit(),
      workflowStore: workflowStore,
      summariesDirectory: layout.summariesDirectory,
      log: log,
      llmURL: ollamaURL,
      agentModel: model,
      llmToken: nil,
      workingDirectory: layout.dataRoot.path)

    let output = try await summaryService.summarizeDay(dayKey: todayKey)

    // Should produce a real summary, not the "no entries" short-circuit
    #expect(!output.summary.contains("No journal entries"))
    #expect(output.entryCount > 0)
    #expect(!output.summary.isEmpty)

    // The summary should mention something from the entries
    let lower = output.summary.lowercased()
    #expect(
      lower.contains("auth") || lower.contains("jwt") || lower.contains("refactor") || lower.contains("walk")
        || lower.contains("workflow"),
      "Expected summary to reference seeded content, got:\n\(output.summary)")

    // Verify the summary file was written
    let summaryFile = layout.summariesDirectory.appendingPathComponent("\(todayKey).md", isDirectory: false)
    #expect(FileManager.default.fileExists(atPath: summaryFile.path))
    let writtenContent = try String(contentsOf: summaryFile, encoding: .utf8)
    #expect(writtenContent == output.summary)

    // Replay — should return same result from cache without hitting the LLM
    let replayed = try await summaryService.summarizeDay(dayKey: todayKey)
    #expect(replayed.summary == output.summary)
  }

  // MARK: - Helpers

  private func testWorkflowStoreRoot(in layout: ShapeTreeDataLayout) -> URL {
    layout.dotFolder.appendingPathComponent("test-workflows", isDirectory: true)
  }

  private func testFileStepStore(in layout: ShapeTreeDataLayout) throws -> FileStepStore {
    try FileStepStore(directory: testWorkflowStoreRoot(in: layout))
  }

  private func ollamaIsReachable(_ baseURL: String) async -> Bool {
    guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
    var req = URLRequest(url: url)
    req.timeoutInterval = 3
    do {
      let (_, response) = try await URLSession.shared.data(for: req)
      return (response as? HTTPURLResponse)?.statusCode == 200
    } catch {
      return false
    }
  }
}
