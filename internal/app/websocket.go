package app

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/coder/websocket"
)

// Hub manages WebSocket subscriptions and broadcasting
type Hub struct {
	mu      sync.RWMutex
	clients map[*Client]struct{}
}

type Client struct {
	hub           *Hub
	conn          *websocket.Conn
	subscriptions map[string]bool
	mu            sync.Mutex
	send          chan []byte
}

func NewHub() *Hub {
	return &Hub{
		clients: make(map[*Client]struct{}),
	}
}

func (h *Hub) Run() {
	// Hub is passive - broadcasting is done directly
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	delete(h.clients, c)
	h.mu.Unlock()
}

// Broadcast sends a message to all clients subscribed to the given channel
func (h *Hub) Broadcast(channel string, data interface{}) {
	msg, err := json.Marshal(map[string]interface{}{
		"channel": channel,
		"data":    data,
	})
	if err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()

	for c := range h.clients {
		c.mu.Lock()
		subscribed := c.subscriptions[channel]
		c.mu.Unlock()
		if subscribed {
			select {
			case c.send <- msg:
			default:
				// Client too slow, skip
			}
		}
	}
}

func HandleWebSocketConnection(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		InsecureSkipVerify: true, // Allow any origin
	})
	if err != nil {
		log.Printf("WebSocket accept error: %v", err)
		return
	}

	client := &Client{
		hub:           hub,
		conn:          conn,
		subscriptions: make(map[string]bool),
		send:          make(chan []byte, 256),
	}

	hub.Register(client)
	defer hub.Unregister(client)

	// Writer goroutine
	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	go func() {
		defer cancel()
		for {
			select {
			case msg, ok := <-client.send:
				if !ok {
					return
				}
				writeCtx, writeCancel := context.WithTimeout(ctx, 5*time.Second)
				err := conn.Write(writeCtx, websocket.MessageText, msg)
				writeCancel()
				if err != nil {
					return
				}
			case <-ctx.Done():
				return
			}
		}
	}()

	// Reader loop - handle subscribe/unsubscribe messages
	for {
		_, msg, err := conn.Read(ctx)
		if err != nil {
			break
		}

		var cmd struct {
			Subscribe   string `json:"subscribe"`
			Unsubscribe string `json:"unsubscribe"`
		}
		if err := json.Unmarshal(msg, &cmd); err != nil {
			continue
		}

		client.mu.Lock()
		if cmd.Subscribe != "" {
			client.subscriptions[cmd.Subscribe] = true
		}
		if cmd.Unsubscribe != "" {
			delete(client.subscriptions, cmd.Unsubscribe)
		}
		client.mu.Unlock()
	}

	close(client.send)
}
