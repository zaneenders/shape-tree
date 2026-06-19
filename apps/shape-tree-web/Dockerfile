FROM alpine:3.21

ARG BINARY_PATH=apps/shape-tree-web/.build/x86_64-swift-linux-musl/release/ShapeTreeWeb
COPY ${BINARY_PATH} /usr/local/bin/

RUN adduser -D -h /home/web web
USER web
WORKDIR /data

EXPOSE 8080
CMD ["ShapeTreeWeb"]
