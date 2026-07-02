-----

title: Full Stack Swift

date: 24-07-18

tags:

- swift
- wasm
- hummingbird

-----

# Full Stack Swift

ShapeTree Web serves a Swift WASM frontend from Hummingbird and loads markdown from the path in `CONTENT_PATH`.

```swift
router.get("api/content/articles") { _, context in
  let items = store.posts(in: .articles, includingPrivate: context.identity != nil)
  return ContentListResponse(items: items.map(ContentListItem.init(post:)))
}
```

The browser renders article bodies as JSON markdown trees, then converts them to HTML on the client.
