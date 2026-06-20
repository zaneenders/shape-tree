# shape-tree

## Structure

```
apps/
├── shape-tree-api/   ← Swift package (server + client library)
├── shape-tree-web/   ← Swift package (markdown blog)
└── ShapeTreeApp/     ← iOS & macOS chat app
```

See [apps/shape-tree](./apps/shape-tree/) for the server package (required `data.path` for the journal root; `.shape-tree/` under that path is ignored in git for local dev—see package README), [apps/shape-tree-web](./apps/shape-tree-web/) for the web blog, and [apps/ShapeTreeApp](./apps/ShapeTreeApp/) for the client app.