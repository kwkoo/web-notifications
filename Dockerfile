FROM golang:1.10.3 as builder
ARG PREFIX=github.com/kwkoo
ARG PACKAGE=onboarding
LABEL builder=true
COPY src /go/src/
RUN set -x && \
	cd /go/src/${PREFIX}/${PACKAGE}/cmd/${PACKAGE} && \
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /go/bin/${PACKAGE} .

FROM scratch
LABEL maintainer="glug71@gmail.com"
LABEL builder=false
COPY --from=builder /go/bin/${PACKAGE} /

COPY docroot/* /docroot/

# we need to copy the certificates over because we're connecting over SSL
COPY --from=builder /etc/ssl /etc/ssl

# copy timezone info
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /usr/share/zoneinfo/Asia/Singapore /etc/localtime

USER 1001
EXPOSE 8080

ENTRYPOINT ["/onboarding"]
