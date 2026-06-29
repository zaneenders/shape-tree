# syntax=docker/dockerfile:1

ARG SWIFT_VERSION=6.3.2

# WASM SDK for cross-compiling the FitViewer target (local dev: `swift run shape-tree-web-builder`).
ARG SWIFT_WASM_SDK=swift-6.3.2-RELEASE_wasm-embedded
ARG SWIFT_WASM_SDK_URL=https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz
ARG SWIFT_WASM_SDK_CHECKSUM=a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c

# Static Linux SDK for a fully static server binary (scratch / Alpine runtime).
ARG SWIFT_STATIC_SDK_URL=https://download.swift.org/swift-6.3.2-release/static-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz
ARG SWIFT_STATIC_SDK_CHECKSUM=3fd798bef6f4408f1ea5a6f94ce4d4052830c4326ab85ebc04f983f01b3da407

# Build mode: release (default) or debug.
ARG BUILD_CONFIGURATION=release

# -----------------------------------------------------------------------------
# Build: WASM frontend + statically linked Hummingbird server
# -----------------------------------------------------------------------------
FROM swift:${SWIFT_VERSION}-noble AS build

ARG SWIFT_WASM_SDK
ARG SWIFT_WASM_SDK_URL
ARG SWIFT_WASM_SDK_CHECKSUM
ARG SWIFT_STATIC_SDK_URL
ARG SWIFT_STATIC_SDK_CHECKSUM
ARG TARGETARCH
ARG BUILD_CONFIGURATION

# nodejs: BridgeJS plugin during `swift package js`. bun: app/ → dist/app.js, features/ → dist/*.js.
RUN apt-get update \
  && apt-get install -y --no-install-recommends binaryen ca-certificates curl nodejs unzip \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN swift sdk install "${SWIFT_WASM_SDK_URL}" --checksum "${SWIFT_WASM_SDK_CHECKSUM}" \
  && swift sdk install "${SWIFT_STATIC_SDK_URL}" --checksum "${SWIFT_STATIC_SDK_CHECKSUM}"

WORKDIR /app

COPY Package.swift .swift-version Package.resolved ./
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests
COPY frontend/ ./frontend/
RUN cd frontend && swift package resolve

# WASM frontend via shape-tree-web-builder, then statically linked server binary.
ENV SWIFT_SDK_ID=${SWIFT_WASM_SDK}
ENV BUILD_CONFIGURATION=${BUILD_CONFIGURATION}

RUN case "${TARGETARCH}" in \
      amd64) echo "x86_64-swift-linux-musl" > /.swift-musl-sdk ;; \
      arm64) echo "aarch64-swift-linux-musl" > /.swift-musl-sdk ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac

# Build builder tool only — FitViewer/JavaScriptKit is built separately via `swift package js` + WASM SDK.
RUN SWIFT_MUSL_SDK="$(cat /.swift-musl-sdk)" \
  && swift build -c "${BUILD_CONFIGURATION}" --product shape-tree-web-builder --swift-sdk "${SWIFT_MUSL_SDK}"

# Run builder (uses BUILD_CONFIGURATION via ShapeTreeWebBuilder.Configuration.current)
RUN .build/$(cat /.swift-musl-sdk)/"${BUILD_CONFIGURATION}"/shape-tree-web-builder

# Build and copy ShapeTreeWeb
RUN SWIFT_MUSL_SDK="$(cat /.swift-musl-sdk)" \
  && swift build -c "${BUILD_CONFIGURATION}" --product ShapeTreeWeb --swift-sdk "${SWIFT_MUSL_SDK}" \
  && mkdir -p /output \
  && cp ".build/${SWIFT_MUSL_SDK}/${BUILD_CONFIGURATION}/ShapeTreeWeb" /output/ShapeTreeWeb

# -----------------------------------------------------------------------------
# Runtime: static binary + dist (shell HTML inlines app.js, links /app.css + Entry.wasm; lazy: fit-viewer-bootstrap.js + FitViewer.wasm)
# -----------------------------------------------------------------------------
FROM scratch AS runtime

WORKDIR /app

# CA cert bundle for outbound TLS (SMTP startTLS). scratch has none by default;
# without it NIOSSLContext can't load a trust store and BoringSSL fails at handshake.
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

COPY --from=build /output/ShapeTreeWeb ./ShapeTreeWeb
COPY --from=build /app/dist ./dist

ENV HOSTNAME=0.0.0.0
ENV PORT=8080
ENV STATIC_ROOT=/app/dist
ENV SKIP_SHAPE_TREE_WEB_BUILD=1
ENV OTEL_HOST=0.0.0.0
ENV OTEL_PORT=42070
ENV OTEL_SERVICE_NAME=shape-tree-web
ENV OTEL_EXPORTER_OTLP_BASE_ENDPOINT=http://jaeger:4318
ENV OTEL_SDK_DISABLED=false

EXPOSE 8080
EXPOSE 42070

CMD ["./ShapeTreeWeb"]
