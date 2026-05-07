#if canImport(System)
import System
#else
import SystemPackage
#endif
import Foundation
import Logging
import Subprocess

public enum SitError: Error, Sendable, CustomStringConvertible {
  case gitCommandFailed(command: String, status: TerminationStatus, stderr: String)

  public var description: String {
    switch self {
    case .gitCommandFailed(let command, let status, let stderr):
      "git \(command) failed (\(status)): \(stderr)"
    }
  }
}

/// Async [`git`(1)](https://git-scm.com/docs/git) helper using [swift-subprocess](https://github.com/swiftlang/swift-subprocess).
public struct Sit: Sendable {
  private let executable: Executable

  public init(gitExecutable: Executable = .name("git")) {
    self.executable = gitExecutable
  }

  /// `git init`; safe to call if `.git` already exists (skipped).
  public func initializeRepoIfNeeded(cwd: FilePath, log: Logger) async throws {
    if FileManager.default.fileExists(atPath: cwd.string + "/.git") {
      return
    }
    try await invokeExpectingSuccess(arguments: ["init"], cwd: cwd, commandLabel: "init", log: log)
  }

  /// No unstaged tracked changes **and** no staged changes versus `HEAD`. Used to gate `pull --rebase`.
  public func isCleanIndexedAndTracked(cwd: FilePath, log: Logger) async throws -> Bool {
    guard try await gitHeadExists(cwd: cwd, log: log) else {
      return false
    }
    let unstaged = try await run(arguments: ["diff", "--quiet"], cwd: cwd, log: log)
    if !unstaged.status.isSuccess {
      log.debug("git diff --quiet: dirty working tree")
      return false
    }
    let staged = try await run(arguments: ["diff", "--cached", "--quiet"], cwd: cwd, log: log)
    if !staged.status.isSuccess {
      log.debug("git diff --cached --quiet: staged changes present")
      return false
    }
    return true
  }

  /// Runs `pull --rebase` only when the index and tracked working tree match `HEAD`. Logs and ignores typical
  /// “no remote” / network failures instead of throwing.
  public func pullRebaseIfClean(cwd: FilePath, log: Logger) async throws {
    guard try await isCleanIndexedAndTracked(cwd: cwd, log: log) else {
      log.debug("skip git pull (--rebase); repo not clean or no commits yet")
      return
    }
    let outcome = try await run(
      arguments: ["pull", "--rebase"], cwd: cwd, log: log, alwaysLogCommand: true)

    guard outcome.status.isSuccess else {
      if Self.isLikelyBenignPullFailure(stderr: outcome.stderr) {
        log.debug(
          "git pull --rebase skipped (benign/no remote/upstream): \(outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
      } else {
        log.warning(
          "git pull --rebase exited non‑zero; continuing without pull",
          metadata: [
            "status": "\(outcome.status)",
            "stderr": "\(outcome.stderr)",
          ])
      }
      return
    }
  }

  public func addCommitPush(
    cwd: FilePath,
    relativePaths: [String],
    message: String,
    log: Logger
  ) async throws {
    guard !relativePaths.isEmpty else { return }

    try await invokeExpectingSuccess(
      arguments: ["add", "--"] + relativePaths,
      cwd: cwd,
      commandLabel: "add",
      log: log)

    try await invokeExpectingSuccess(
      arguments: ["commit", "-m", message],
      cwd: cwd,
      commandLabel: "commit",
      log: log)

    let pushOutcome = try await run(
      arguments: ["push"],
      cwd: cwd,
      log: log,
      alwaysLogCommand: true)

    guard pushOutcome.status.isSuccess else {
      if Self.isLikelyBenignPushFailure(stderr: pushOutcome.stderr) {
        log.debug(
          "git push skipped (benign/no remote): \(pushOutcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
      } else {
        log.warning(
          "git push failed; journal entry committed locally only",
          metadata: [
            "status": "\(pushOutcome.status)",
            "stderr": "\(pushOutcome.stderr)",
          ])
      }
      return
    }
  }

  // MARK: - Internals

  private struct RunOutcome {
    let status: TerminationStatus
    let stdout: String
    let stderr: String
  }

  private func gitHeadExists(cwd: FilePath, log: Logger) async throws -> Bool {
    let outcome = try await run(arguments: ["rev-parse", "--verify", "HEAD"], cwd: cwd, log: log)
    return outcome.status.isSuccess
  }

  private func invokeExpectingSuccess(
    arguments: [String],
    cwd: FilePath,
    commandLabel: String,
    log: Logger
  ) async throws {
    let o = try await run(arguments: arguments, cwd: cwd, log: log, alwaysLogCommand: true)
    guard o.status.isSuccess else {
      throw SitError.gitCommandFailed(
        command: commandLabel,
        status: o.status,
        stderr: o.stderr.isEmpty ? o.stdout : o.stderr)
    }
  }

  private func run(
    arguments: [String],
    cwd: FilePath,
    log: Logger,
    alwaysLogCommand: Bool = false
  ) async throws -> RunOutcome {
    if alwaysLogCommand {
      log.debug("git \(arguments.joined(separator: " "))", metadata: ["cwd": "\(cwd)"])
    }
    let record = try await Subprocess.run(
      executable,
      arguments: Arguments(arguments),
      environment: .inherit,
      workingDirectory: cwd,
      output: .string(limit: 10 * 1024 * 1024),
      error: .string(limit: 1024 * 1024))

    let out = record.standardOutput ?? ""
    let err = record.standardError ?? ""

    return RunOutcome(status: record.terminationStatus, stdout: out, stderr: err)
  }

  private nonisolated static func isLikelyBenignPullFailure(stderr: String) -> Bool {
    let s = stderr.lowercased()
    return s.contains("there is no tracking information")
      || s.contains("no upstream")
      || s.contains("could not resolve host")
      || s.contains("could not read from remote repository")
      || s.contains("unable to access")
      || s.contains("'origin' does not appear to be a git repository")
  }

  private nonisolated static func isLikelyBenignPushFailure(stderr: String) -> Bool {
    let s = stderr.lowercased()
    return s.contains("no configured push destination")
      || s.contains("fatal: unable to access")
      || s.contains("could not resolve host")
      || s.contains("'origin' does not appear to be a git repository")
  }
}
