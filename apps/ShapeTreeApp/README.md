# ShapeTree Client App

Basic iOS and macOS chat UI for [ShapeTree](../..).

## Prerequisites

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- macOS 15+ with Xcode 16+

## Generate & open

```bash
cd apps/ShapeTreeApp

# Generate the Xcode project
xcodegen generate

# Open
open ShapeTreeClient.xcodeproj
```

Then pick the **ShapeTreeClient-Mac** or **ShapeTreeClient-iOS** scheme and run.

## What it is

A minimal single-screen chat app that talks to a local [ShapeTree server](../../Sources/ShapeTree/)
(default `http://127.0.0.1:42069`) through the OpenAPI-generated
[ShapeTreeClient](../../Sources/ShapeTreeClient/).

- **macOS**: Native window with chat history and text input.
- **iOS**: Identical UI, runs on iPhone and iPad.

## Configuration

Edit defaults in `ShapeTreeShared/ShapeTreeViewModel.swift`:

| Property       | Default                          |
|----------------|----------------------------------|
| `serverURL`    | `http://127.0.0.1:42069`        |
| `ollamaURL`    | `http://127.0.0.1:11434`        |
| `model`        | `gemma4:e2b`                    |
| `systemPrompt` | `"You are a helpful …"`         |

## Structure

```
ShapeTreeApp/
├── project.yml                  # XcodeGen project spec
├── ShapeTreeShared/             # Shared between iOS and Mac
│   ├── ShapeTreeViewModel.swift # Observable view model (ShapeTreeClient)
│   └── Views/
│       ├── ShapeTreeChatView.swift
│       └── ShapeTreeChatInputView.swift
├── ShapeTree-iOS-Only/          # iOS app entry point
│   ├── ShapeTreeApp.swift
│   └── Assets.xcassets/
└── ShapeTree-Mac-Only/          # Mac app entry point
    ├── ShapeTreeApp.swift
    ├── ShapeTree.entitlements
    └── Assets.xcassets/
```
