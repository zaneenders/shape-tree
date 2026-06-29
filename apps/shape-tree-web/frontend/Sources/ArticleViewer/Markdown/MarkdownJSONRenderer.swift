import JavaScriptKit

func renderMarkdownNode(_ node: JSValue) -> String {
  guard let object = node.object, let kind = object.kind.string else {
    return ""
  }

  switch kind {
  case "document":
    return renderChildren(object)
  case "text":
    return escapeHTML(object.text.string ?? "")
  case "softBreak":
    return "\n"
  case "lineBreak":
    return "<br>"
  case "emphasis":
    return "<em>\(renderChildren(object))</em>"
  case "strong":
    return "<strong>\(renderChildren(object))</strong>"
  case "strikethrough":
    return "<del>\(renderChildren(object))</del>"
  case "inlineCode":
    return "<code>\(escapeHTML(object.text.string ?? ""))</code>"
  case "link":
    let destination = object.destination.string ?? ""
    let href = escapeAttr(destination)
    let rel = destination.hasPrefix("http") ? " rel=\"noopener noreferrer\"" : ""
    return "<a href=\"\(href)\"\(rel)>\(renderChildren(object))</a>"
  case "image":
    let source = escapeAttr(object.source.string ?? "")
    let alt = escapeAttr(object.text.string ?? "")
    return "<img src=\"\(source)\" alt=\"\(alt)\" loading=\"lazy\">"
  case "paragraph":
    return "<p>\(renderChildren(object))</p>"
  case "heading":
    let level = min(max(Int(object.level.number ?? 1), 1), 6)
    return "<h\(level)>\(renderChildren(object))</h\(level)>"
  case "blockQuote":
    return "<blockquote>\(renderChildren(object))</blockquote>"
  case "codeBlock":
    let language = object.language.string.map { " class=\"language-\(escapeAttr($0))\"" } ?? ""
    return "<pre><code\(language)>\(escapeHTML(object.text.string ?? ""))</code></pre>"
  case "unorderedList":
    return "<ul>\(renderChildren(object))</ul>"
  case "orderedList":
    return "<ol>\(renderChildren(object))</ol>"
  case "listItem":
    return "<li>\(renderChildren(object))</li>"
  case "thematicBreak":
    return "<hr>"
  case "htmlBlock", "inlineHTML":
    return object.text.string ?? ""
  default:
    return renderChildren(object)
  }
}

private func renderChildren(_ object: JSObject) -> String {
  guard let children = object.children.object else { return "" }
  let length = Int(children.length.number ?? 0)
  var html = ""
  for index in 0..<length {
    html += renderMarkdownNode(children[index])
  }
  return html
}

private func escapeHTML(_ value: String) -> String {
  var escaped = ""
  escaped.reserveCapacity(value.count)
  for character in value {
    switch character {
    case "&": escaped.append("&amp;")
    case "<": escaped.append("&lt;")
    case ">": escaped.append("&gt;")
    case "\"": escaped.append("&quot;")
    case "'": escaped.append("&#39;")
    default: escaped.append(character)
    }
  }
  return escaped
}

private func escapeAttr(_ value: String) -> String {
  escapeHTML(value)
}
