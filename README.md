# shape-tree

## Structure

```
apps/
├── shape-tree/       ← Swift package (server + client library)
└── ShapeTreeApp/     ← iOS & macOS chat app
```

See [apps/shape-tree](./apps/shape-tree/) for the server package (required `data.path` for the journal root; `.shape-tree/` under that path is ignored in git for local dev—see package README) and [apps/ShapeTreeApp](./apps/ShapeTreeApp/) for the client app.