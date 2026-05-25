# syntax=docker/dockerfile:1

FROM swift:6.3-jammy AS build

WORKDIR /src

COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

# Drop Apple-only platform constraints so Linux container builds succeed.
RUN --mount=type=cache,target=/root/.cache/swift \
    --mount=type=cache,target=/src/.build \
    sed -i '/platforms: \[/,/^\  \],/d' Package.swift \
    && swift package resolve \
    && find .build/checkouts/swift-raft -name Package.swift -exec sed -i '/platforms: \[/,/^\  \],/d' {} + \
    && swift build -c release --product raft-workflow-node \
    && cp .build/release/raft-workflow-node /tmp/raft-workflow-node

FROM swift:6.3-jammy-slim

WORKDIR /app

COPY --from=build /tmp/raft-workflow-node /usr/local/bin/raft-workflow-node

RUN mkdir -p /data/raft-workflow-node

ENTRYPOINT ["/usr/local/bin/raft-workflow-node"]
