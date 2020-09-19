FROM golang:1.15.2 as builder
ARG PREFIX=github.com/kwkoo
ARG PACKAGE=webnotifications
LABEL builder=true
COPY src /go/src/
RUN \
  set -x \
  && \
  cd /go/src/ \
  && \
  CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /go/bin/${PACKAGE} .

FROM scratch
LABEL maintainer="kin.wai.koo@gmail.com"
LABEL builder=false
LABEL org.opencontainers.image.source="https://github.com/kwkoo/web-notifications"
COPY --from=builder /go/bin/${PACKAGE} /

COPY src/docroot/* /docroot/

USER 1001
EXPOSE 8080

ENTRYPOINT ["/webnotifications"]
CMD ["--docroot", "/docroot"]