enum WebAssets {
  static let stylesheetPath = "/app.css"

  static func indexHTML(
    title: String = "ShapeTree",
    bootstrapScript: String
  ) -> String {
    let escapedTitle = escapeHTML(title)
    return """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>\(escapedTitle)</title>
        <link rel="stylesheet" href="\(stylesheetPath)" />
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
