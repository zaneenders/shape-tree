import JavaScriptKit

enum Bridge {
  static func log(_ message: String) {
    try? webConsole.log("[shape-tree-core] \(message)")
  }

  static func datasetString(_ element: HTMLElement, _ key: String) -> String? {
    datasetString(try? element.dataset, key)
  }

  static func datasetString(_ dataset: JSObject?, _ key: String) -> String? {
    guard let dataset else { return nil }
    let value = dataset[key]
    guard !value.isUndefined, !value.isNull else { return nil }
    return value.string
  }

  static func setDataset(_ dataset: JSObject, _ key: String, _ value: JSValue) {
    dataset[key] = value
  }

  static func jsObjectPropertyString(_ object: JSObject, _ key: String) -> String? {
    let value = object[key]
    guard !value.isUndefined, !value.isNull else { return nil }
    return value.string
  }

  static func jsObjectPropertyBool(_ object: JSObject, _ key: String) -> Bool? {
    let value = object[key]
    guard !value.isUndefined, !value.isNull else { return nil }
    return value.boolean
  }

  static func jsArrayLength(_ value: JSValue) -> Int {
    Int(value.object?.length.number ?? 0)
  }

  static func jsArrayElement(_ value: JSValue, _ index: Int) -> JSValue {
    value.object![index]
  }

  static func elementDataset(_ element: HTMLElement) -> JSObject? {
    try? element.dataset
  }

  static func tagName(_ element: HTMLElement) -> String? {
    try? element.tagName
  }

  static func elementID(_ element: HTMLElement) -> String? {
    try? element.id
  }

  static func isChecked(_ element: HTMLElement) -> Bool {
    (try? element.checked) == true
  }

  static func collectionLength(_ collection: HTMLCollection) -> Int {
    Int((try? collection.length) ?? 0)
  }

  static func nodeListLength(_ list: NodeList) -> Int {
    Int((try? list.length) ?? 0)
  }

  static func eventTarget(_ event: Event) -> HTMLElement? {
    try? event.target
  }

  static func eventKey(_ event: Event) -> String? {
    try? event.key
  }

  static func eventState(_ event: Event) -> JSObject? {
    try? event.state
  }
}
