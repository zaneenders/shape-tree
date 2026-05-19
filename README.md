# shape-tree

## Structure

```
apps/
├── shape-tree/       ← Swift package (server + client library)
└── ShapeTreeApp/     ← iOS & macOS chat app
```

See [apps/shape-tree](./apps/shape-tree/) for the server package (required `data.path`; all mutable server data under `R/.shape-tree/`, including todos—see package README) and [apps/ShapeTreeApp](./apps/ShapeTreeApp/) for the client app.