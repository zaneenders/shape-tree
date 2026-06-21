import ShapeTreeWebAssets
import Testing

@Suite
/// Requires embedded `WasmPosts` from `./Scripts/build-client.sh`.
struct PostWasmAssetTests {
  @Test
  func servesKnownSlugWhenWasmPostsAreEmbedded() {
    guard PostWasmAsset.isAvailable else {
      Issue.record("WasmPosts not embedded — run ./Scripts/build-client.sh first")
      return
    }

    #expect(!PostWasmAsset.availableSlugs.isEmpty)

    for slug in ["new-mac", "c++-and-swift", "Articles"] {
      guard PostWasmAsset.availableSlugs.contains(slug) else { continue }
      let bytes = PostWasmAsset.wasm(forSlug: slug)
      #expect(bytes != nil)
      #expect(bytes?.isEmpty == false)
      let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
      #expect(PostWasmAsset.wasm(forSlug: encoded) != nil)
    }
  }
}
