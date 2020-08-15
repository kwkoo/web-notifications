FROM golang:1.15.0 as builder
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
COPY --from=builder /go/bin/${PACKAGE} /

COPY docroot/* /docroot/

USER 1001
EXPOSE 8080

ENTRYPOINT ["/webnotifications"]
CMD ["--docroot", "/docroot"]