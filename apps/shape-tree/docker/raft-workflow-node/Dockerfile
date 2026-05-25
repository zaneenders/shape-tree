# syntax=docker/dockerfile:1

FROM swift:6.3-jammy AS build

WORKDIR /src

COPY docker/raft-workflow-node/Package.swift ./
COPY Sources/Workflow ./Sources/Workflow
COPY Sources/RaftWorkflow ./Sources/RaftWorkflow
COPY Sources/raft-workflow-node ./Sources/raft-workflow-node

# swift-raft declares macOS-only platforms; drop that so Linux builds succeed.
RUN --mount=type=cache,target=/root/.cache/swift \
    --mount=type=cache,target=/src/.build \
    swift package resolve \
    && find .build/checkouts/swift-raft -name Package.swift -exec sed -i '/platforms: \[/,/^\  \],/d' {} + \
    && swift build -c release --product raft-workflow-node \
    && cp .build/release/raft-workflow-node /tmp/raft-workflow-node

FROM swift:6.3-jammy-slim

WORKDIR /app

COPY --from=build /tmp/raft-workflow-node /usr/local/bin/raft-workflow-node

RUN mkdir -p /data/raft-workflow-node

ENTRYPOINT ["/usr/local/bin/raft-workflow-node"]
