---
title: Getting Started
date: 2025-06-12
tags:
  - guides
  - setup
excerpt: How to point the server at a content directory and publish markdown files.
---

## Run the server

```bash
cd apps/shape-tree-web
cp .env.example .env
swift run ShapeTreeWeb
```

## Add content

Create `.md` files anywhere under `CONTENT_PATH`. Optional front matter at the top:

```markdown
---
title: My Page
date: 2025-06-12
tags:
  - example
excerpt: A one-line summary for the index.
---

Body copy begins here.
```

## Directory groups

Files in subfolders are grouped together. Example layout:

```text
content/
  index.md
  style-guide.md
  notes/
    morning-pages.md
  guides/
    getting-started.md
```

Folders become flyout menus in the nav and labeled sections on the home page.
