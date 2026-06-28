enum WebAssets {
  static func indexHTML(
    title: String = "WASM Hummingbird Server",
    styles: String,
    bootstrapScript: String
  ) -> String {
    let escapedTitle = escapeHTML(title)
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <title>\(escapedTitle)</title>
        <style>
        \(styles)
        </style>
        <script type="module">
        \(bootstrapScript)
        </script>
      </head>
      <body>
      </body>
      </html>
      """
  }

  private static func escapeHTML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
