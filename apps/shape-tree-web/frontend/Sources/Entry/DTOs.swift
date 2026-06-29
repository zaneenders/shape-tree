import JavaScriptKit

@JS struct VerifyResponse {
  var ok: Bool
  var next: String?
}

@JS struct PageProps {
  var page: String
  var next: String
  var token: String
}

@JS struct ServerMessage {
  var message: String
  var server: String
}

@JS struct SessionInfo {
  var authenticated: Bool
  var email: String?
  var demo: Bool
  var fit: Bool
  var article: Bool
}
