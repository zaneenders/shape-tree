---
title: Hello, Markdown
date: 2025-06-17
tags:
  - swift
  - hummingbird
excerpt: A first post rendered from a markdown file on disk.
---

# Hello, Markdown

This post lives in `Examples/content/` and is loaded at startup.

## Features

- Jekyll-style `---` front matter
- Recursive `.md` discovery
- GitHub-flavored markdown via swift-markdown
- HTMX navigation without full page reloads

```swift
let store = try ContentStore(contentDirectory: contentURL)
```

> ShapeTree Web is meant for local previews and small static-ish sites, not as a replacement for the authenticated ShapeTree API server.
