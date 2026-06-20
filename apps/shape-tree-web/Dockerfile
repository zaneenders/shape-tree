ARG TARGETARCH

FROM alpine:3.21 AS arch-amd64
COPY apps/shape-tree-web/.build/x86_64-swift-linux-musl/release/ShapeTreeWeb /ShapeTreeWeb
COPY apps/shape-tree-web/.build/x86_64-swift-linux-musl/release/shape-tree-web_ShapeTreeWebAssets.resources /resources

FROM alpine:3.21 AS arch-arm64
COPY apps/shape-tree-web/.build/aarch64-swift-linux-musl/release/ShapeTreeWeb /ShapeTreeWeb
COPY apps/shape-tree-web/.build/aarch64-swift-linux-musl/release/shape-tree-web_ShapeTreeWebAssets.resources /resources

FROM arch-${TARGETARCH} AS selected

FROM alpine:3.21

COPY --from=selected /ShapeTreeWeb /usr/local/bin/
COPY --from=selected /resources /usr/local/bin/shape-tree-web_ShapeTreeWebAssets.resources

RUN adduser -D -h /home/web web
USER web
WORKDIR /data

EXPOSE 42069 42070
CMD ["ShapeTreeWeb"]
