// Embedded Swift has no Foundation, so replacingOccurrences/of:with: is not
// available. This helper works on UTF-8 bytes, which only needs transcoding.

func stringReplacing(_ source: String, _ target: String, _ replacement: String) -> String {
  let bytes = Array(source.utf8)
  let needle = Array(target.utf8)
  guard !needle.isEmpty, needle.count <= bytes.count else { return source }
  let repl = Array(replacement.utf8)
  var out: [UInt8] = []
  var index = 0
  while index < bytes.count {
    if index + needle.count <= bytes.count,
      Array(bytes[index..<index + needle.count]) == needle
    {
      out.append(contentsOf: repl)
      index += needle.count
    } else {
      out.append(bytes[index])
      index += 1
    }
  }
  return String(decoding: out, as: UTF8.self)
}
