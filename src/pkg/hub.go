package pkg

import (
	"fmt"
	"io"
	"log"
	"sync"
	"time"
)

// Hub contains methods to manage channels and messages.
type Hub struct {
	bufSize      int
	pingInterval int
	counter      int
	mux          sync.Mutex
	msgMux       sync.RWMutex
	endPing      chan bool
	in           chan string
	out          map[int]chan string
	messages     []LogMessage
}

// InitHub returns an initialized Hub struct.
func InitHub(bufSize, pingInterval int) *Hub {
	h := Hub{
		bufSize: bufSize,
		counter: 0,
		mux:     sync.Mutex{},
		msgMux:  sync.RWMutex{},
		endPing: make(chan bool),
		in:      make(chan string),
		out:     make(map[int]chan string),
	}

	if pingInterval > 0 {
		go func() {
			log.Printf("ping interval set to %d seconds", pingInterval)
			for {
				select {
				case <-h.endPing:
					log.Print("ping goroutine terminating")
					return
				case <-time.After(time.Duration(pingInterval) * time.Second):
					h.Ping()
					break
				}
			}
		}()
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
	log.Printf("registered client with ID %d", chanID)
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
	log.Printf("deregistered client with ID %d", chanID)
	close(c)
}

// Close will close all channels.
func (h *Hub) Close() {
	if h.pingInterval > 0 {
		h.endPing <- true
	}
	h.mux.Lock()
	defer h.mux.Unlock()
	close(h.in)
	for chanID, c := range h.out {
		delete(h.out, chanID)
		close(c)
	}
}

// Ping sends a ping to all registered listeners.
// Pings begin with 1.
func (h *Hub) Ping() {
	h.realBroadcast("1")
}

// Broadcast sends the given message to all registered listeners.
// Real messages begin with 0.
func (h *Hub) Broadcast(m string) {
	h.msgMux.Lock()
	msg := NewLogMessage(m)
	h.messages = append(h.messages, msg)
	if len(h.messages) > h.bufSize {
		h.messages = h.messages[len(h.messages)-h.bufSize:]
	}
	h.msgMux.Unlock()
	h.realBroadcast("0" + msg.String())
}

// Does not know about pings - sends strings only.
func (h *Hub) realBroadcast(m string) {
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
		c <- m.String()
	}
}
