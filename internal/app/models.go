package app

import (
	"context"
	"strings"
	"time"
)

// Status represents a CI build status
type Status struct {
	ID          int
	Service     string
	ProjectID   string
	ProjectName string
	Username    string
	Workflow    string
	Red         *bool
	Yellow      *bool
	Payload     *string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

func (s *Status) Name() string {
	return s.Username + "/" + s.ProjectName
}

// Colors represents the aggregated color state
type Colors struct {
	Red    int  `json:"red"`
	Yellow bool `json:"yellow"`
	Green  bool `json:"green"`
}

// ColorsAsBooleans returns colors with red as a boolean
type ColorsAsBooleans struct {
	Red    bool `json:"red"`
	Yellow bool `json:"yellow"`
	Green  bool `json:"green"`
}

func (c Colors) AsBooleans() ColorsAsBooleans {
	return ColorsAsBooleans{
		Red:    c.Red > 0,
		Yellow: c.Yellow,
		Green:  c.Green,
	}
}

func (c Colors) RYG() string {
	var b strings.Builder
	if c.Red > 0 {
		b.WriteByte('R')
	} else {
		b.WriteByte('r')
	}
	if c.Yellow {
		b.WriteByte('Y')
	} else {
		b.WriteByte('y')
	}
	if c.Green {
		b.WriteByte('G')
	} else {
		b.WriteByte('g')
	}
	return b.String()
}

// CurrentStatus returns a status string like "passing", "failing-building", etc.
func CurrentStatus(ctx context.Context, db *DB, usernames []string, projects []string) (string, error) {
	statuses, err := findStatusesForDevice(ctx, db, usernames, projects)
	if err != nil {
		return "", err
	}

	hasRed := false
	hasYellow := false
	for _, s := range statuses {
		if s.Red != nil && *s.Red {
			hasRed = true
		}
		if s.Yellow != nil && *s.Yellow {
			hasYellow = true
		}
	}

	var parts []string
	if !hasRed {
		parts = append(parts, "passing")
	}
	if hasRed {
		parts = append(parts, "failing")
	}
	if hasYellow {
		parts = append(parts, "building")
	}
	return strings.Join(parts, "-"), nil
}

// GetColors returns aggregated colors for given usernames (nil = all)
func GetColors(ctx context.Context, db *DB, usernames []string) (Colors, error) {
	var redCount int
	var yellowExists bool

	if len(usernames) == 0 {
		err := db.pool.QueryRow(ctx,
			"SELECT COUNT(*) FROM statuses WHERE red = true").Scan(&redCount)
		if err != nil {
			return Colors{}, err
		}
		err = db.pool.QueryRow(ctx,
			"SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true)").Scan(&yellowExists)
		if err != nil {
			return Colors{}, err
		}
	} else {
		err := db.pool.QueryRow(ctx,
			"SELECT COUNT(*) FROM statuses WHERE red = true AND username = ANY($1)", usernames).Scan(&redCount)
		if err != nil {
			return Colors{}, err
		}
		err = db.pool.QueryRow(ctx,
			"SELECT EXISTS(SELECT 1 FROM statuses WHERE yellow = true AND username = ANY($1))", usernames).Scan(&yellowExists)
		if err != nil {
			return Colors{}, err
		}
	}

	return Colors{
		Red:    redCount,
		Yellow: yellowExists,
		Green:  redCount == 0,
	}, nil
}

// GetDeviceColors returns colors for a specific device's watched statuses
func GetDeviceColors(ctx context.Context, db *DB, d *Device) (Colors, error) {
	statuses, err := findStatusesForDevice(ctx, db, d.Usernames, d.Projects)
	if err != nil {
		return Colors{}, err
	}

	redCount := 0
	yellowExists := false
	for _, s := range statuses {
		if s.Red != nil && *s.Red {
			redCount++
		}
		if s.Yellow != nil && *s.Yellow {
			yellowExists = true
		}
	}

	return Colors{
		Red:    redCount,
		Yellow: yellowExists,
		Green:  redCount == 0,
	}, nil
}

func findStatusesForDevice(ctx context.Context, db *DB, usernames []string, projects []string) ([]Status, error) {
	rows, err := db.pool.Query(ctx, `
		SELECT id, service, COALESCE(project_id,''), COALESCE(project_name,''),
		       COALESCE(username,''), COALESCE(workflow,''), red, yellow
		FROM statuses
		WHERE username = ANY($1)
		   OR (username || '/' || project_name) = ANY($2)
	`, usernames, projects)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var statuses []Status
	for rows.Next() {
		var s Status
		if err := rows.Scan(&s.ID, &s.Service, &s.ProjectID, &s.ProjectName,
			&s.Username, &s.Workflow, &s.Red, &s.Yellow); err != nil {
			return nil, err
		}
		statuses = append(statuses, s)
	}
	return statuses, rows.Err()
}

// FindDevicesForStatus finds devices watching a given status
func FindDevicesForStatus(ctx context.Context, db *DB, username, projectName string) ([]Device, error) {
	name := username + "/" + projectName
	rows, err := db.pool.Query(ctx, `
		SELECT id, name, usernames, projects, COALESCE(identifier,''),
		       COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,''),
		       status_changed_at, created_at, updated_at
		FROM devices
		WHERE usernames @> ARRAY[$1]::varchar[]
		   OR projects @> ARRAY[$2]::varchar[]
	`, username, name)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []Device
	for rows.Next() {
		var d Device
		if err := rows.Scan(&d.ID, &d.Name, &d.Usernames, &d.Projects,
			&d.Identifier, &d.WebhookURL, &d.Slug, &d.Status,
			&d.StatusChangedAt, &d.CreatedAt, &d.UpdatedAt); err != nil {
			return nil, err
		}
		devices = append(devices, d)
	}
	return devices, rows.Err()
}

// UpsertStatus finds or creates a status and saves it
func UpsertStatus(ctx context.Context, db *DB, s *Status) error {
	var id int
	err := db.pool.QueryRow(ctx, `
		SELECT id FROM statuses
		WHERE service = $1
		  AND COALESCE(username,'') = COALESCE($2,'')
		  AND COALESCE(project_name,'') = COALESCE($3,'')
		  AND COALESCE(project_id,'') = COALESCE($4,'')
		  AND COALESCE(workflow,'') = COALESCE($5,'')
	`, s.Service, s.Username, s.ProjectName, s.ProjectID, s.Workflow).Scan(&id)

	if err != nil {
		// Not found, insert
		err = db.pool.QueryRow(ctx, `
			INSERT INTO statuses (service, username, project_name, project_id, workflow, red, yellow, payload, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
			RETURNING id
		`, s.Service, s.Username, s.ProjectName, s.ProjectID, s.Workflow, s.Red, s.Yellow, s.Payload).Scan(&s.ID)
	} else {
		s.ID = id
		_, err = db.pool.Exec(ctx, `
			UPDATE statuses SET red = $1, yellow = $2, payload = $3, username = $4,
			       project_name = $5, updated_at = NOW()
			WHERE id = $6
		`, s.Red, s.Yellow, s.Payload, s.Username, s.ProjectName, id)
	}
	return err
}

// GetRedStatuses returns failing statuses for a device
func GetRedStatuses(ctx context.Context, db *DB, d *Device) ([]Status, error) {
	rows, err := db.pool.Query(ctx, `
		SELECT id, service, COALESCE(project_id,''), COALESCE(project_name,''),
		       COALESCE(username,''), COALESCE(workflow,''), red, yellow
		FROM statuses
		WHERE red = true
		  AND (username = ANY($1) OR (username || '/' || project_name) = ANY($2))
	`, d.Usernames, d.Projects)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var statuses []Status
	for rows.Next() {
		var s Status
		if err := rows.Scan(&s.ID, &s.Service, &s.ProjectID, &s.ProjectName,
			&s.Username, &s.Workflow, &s.Red, &s.Yellow); err != nil {
			return nil, err
		}
		statuses = append(statuses, s)
	}
	return statuses, rows.Err()
}

// Device represents a physical or virtual build light device
type Device struct {
	ID              string
	Name            string
	Usernames       []string
	Projects        []string
	Identifier      string
	WebhookURL      string
	Slug            string
	Status          string
	StatusChangedAt *time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// FindDeviceBySlugOrID finds a device by slug or UUID
func FindDeviceBySlugOrID(ctx context.Context, db *DB, id string) (*Device, error) {
	var d Device
	err := db.pool.QueryRow(ctx, `
		SELECT id, name, usernames, projects, COALESCE(identifier,''),
		       COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,''),
		       status_changed_at, created_at, updated_at
		FROM devices
		WHERE slug = $1 OR id::text = $1
		LIMIT 1
	`, id).Scan(&d.ID, &d.Name, &d.Usernames, &d.Projects,
		&d.Identifier, &d.WebhookURL, &d.Slug, &d.Status,
		&d.StatusChangedAt, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// FindDeviceByID finds a device by UUID
func FindDeviceByID(ctx context.Context, db *DB, id string) (*Device, error) {
	var d Device
	err := db.pool.QueryRow(ctx, `
		SELECT id, name, usernames, projects, COALESCE(identifier,''),
		       COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,''),
		       status_changed_at, created_at, updated_at
		FROM devices
		WHERE id = $1
	`, id).Scan(&d.ID, &d.Name, &d.Usernames, &d.Projects,
		&d.Identifier, &d.WebhookURL, &d.Slug, &d.Status,
		&d.StatusChangedAt, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// FindDeviceByIdentifier finds a device by its Particle identifier
func FindDeviceByIdentifier(ctx context.Context, db *DB, identifier string) (*Device, error) {
	var d Device
	err := db.pool.QueryRow(ctx, `
		SELECT id, name, usernames, projects, COALESCE(identifier,''),
		       COALESCE(webhook_url,''), COALESCE(slug,''), COALESCE(status,''),
		       status_changed_at, created_at, updated_at
		FROM devices
		WHERE identifier = $1
	`, identifier).Scan(&d.ID, &d.Name, &d.Usernames, &d.Projects,
		&d.Identifier, &d.WebhookURL, &d.Slug, &d.Status,
		&d.StatusChangedAt, &d.CreatedAt, &d.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// UpdateDeviceStatus recalculates and persists device status, broadcasts, and triggers
func UpdateDeviceStatus(ctx context.Context, db *DB, hub *Hub, d *Device) error {
	newStatus, err := CurrentStatus(ctx, db, d.Usernames, d.Projects)
	if err != nil {
		return err
	}

	oldStatus := d.Status
	d.Status = newStatus

	// Broadcast to WebSocket clients
	if d.Slug != "" {
		colors, err := GetDeviceColors(ctx, db, d)
		if err == nil {
			hub.Broadcast("device:"+d.Slug, map[string]interface{}{
				"colors": colors,
			})
		}
	}

	if oldStatus != newStatus {
		now := time.Now()
		d.StatusChangedAt = &now
		_, err = db.pool.Exec(ctx,
			"UPDATE devices SET status = $1, status_changed_at = $2, updated_at = NOW() WHERE id = $3",
			d.Status, d.StatusChangedAt, d.ID)
		if err != nil {
			return err
		}

		// Trigger external notifications
		TriggerDevice(ctx, db, d)
	}

	return nil
}

// UpdateDevicesForStatus broadcasts and updates all devices watching a status
func UpdateDevicesForStatus(ctx context.Context, db *DB, hub *Hub, username, projectName string) {
	// Broadcast to global and per-username colors channels
	allColors, err := GetColors(ctx, db, nil)
	if err == nil {
		hub.Broadcast("colors:*", map[string]interface{}{"colors": allColors})
	}
	userColors, err := GetColors(ctx, db, []string{username})
	if err == nil {
		hub.Broadcast("colors:"+username, map[string]interface{}{"colors": userColors})
	}

	// Update watching devices
	devices, err := FindDevicesForStatus(ctx, db, username, projectName)
	if err != nil {
		return
	}
	for i := range devices {
		UpdateDeviceStatus(ctx, db, hub, &devices[i])
	}
}

// TriggerDevice sends webhook and particle notifications
func TriggerDevice(ctx context.Context, db *DB, d *Device) {
	if d.WebhookURL != "" {
		colors, err := GetDeviceColors(ctx, db, d)
		if err == nil {
			go TriggerWebhook(d, colors)
		}
	}
	if d.Identifier != "" {
		go TriggerParticle(d)
	}
}

func boolPtr(b bool) *bool {
	return &b
}

func strPtr(s string) *string {
	return &s
}
