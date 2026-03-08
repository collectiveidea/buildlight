package app

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"buildlight"
)

type Handler struct {
	db  *DB
	hub *Hub
}

// WebhookCreate handles POST / - receives CI webhooks
func (h *Handler) WebhookCreate(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	// Try to detect service type
	contentType := r.Header.Get("Content-Type")

	// Travis CI sends payload as form-encoded
	if contentType == "application/x-www-form-urlencoded" {
		r.Body = io.NopCloser(bytes.NewReader(body))
		r.ParseForm()
		payloadStr := r.FormValue("payload")
		if payloadStr != "" {
			if err := ParseTravis(r.Context(), h.db, h.hub, payloadStr); err != nil {
				log.Printf("ParseTravis error: %v", err)
			}
			w.WriteHeader(http.StatusOK)
			return
		}
	}

	// Try JSON parsing
	var payload map[string]interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	// Check for Circle CI
	circleEventType := r.Header.Get("Circleci-Event-Type")
	if circleEventType != "" {
		if err := ParseCircle(r.Context(), h.db, h.hub, payload); err != nil {
			log.Printf("ParseCircle error: %v", err)
		}
		w.WriteHeader(http.StatusOK)
		return
	}

	// Check for GitHub Actions (has "repository" as a string like "owner/repo")
	if repo, ok := payload["repository"].(string); ok && strings.Contains(repo, "/") {
		if err := ParseGithub(r.Context(), h.db, h.hub, payload); err != nil {
			log.Printf("ParseGithub error: %v", err)
		}
		w.WriteHeader(http.StatusOK)
		return
	}

	// Check for Travis CI JSON payload
	if payloadStr, ok := payload["payload"].(string); ok {
		if err := ParseTravis(r.Context(), h.db, h.hub, payloadStr); err != nil {
			log.Printf("ParseTravis error: %v", err)
		}
		w.WriteHeader(http.StatusOK)
		return
	}

	http.Error(w, "Bad request", http.StatusBadRequest)
}

// ColorsIndex handles GET / - show all colors
func (h *Handler) ColorsIndex(w http.ResponseWriter, r *http.Request) {
	h.renderColors(w, r, nil)
}

// ColorsShow handles GET /{id} - show colors for specific usernames
func (h *Handler) ColorsShow(w http.ResponseWriter, r *http.Request) {
	ids := strings.Split(r.PathValue("id"), ",")
	h.renderColors(w, r, ids)
}

func (h *Handler) renderColors(w http.ResponseWriter, r *http.Request, ids []string) {
	accept := r.Header.Get("Accept")

	// Check for .ryg extension
	path := r.URL.Path
	if strings.HasSuffix(path, ".ryg") {
		h.streamRYG(w, r, ids)
		return
	}

	colors, err := GetColors(r.Context(), h.db, ids)
	if err != nil {
		renderErrorPage(w, http.StatusInternalServerError)
		return
	}

	// JSON response
	if strings.Contains(accept, "application/json") || r.URL.Query().Get("format") == "json" {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(colors)
		return
	}

	// HTML response
	h.renderColorsHTML(w, colors)
}

func (h *Handler) streamRYG(w http.ResponseWriter, r *http.Request, ids []string) {
	w.Header().Set("Content-Type", "text/ryg")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	for {
		select {
		case <-r.Context().Done():
			return
		default:
			colors, err := GetColors(r.Context(), h.db, ids)
			if err != nil {
				return
			}
			fmt.Fprint(w, colors.RYG())
			flusher.Flush()
			time.Sleep(1 * time.Second)
		}
	}
}

func (h *Handler) renderColorsHTML(w http.ResponseWriter, colors Colors) {
	ReloadTemplates()
	w.Header().Set("Content-Type", "text/html; charset=utf-8")

	data := struct {
		Colors  Colors
		Favicon string
		BodyAttrs string
	}{
		Colors:  colors,
		Favicon: faviconForColors(colors),
		BodyAttrs: bodyAttrsForColors(colors),
	}

	var buf bytes.Buffer
	if err := Templates.ExecuteTemplate(&buf, "layout.html", data); err != nil {
		log.Printf("Template error: %v", err)
		renderErrorPage(w, http.StatusInternalServerError)
		return
	}
	w.Write(buf.Bytes())
}

// DeviceShow handles GET /devices/{id}
func (h *Handler) DeviceShow(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	device, err := FindDeviceBySlugOrID(r.Context(), h.db, id)
	if err != nil {
		renderErrorPage(w, http.StatusNotFound)
		return
	}

	colors, err := GetDeviceColors(r.Context(), h.db, device)
	if err != nil {
		renderErrorPage(w, http.StatusInternalServerError)
		return
	}

	accept := r.Header.Get("Accept")
	if strings.Contains(accept, "application/json") || r.URL.Query().Get("format") == "json" {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(colors)
		return
	}

	h.renderColorsHTML(w, colors)
}

// APIDeviceShow handles GET /api/devices/{id}
func (h *Handler) APIDeviceShow(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	device, err := FindDeviceByID(r.Context(), h.db, id)
	if err != nil {
		renderErrorPage(w, http.StatusNotFound)
		return
	}

	colors, err := GetDeviceColors(r.Context(), h.db, device)
	if err != nil {
		renderErrorPage(w, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"colors": colors.AsBooleans(),
		"ryg":    colors.RYG(),
	})
}

// APIDeviceTrigger handles POST /api/device/trigger
func (h *Handler) APIDeviceTrigger(w http.ResponseWriter, r *http.Request) {
	var body struct {
		CoreID string `json:"coreid"`
	}

	// Try form value first (Particle sends form data)
	coreID := r.FormValue("coreid")
	if coreID == "" {
		json.NewDecoder(r.Body).Decode(&body)
		coreID = body.CoreID
	}

	if coreID != "" {
		device, err := FindDeviceByIdentifier(r.Context(), h.db, coreID)
		if err == nil {
			TriggerDevice(r.Context(), h.db, device)
		}
	}

	w.WriteHeader(http.StatusOK)
}

// APIRedShow handles GET /api/device/{id}/red
func (h *Handler) APIRedShow(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	device, err := FindDeviceByIdentifier(r.Context(), h.db, id)
	if err != nil {
		renderErrorPage(w, http.StatusNotFound)
		return
	}

	redStatuses, err := GetRedStatuses(r.Context(), h.db, device)
	if err != nil {
		renderErrorPage(w, http.StatusInternalServerError)
		return
	}

	accept := r.Header.Get("Accept")
	if strings.Contains(accept, "application/json") || r.URL.Query().Get("format") == "json" {
		type redProject struct {
			Username    string `json:"username"`
			ProjectName string `json:"project_name"`
		}
		var projects []redProject
		for _, s := range redStatuses {
			projects = append(projects, redProject{
				Username:    s.Username,
				ProjectName: s.ProjectName,
			})
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(projects)
		return
	}

	// HTML response
	ReloadTemplates()
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	data := struct {
		RedProjects []Status
	}{
		RedProjects: redStatuses,
	}
	if err := Templates.ExecuteTemplate(w, "red.html", data); err != nil {
		log.Printf("Template error: %v", err)
	}
}

// HandleWebSocket handles GET /ws
func (h *Handler) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	HandleWebSocketConnection(h.hub, w, r)
}

// Helper functions for templates

func faviconForColors(colors Colors) string {
	filename := "/public/favicon"
	if colors.Red > 0 {
		filename += "-failing"
	} else {
		filename += "-passing"
	}
	if colors.Yellow {
		filename += "-building"
	}
	filename += ".ico"
	return filename
}

func bodyAttrsForColors(colors Colors) string {
	var attrs string
	if colors.Red > 0 {
		attrs += " data-failing"
	} else {
		attrs += " data-passing"
	}
	if colors.Yellow {
		attrs += " data-building"
	}
	return attrs
}

// renderErrorPage serves a static error page from public/ (e.g. 404.html, 500.html).
// Falls back to http.Error if the file doesn't exist.
func renderErrorPage(w http.ResponseWriter, code int) {
	data, err := buildlight.ReadPublicFile(fmt.Sprintf("%d.html", code))
	if err != nil {
		http.Error(w, http.StatusText(code), code)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(code)
	w.Write(data)
}
