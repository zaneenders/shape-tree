FROM alpine:3.21

ARG WEB_BINARY_PATH=apps/shape-tree-web/.build/aarch64-swift-linux-musl/release/ShapeTreeWeb
ARG WEB_RESOURCES_PATH=apps/shape-tree-web/.build/aarch64-swift-linux-musl/release/shape-tree-web_ShapeTreeWebAssets.resources

COPY ${WEB_BINARY_PATH} /usr/local/bin/
COPY ${WEB_RESOURCES_PATH} /usr/local/bin/shape-tree-web_ShapeTreeWebAssets.resources

RUN adduser -D -h /home/web web
USER web
WORKDIR /data

EXPOSE 42069 42070
CMD ["ShapeTreeWeb"]
