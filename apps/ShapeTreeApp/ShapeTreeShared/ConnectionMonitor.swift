import Foundation

public enum ConnectionState: Equatable, Sendable {
  /// Server is reachable and the device key is enrolled in authorized_keys.
  case online
  /// Server is reachable but the device key is not enrolled — 401 from /ping.
  case unauthorized
  /// Server is not responding within the 1-second timeout.
  case offline
}

/// Polls `GET /ping` on a fixed interval and surfaces the three-state connection status.
/// Start/stop from the root view based on scene phase to avoid background polling.
@Observable
@MainActor
public final class ConnectionMonitor {
  public private(set) var state: ConnectionState = .offline

  private var serverURL: String
  private let keyStore: ShapeTreeKeyStore
  private var pollingTask: Task<Void, Never>?
  private let session: URLSession
  private var isActive = false

  private static let pollInterval: Duration = .seconds(3)
  private static let requestTimeout: TimeInterval = 1

  public init(serverURL: String, keyStore: ShapeTreeKeyStore) {
    self.serverURL = serverURL
    self.keyStore = keyStore
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = Self.requestTimeout
    config.timeoutIntervalForResource = Self.requestTimeout + 1
    self.session = URLSession(configuration: config)
  }

  /// Starts the polling loop, cancelling any previous one first.
  public func start() {
    stop()
    isActive = true
    pollingTask = Task {
      while !Task.isCancelled {
        await probe()
        try? await Task.sleep(for: Self.pollInterval)
      }
    }
  }

  public func stop() {
    isActive = false
    pollingTask?.cancel()
    pollingTask = nil
  }

  /// Call when the server URL changes — resets to `.offline` and restarts polling if active.
  public func serverURLDidChange(_ url: String) {
    serverURL = url
    state = .offline
    if isActive { start() }
  }

  private func probe() async {
    guard !serverURL.isEmpty, let url = URL(string: serverURL + "/ping") else {
      state = .offline
      return
    }
    do {
      var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
      let token = try keyStore.mintES256JWT(ttl: 30)
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      let (_, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else {
        state = .offline
        return
      }
      switch http.statusCode {
      case 200, 204: state = .online
      case 401: state = .unauthorized
      default: state = .offline
      }
    } catch {
      state = .offline
    }
  }
}
