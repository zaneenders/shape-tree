# syntax=docker/dockerfile:1

ARG SWIFT_VERSION=6.3.2

# Static Linux SDK for a fully static server binary (Alpine runtime).
ARG SWIFT_STATIC_SDK_URL=https://download.swift.org/swift-6.3.2-release/static-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_static-linux-0.1.0.artifactbundle.tar.gz
ARG SWIFT_STATIC_SDK_CHECKSUM=3fd798bef6f4408f1ea5a6f94ce4d4052830c4326ab85ebc04f983f01b3da407

# Build mode: release (default) or debug.
ARG BUILD_CONFIGURATION=release

# -----------------------------------------------------------------------------
# Build: statically linked Hummingbird server
# -----------------------------------------------------------------------------
FROM swift:${SWIFT_VERSION}-noble AS build

ARG SWIFT_STATIC_SDK_URL
ARG SWIFT_STATIC_SDK_CHECKSUM
ARG TARGETARCH
ARG BUILD_CONFIGURATION

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN swift sdk install "${SWIFT_STATIC_SDK_URL}" --checksum "${SWIFT_STATIC_SDK_CHECKSUM}"

WORKDIR /app

COPY Package.swift Package.resolved ./
RUN swift package resolve

COPY Sources ./Sources
COPY Tests ./Tests

RUN case "${TARGETARCH}" in \
      amd64) echo "x86_64-swift-linux-musl" > /.swift-musl-sdk ;; \
      arm64) echo "aarch64-swift-linux-musl" > /.swift-musl-sdk ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac

RUN SWIFT_MUSL_SDK="$(cat /.swift-musl-sdk)" \
  && swift build -c "${BUILD_CONFIGURATION}" --product ShapeTree --swift-sdk "${SWIFT_MUSL_SDK}" \
  && mkdir -p /output \
  && cp ".build/${SWIFT_MUSL_SDK}/${BUILD_CONFIGURATION}/ShapeTree" /output/ShapeTree

# -----------------------------------------------------------------------------
# Runtime: static binary on Alpine (git + openssh-client for journal commits)
# -----------------------------------------------------------------------------
FROM alpine:3.21

RUN apk add --no-cache git openssh-client

COPY --from=build /output/ShapeTree /usr/local/bin/

RUN adduser -D -h /home/shape-tree shape-tree
USER shape-tree
WORKDIR /data
VOLUME /data

EXPOSE 42067 42068
CMD ["ShapeTree"]
