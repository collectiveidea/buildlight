package app

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
)

// TriggerWebhook sends a POST to the device's webhook URL
func TriggerWebhook(d *Device, colors Colors) {
	body, err := json.Marshal(map[string]interface{}{
		"colors": colors.AsBooleans(),
	})
	if err != nil {
		log.Printf("TriggerWebhook marshal error: %v", err)
		return
	}

	req, err := http.NewRequest("POST", d.WebhookURL, bytes.NewReader(body))
	if err != nil {
		log.Printf("TriggerWebhook request error: %v", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-ryg", colors.RYG())
	req.Header.Set("x-device-url", fmt.Sprintf("https://%s/api/devices/%s", AppHost, d.ID))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("TriggerWebhook error for device %s: %v", d.Name, err)
		return
	}
	resp.Body.Close()
}

// TriggerParticle publishes a build_state event to Particle
func TriggerParticle(d *Device) {
	if ParticleAccessToken == "" {
		return
	}

	body, _ := json.Marshal(map[string]interface{}{
		"name":    "build_state",
		"data":    d.Status,
		"ttl":     3600,
		"private": false,
	})

	req, err := http.NewRequest("POST", "https://api.particle.io/v1/devices/events", bytes.NewReader(body))
	if err != nil {
		log.Printf("TriggerParticle request error: %v", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+ParticleAccessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("TriggerParticle error: %v", err)
		return
	}
	resp.Body.Close()
}
