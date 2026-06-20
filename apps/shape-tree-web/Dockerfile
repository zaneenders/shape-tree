FROM alpine:3.21

ARG BINARY_PATH=apps/shape-tree-web/.build/x86_64-swift-linux-musl/release/ShapeTreeWeb
ARG RESOURCES_PATH=apps/shape-tree-web/.build/x86_64-swift-linux-musl/release/shape-tree-web_ShapeTreeWebAssets.resources

COPY ${BINARY_PATH} /usr/local/bin/
COPY ${RESOURCES_PATH} /usr/local/bin/shape-tree-web_ShapeTreeWebAssets.resources

RUN adduser -D -h /home/web web
USER web
WORKDIR /data

EXPOSE 8080
CMD ["ShapeTreeWeb"]
