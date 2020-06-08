PREFIX=github.com/kwkoo
PACKAGE=webnotifications

GOPATH:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
GOBIN=$(GOPATH)/bin
COVERAGEOUTPUT=coverage.out
COVERAGEHTML=coverage.html
IMAGENAME="kwkoo/$(PACKAGE)"
VERSION="0.1"

.PHONY: run build clean test coverage image runcontainer
run:
	@GOPATH=$(GOPATH) \
	GOBIN=$(GOBIN) \
	DOCROOT=$(GOPATH)/docroot \
	BUFFERSIZE=3 \
	go run $(GOPATH)/src/$(PREFIX)/$(PACKAGE)/cmd/$(PACKAGE)/main.go

build:
	@echo "Building..."
	@GOPATH=$(GOPATH) \
	GOBIN=$(GOBIN) \
	go build -o $(GOBIN)/$(PACKAGE) $(PREFIX)/$(PACKAGE)/cmd/$(PACKAGE)

clean:
	rm -f \
	  $(GOPATH)/bin/$(PACKAGE) \
	  $(GOPATH)/pkg/*/$(PACKAGE).a \
	  $(GOPATH)/$(COVERAGEOUTPUT) \
	  $(GOPATH)/$(COVERAGEHTML)

test:
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go clean -testcache
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go test -race $(PREFIX)/$(PACKAGE)

coverage:
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go test $(PREFIX)/$(PACKAGE) -cover -coverprofile=$(GOPATH)/$(COVERAGEOUTPUT)
	@GOPATH=$(GOPATH) GOBIN=$(GOBIN) go tool cover -html=$(GOPATH)/$(COVERAGEOUTPUT) -o $(GOPATH)/$(COVERAGEHTML)
	open $(GOPATH)/$(COVERAGEHTML)

image: 
	docker build --rm -t $(IMAGENAME):$(VERSION) $(GOPATH)

runcontainer:
	docker run \
	  --rm \
	  -it \
	  --name $(PACKAGE) \
	  -p 8080:8080 \
	  -v $(GOPATH)/config:/config \
	  -e DOCROOT=/docroot \
	  $(IMAGENAME):$(VERSION)

#deployocp:
#	-oc new-project $(OCP_PROJ)
#	-oc project $(OCP_PROJ)
#	-oc delete secret/$(PACKAGE)-admin
#	-oc delete configmap/$(PACKAGE)
#	oc create secret generic $(PACKAGE)-admin --from-literal=ADMINSECRET=$(ADMINSECRET)
#	$(GOPATH)/scripts/create_credentials.sh $(OCP_USERS) > /tmp/credentials.tsv
#	oc create configmap $(PACKAGE) --from-file=/tmp/credentials.tsv
#	rm /tmp/credentials.tsv
#
#	-rm -rf /tmp/ocp
#	mkdir /tmp/ocp
#	mkdir -p /tmp/ocp/.s2i/bin
#	cp $(GOPATH)/scripts/s2i_assemble /tmp/ocp/.s2i/bin/assemble
#	cp -r $(GOPATH)/docroot $(GOPATH)/src /tmp/ocp/
#	oc import-image \
#	  --confirm \
#	  docker.io/centos/go-toolset-7-centos7:latest
#	oc new-build \
#	  --name onboarding \
#	  --binary \
#	  --labels=app=onboarding \
#	  -i go-toolset-7-centos7:latest
#	oc start-build \
#	  onboarding \
#	  --from-dir=/tmp/ocp \
#	  --follow
#	rm -rf /tmp/ocp
#
#	oc new-app \
#	  --name $(PACKAGE) \
#	  -i $(PACKAGE) \
#	  -e DOCROOT=/opt/app-root/docroot \
#	  -e CREDENTIALS=/config/credentials.tsv
#	
#	# Bind secret to environment
#	oc patch \
#	  dc/$(PACKAGE) \
#	  --patch '{"spec":{"template":{"spec":{"containers":[{"name": "onboarding", "envFrom":[{"secretRef":{"name":"onboarding-admin"}}]}]}}}}'

	# Mount configmap as volume
#	oc set volume \
#	  dc/$(PACKAGE) \
#	  --add \
#	  --name="volume-credentials" \
#	  --configmap-name="onboarding"
#	oc patch \
#	  dc/$(PACKAGE) \
#	  --patch '{"spec":{"template":{"spec":{"containers":[{"name": "onboarding", "volumeMounts":[{"name":"volume-credentials","mountPath":"/config"}]}]}}}}'
#	
#	oc expose dc/$(PACKAGE) --port=8080
#	oc expose svc/$(PACKAGE)
#	oc patch route/$(PACKAGE) -p '{"spec":{"host":"username'`oc get route/$(PACKAGE) -o jsonpath='{ .spec.host }' | sed -e 's/[^.]*\(.*\)/\1/'`'"}}'
#	@echo "Deployment successful"
#	@echo "The application is now accessible at http://`oc get route/$(PACKAGE) -o jsonpath='{ .spec.host }'`"
