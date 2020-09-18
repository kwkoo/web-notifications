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
	-rm -rf /tmp/ocp
	mkdir /tmp/ocp
	mkdir -p /tmp/ocp/.s2i/bin
	cp $(BASE)/scripts/s2i_assemble /tmp/ocp/.s2i/bin/assemble
	cp -r $(BASE)/docroot $(BASE)/src /tmp/ocp/
	oc import-image \
	  --confirm \
	  ghcr.io/kwkoo/go-toolset-7-centos7:1.15.2
	@/bin/echo -n "Waiting for Go imagestreamtag to be created..."
	@while true; do \
	  oc get istag go-toolset-7-centos7:1.15.2 2>/dev/null 1>/dev/null;  \
	  if [ $$? -eq 0 ]; then /bin/echo "done"; break; fi; \
	  /bin/echo -n "."; \
	  sleep 1; \
	done
	oc new-build \
	  --name $(PACKAGE) \
	  --binary \
	  --labels=app=$(PACKAGE) \
	  -i go-toolset-7-centos7:1.15.2
	oc start-build \
	  $(PACKAGE) \
	  --from-dir=/tmp/ocp \
	  --follow
	rm -rf /tmp/ocp

	oc new-app \
	  --name $(PACKAGE) \
	  -i $(PACKAGE) \
	  -e DOCROOT=/opt/app-root/docroot \
	  -e TZ=Asia/Singapore
	
	oc expose deployment/$(PACKAGE) --port=8080
	oc expose svc/$(PACKAGE)
	@echo "Deployment successful"
	@echo "The application is now accessible at http://`oc get route/$(PACKAGE) -o jsonpath='{ .spec.host }'`"

cleanocp:
	-oc delete all -l app=$(PACKAGE) -n $(OCP_PROJ)
	-oc delete istag/go-toolset-7-centos7:1.15.2 -n $(OCP_PROJ)
	-oc delete is/go-toolset-7-centos7 -n $(OCP_PROJ)
	-rm -rf /tmp/ocp