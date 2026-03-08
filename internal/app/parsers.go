package app

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

// ParseGithub parses a GitHub Actions webhook payload
func ParseGithub(ctx context.Context, db *DB, hub *Hub, payload map[string]interface{}) error {
	repo, _ := payload["repository"].(string)
	parts := strings.SplitN(repo, "/", 2)
	if len(parts) != 2 {
		return fmt.Errorf("invalid repository: %s", repo)
	}
	username := parts[0]
	projectName := parts[1]
	workflow, _ := payload["workflow"].(string)
	statusCode, _ := payload["status"].(string)

	s := &Status{
		Service:     "github",
		Username:    username,
		ProjectName: projectName,
		Workflow:    workflow,
	}

	if DebugMode {
		raw, _ := json.Marshal(payload)
		s.Payload = strPtr(string(raw))
	}

	// Set colors based on status
	s.Yellow = boolPtr(false)
	switch statusCode {
	case "":
		s.Yellow = boolPtr(true)
	case "success":
		s.Red = boolPtr(false)
	case "failure":
		s.Red = boolPtr(true)
	default:
		return fmt.Errorf("unknown status: %s", statusCode)
	}

	if err := UpsertStatus(ctx, db, s); err != nil {
		return err
	}

	go UpdateDevicesForStatus(ctx, db, hub, username, projectName)
	return nil
}

// ParseTravis parses a Travis CI webhook payload
func ParseTravis(ctx context.Context, db *DB, hub *Hub, payloadStr string) error {
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(payloadStr), &payload); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	// Ignore pull requests
	if typ, _ := payload["type"].(string); typ == "pull_request" {
		return nil
	}

	repo, _ := payload["repository"].(map[string]interface{})
	if repo == nil {
		return fmt.Errorf("missing repository")
	}

	repoID := fmt.Sprintf("%v", repo["id"])
	ownerName, _ := repo["owner_name"].(string)
	repoName, _ := repo["name"].(string)
	statusMessage, _ := payload["status_message"].(string)

	s := &Status{
		Service:     "travis",
		ProjectID:   repoID,
		Username:    ownerName,
		ProjectName: repoName,
	}

	if DebugMode {
		s.Payload = &payloadStr
	}

	// Set colors based on status message
	s.Yellow = boolPtr(false)
	switch statusMessage {
	case "Pending":
		s.Yellow = boolPtr(true)
	case "Passed", "Fixed":
		s.Red = boolPtr(false)
	default:
		s.Red = boolPtr(true)
	}

	if err := UpsertStatus(ctx, db, s); err != nil {
		return err
	}

	go UpdateDevicesForStatus(ctx, db, hub, ownerName, repoName)
	return nil
}

// ParseCircle parses a Circle CI webhook payload
func ParseCircle(ctx context.Context, db *DB, hub *Hub, payload map[string]interface{}) error {
	// Only handle workflow-completed events
	typ, _ := payload["type"].(string)
	if typ != "workflow-completed" {
		return nil
	}

	// Only process main/master branches
	pipeline, _ := payload["pipeline"].(map[string]interface{})
	vcs, _ := pipeline["vcs"].(map[string]interface{})
	branch, _ := vcs["branch"].(string)
	if branch != "main" && branch != "master" {
		return nil
	}

	org, _ := payload["organization"].(map[string]interface{})
	orgName, _ := org["name"].(string)

	project, _ := payload["project"].(map[string]interface{})
	projectName, _ := project["name"].(string)

	workflow, _ := payload["workflow"].(map[string]interface{})
	workflowStatus, _ := workflow["status"].(string)

	s := &Status{
		Service:     "circle",
		Username:    orgName,
		ProjectName: projectName,
	}

	if DebugMode {
		raw, _ := json.Marshal(payload)
		s.Payload = strPtr(string(raw))
	}

	// Set colors - no yellow support for Circle
	s.Yellow = boolPtr(false)
	s.Red = boolPtr(workflowStatus != "success")

	if err := UpsertStatus(ctx, db, s); err != nil {
		return err
	}

	go UpdateDevicesForStatus(ctx, db, hub, orgName, projectName)
	return nil
}
