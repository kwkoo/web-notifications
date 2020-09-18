PREFIX=github.com/kwkoo
PACKAGE=webnotifications
OCP_PROJ=demo

BASE:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
COVERAGEOUTPUT=coverage.out
COVERAGEHTML=coverage.html
IMAGENAME="kwkoo/$(PACKAGE)"
VERSION="0.2"

.PHONY: run build clean test coverage image runcontainer
run:
	-@cd $(BASE)/src \
	&& \
	DOCROOT=$(BASE)/docroot \
	BUFFERSIZE=3 \
	PINGINTERVAL=10 \
	go run main.go

build:
	@echo "Building..."
	@cd $(BASE)/src \
	&& \
	go build -o $(BASE)/bin/$(PACKAGE) .

clean:
	@rm -rf \
	  $(BASE)/bin/$(PACKAGE) \
	  $(BASE)/$(COVERAGEOUTPUT) \
	  $(BASE)/$(COVERAGEHTML)

test:
	@cd $(BASE)/src && go clean -testcache
	@cd $(BASE)/src && go test -race $(PREFIX)/$(PACKAGE)

coverage:
	@cd $(BASE)/src && go test $(PREFIX)/$(PACKAGE) -cover -coverprofile=$(BASE)/$(COVERAGEOUTPUT)
	@cd $(BASE)/src && go tool cover -html=$(BASE)/$(COVERAGEOUTPUT) -o $(BASE)/$(COVERAGEHTML)
	open $(BASE)/$(COVERAGEHTML)

dockerimage: 
	docker build --rm -t $(IMAGENAME):$(VERSION) $(BASE)
	docker tag $(IMAGENAME):$(VERSION) quay.io/$(IMAGENAME):$(VERSION)
	docker tag $(IMAGENAME):$(VERSION) quay.io/$(IMAGENAME):latest
	docker login quay.io
	docker push quay.io/$(IMAGENAME):$(VERSION)
	docker push quay.io/$(IMAGENAME):latest

runcontainer:
	docker run \
	  --rm \
	  -it \
	  --name $(PACKAGE) \
	  -p 8080:8080 \
	  -e TZ=Asia/Singapore \
	  $(IMAGENAME):$(VERSION)

deployocp:
	oc new-project $(OCP_PROJ) || oc project $(OCP_PROJ)

	oc new-app \
	  -n $(OCP_PROJ) \
	  --name $(PACKAGE) \
	  --binary \
	  --docker-image=ghcr.io/kwkoo/go-toolset-7-centos7:1.15.2 \
	  -e TZ=Asia/Singapore

	@/bin/echo -n "Waiting for S2I builder istag to appear..."
	@while [ `oc get -n $(OCP_PROJ) istag go-toolset-7-centos7:1.15.2 -o name 2>/dev/null | wc -l` -lt 1 ]; do \
	  /bin/echo -n "."; \
	  sleep 1; \
	done
	@/bin/echo "done"

	oc start-build $(PACKAGE) \
	  -n $(OCP_PROJ) \
	  --follow \
	  --from-dir=$(BASE)/src

	oc expose -n $(OCP_PROJ) deploy/$(PACKAGE) --port=8080

	oc expose -n $(OCP_PROJ) svc/$(PACKAGE)

	@echo "Deployment successful"
	@echo "The application is now accessible at http://`oc get route/$(PACKAGE) -o jsonpath='{ .spec.host }'`"

cleanocp:
	-oc delete all -l app=$(PACKAGE) -n $(OCP_PROJ)
	-oc delete istag/go-toolset-7-centos7:1.15.2 -n $(OCP_PROJ)
	-oc delete is/go-toolset-7-centos7 -n $(OCP_PROJ)