package webnotifications

import (
	"fmt"
	"io"
	"sync"
)

// Hub contains methods to manage channels and messages.
type Hub struct {
	bufSize  int
	counter  int
	mux      sync.Mutex
	msgMux   sync.RWMutex
	in       chan string
	out      map[int]chan string
	messages []string
}

// InitHub returns an initialized Hub struct.
func InitHub(bufSize int) *Hub {
	h := Hub{
		bufSize: bufSize,
		counter: 0,
		mux:     sync.Mutex{},
		msgMux:  sync.RWMutex{},
		in:      make(chan string),
		out:     make(map[int]chan string),
	}
	return &h
}

// GetInChannel returns the input channel.
func (h *Hub) GetInChannel() chan string {
	return h.in
}

// GetOutChannel registers a new channel.
func (h *Hub) GetOutChannel() (int, chan string) {
	h.mux.Lock()
	defer h.mux.Unlock()
	chanID := h.counter
	h.counter++
	c := make(chan string)
	h.out[chanID] = c
	go h.dumpToChannel(c)
	return chanID, c
}

// CloseOutChannel deregisters the given channel.
func (h *Hub) CloseOutChannel(chanID int) {
	h.mux.Lock()
	defer h.mux.Unlock()
	c, ok := h.out[chanID]
	if !ok {
		return
	}
	delete(h.out, chanID)
	close(c)
}

// Close will close all channels.
func (h *Hub) Close() {
	h.mux.Lock()
	defer h.mux.Unlock()
	close(h.in)
	for chanID, c := range h.out {
		delete(h.out, chanID)
		close(c)
	}
}

// Broadcast sends the given message to all registered listeners.
func (h *Hub) Broadcast(m string) {
	h.msgMux.Lock()
	h.messages = append(h.messages, m)
	if len(h.messages) > h.bufSize {
		h.messages = h.messages[len(h.messages)-h.bufSize:]
	}
	h.msgMux.Unlock()

	h.mux.Lock()
	for _, c := range h.out {
		c <- m
	}
	h.mux.Unlock()
}

// Dump writes messages to the given Writer.
func (h *Hub) Dump(w io.Writer) {
	h.msgMux.RLock()
	defer h.msgMux.RUnlock()
	for _, m := range h.messages {
		fmt.Fprintln(w, m)
	}
}

func (h *Hub) dumpToChannel(c chan string) {
	h.msgMux.RLock()
	defer h.msgMux.RUnlock()
	for _, m := range h.messages {
		c <- m
	}
}
