ARG TARGETARCH
ARG BUILD_CONFIG=release

FROM alpine:3.21 AS arch-amd64
ARG BUILD_CONFIG
COPY apps/shape-tree-web/.build/x86_64-swift-linux-musl/${BUILD_CONFIG}/ShapeTreeWeb /ShapeTreeWeb
COPY apps/shape-tree-web/.build/x86_64-swift-linux-musl/${BUILD_CONFIG}/shape-tree-web_ShapeTreeWebAssets.resources /resources

FROM alpine:3.21 AS arch-arm64
ARG BUILD_CONFIG
COPY apps/shape-tree-web/.build/aarch64-swift-linux-musl/${BUILD_CONFIG}/ShapeTreeWeb /ShapeTreeWeb
COPY apps/shape-tree-web/.build/aarch64-swift-linux-musl/${BUILD_CONFIG}/shape-tree-web_ShapeTreeWebAssets.resources /resources

FROM arch-${TARGETARCH} AS selected

FROM alpine:3.21

COPY --from=selected /ShapeTreeWeb /usr/local/bin/
COPY --from=selected /resources /usr/local/bin/shape-tree-web_ShapeTreeWebAssets.resources

RUN mkdir -p /content

RUN adduser -D -h /home/web web
USER web
WORKDIR /data

EXPOSE 42069 42070
CMD ["ShapeTreeWeb"]
