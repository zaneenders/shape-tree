import Configuration

enum ConfigKeys {
  static let serverHost: ConfigKey = "server.host"
  static let serverPort: ConfigKey = "server.port"
  static let dataPath: ConfigKey = "data.path"
  static let ollamaURL: ConfigKey = "ollama.url"
  static let ollamaToken: ConfigKey = "ollama.token"
  static let agentModel: ConfigKey = "agent.model"
  static let systemPrompt: ConfigKey = "agent.systemPrompt"
  static let contextWindow: ConfigKey = "agent.contextWindow"
  static let contextWindowThreshold: ConfigKey = "agent.contextWindowThreshold"
  static let journalCommitAuthorName: ConfigKey = "journal.commitAuthor.name"
  static let journalCommitAuthorEmail: ConfigKey = "journal.commitAuthor.email"
  static let workflowRaftEndpoints: ConfigKey = "workflow.raft.endpoints"
}
