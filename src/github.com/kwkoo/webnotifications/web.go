package webnotifications

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strings"

	"github.com/gorilla/websocket"
)

// WebHandler is a struct with methods for handling web requests.
type WebHandler struct {
	fileServer http.Handler
	hub        *Hub
	wsupgrader websocket.Upgrader
}

// InitWebHandler initializes the WebHandler struct.
func InitWebHandler(docRoot string, hub *Hub) WebHandler {
	wh := WebHandler{
		fileServer: http.FileServer(http.Dir(docRoot)),
		hub:        hub,
		wsupgrader: websocket.Upgrader{},
	}
	return wh
}

// CloseHub closes all channels.
func (wh WebHandler) CloseHub() {
	wh.hub.Close()
}

func (wh WebHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// do not log requests from probes
	//
	if strings.HasPrefix(r.Header.Get("User-Agent"), "kube-probe") {
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, "OK")
		return
	}

	path := r.URL.Path
	if strings.HasPrefix(path, "/api/") {
		wh.handleAPI(path[len("/api/"):], w, r)
		return
	}
	wh.fileServer.ServeHTTP(w, r)
}

func (wh WebHandler) handleAPI(path string, w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(path, "send") {
		wh.handleSend(path[len("send"):], w, r)
		return
	}
	if strings.HasPrefix(path, "messages") {
		wh.handleMessages(w, r)
		return
	}
	if strings.HasPrefix(path, "stream") {
		wh.handleStream(w, r)
		return
	}
	http.Error(w, "invalid API call", http.StatusNotFound)
}

func (wh WebHandler) handleSend(path string, w http.ResponseWriter, r *http.Request) {
	var message string
	if r.Method == http.MethodGet {
		if len(path) == 0 || path[0] != '/' {
			http.Error(w, "no message found in GET request", http.StatusInternalServerError)
			return
		}
		raw := path[1:]
		var err error
		message, err = url.QueryUnescape(raw)
		if err != nil {
			http.Error(w, "could not decode message", http.StatusInternalServerError)
			return
		}
	} else if r.Method == http.MethodPost || r.Method == http.MethodPut {
		defer r.Body.Close()
		b, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Printf("error reading request body: %s", err)
			http.Error(w, "error reading body", http.StatusInternalServerError)
			return
		}
		message = string(b)
	} else {
		http.Error(w, "invalid HTTP method", http.StatusInternalServerError)
		return
	}
	log.Printf("received messsage: %s", message)
	wh.hub.Broadcast(message)
	w.Header().Set("Content-Type", "text/plain")
	fmt.Fprint(w, "OK")
	return
}

func (wh WebHandler) handleStream(w http.ResponseWriter, r *http.Request) {
	c, err := wh.wsupgrader.Upgrade(w, r, nil)
	if err != nil {
		http.Error(w, fmt.Sprintf("could not upgrade to websocket: %v", err), http.StatusInternalServerError)
		return
	}
	defer c.Close()
	chanID, outChan := wh.hub.GetOutChannel()

	// we need to read from the websocket in order to know when the client
	// terminates the connection
	go func() {
		for {
			if _, _, err := c.NextReader(); err != nil {
				wh.hub.CloseOutChannel(chanID)
				c.Close()
				break
			}
		}
		log.Printf("read goroutine terminating for channel ID %d", chanID)
	}()

	defer wh.hub.CloseOutChannel(chanID)
	for msg := range outChan {
		if err := c.WriteMessage(websocket.TextMessage, []byte(msg)); err != nil {
			return
		}
	}
	log.Printf("writes terminated for channel ID %d", chanID)
}

func (wh WebHandler) handleMessages(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	wh.hub.Dump(w)
	fmt.Fprint(w, "End")
	return
}
