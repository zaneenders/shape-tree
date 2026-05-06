# ShapeTree Client App

Basic iOS and macOS chat UI for [ShapeTree](../shape-tree/).

## Prerequisites

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- macOS 15+ with Xcode 16+

## Code signing

The committed `project.yml` does not embed anyone’s Apple Development Team. Signing values live in `project.local.yml`, which is **gitignored** and created on first generate from `project.local.yml.example`. Edit that file and set `DEVELOPMENT_TEAM` to your 10-character Team ID for physical devices, notarization, or distribution. Simulator-only runs often work with the placeholder until you need a real team. Private keys and certificates never belong in the repository.

## Generate & open

```bash
cd apps/ShapeTreeApp
cp project.local.yml.example project.local.yml
# Only need to create the project.local file once
xcodegen generate
open ShapeTreeClient.xcodeproj
```

Edit `project.local.yml` and set `DEVELOPMENT_TEAM` to your 10-character Apple Team ID for device signing, notarization, or distribution. Simulator-only runs work with the placeholder until you need a real team.

## What it is

A minimal single-screen chat app that talks to a local [ShapeTree server](../shape-tree/Sources/ShapeTree/)
(default `http://127.0.0.1:42069`) through the OpenAPI-generated
[ShapeTreeClient](../shape-tree/Sources/ShapeTreeClient/).

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
├── project.yml                  # XcodeGen project spec (no Team ID)
├── project.local.yml.example    # Template for gitignored project.local.yml
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
