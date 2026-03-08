package app

import (
	"testing"
)

func TestGetColors(t *testing.T) {
	db, ctx := setupTestDB(t)

	t.Run("returns green when no statuses", func(t *testing.T) {
		truncate(t, db, ctx)
		colors, err := GetColors(ctx, db, nil)
		if err != nil {
			t.Fatalf("GetColors error: %v", err)
		}
		if colors.Red != 0 {
			t.Errorf("expected red=0, got %d", colors.Red)
		}
		if colors.Yellow != false {
			t.Errorf("expected yellow=false, got %v", colors.Yellow)
		}
		if colors.Green != true {
			t.Errorf("expected green=true, got %v", colors.Green)
		}
	})

	t.Run("counts red statuses", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "bob"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(false), Username: "carol"})

		colors, err := GetColors(ctx, db, nil)
		if err != nil {
			t.Fatalf("GetColors error: %v", err)
		}
		if colors.Red != 2 {
			t.Errorf("expected red=2, got %d", colors.Red)
		}
		if colors.Green != false {
			t.Errorf("expected green=false, got %v", colors.Green)
		}
	})

	t.Run("detects yellow", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Yellow: boolPtr(true)})

		colors, err := GetColors(ctx, db, nil)
		if err != nil {
			t.Fatalf("GetColors error: %v", err)
		}
		if colors.Yellow != true {
			t.Errorf("expected yellow=true, got %v", colors.Yellow)
		}
	})

	t.Run("filters by username", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "bob"})

		colors, err := GetColors(ctx, db, []string{"alice"})
		if err != nil {
			t.Fatalf("GetColors error: %v", err)
		}
		if colors.Red != 1 {
			t.Errorf("expected red=1, got %d", colors.Red)
		}
	})

	t.Run("returns green when filtered user has no red", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(false), Username: "bob"})

		colors, err := GetColors(ctx, db, []string{"bob"})
		if err != nil {
			t.Fatalf("GetColors error: %v", err)
		}
		if colors.Red != 0 {
			t.Errorf("expected red=0, got %d", colors.Red)
		}
		if colors.Green != true {
			t.Errorf("expected green=true, got %v", colors.Green)
		}
	})
}

func TestColorsAsBooleans(t *testing.T) {
	t.Run("converts red count to boolean", func(t *testing.T) {
		c := Colors{Red: 3, Yellow: true, Green: false}
		b := c.AsBooleans()
		if b.Red != true {
			t.Errorf("expected red=true, got %v", b.Red)
		}
		if b.Yellow != true {
			t.Errorf("expected yellow=true, got %v", b.Yellow)
		}
		if b.Green != false {
			t.Errorf("expected green=false, got %v", b.Green)
		}
	})

	t.Run("zero red converts to false", func(t *testing.T) {
		c := Colors{Red: 0, Yellow: false, Green: true}
		b := c.AsBooleans()
		if b.Red != false {
			t.Errorf("expected red=false, got %v", b.Red)
		}
		if b.Green != true {
			t.Errorf("expected green=true, got %v", b.Green)
		}
	})
}

func TestColorsRYG(t *testing.T) {
	tests := []struct {
		name   string
		colors Colors
		want   string
	}{
		{"all off", Colors{Red: 0, Yellow: false, Green: false}, "ryg"},
		{"all on", Colors{Red: 1, Yellow: true, Green: true}, "RYG"},
		{"red only", Colors{Red: 2, Yellow: false, Green: false}, "Ryg"},
		{"green only", Colors{Red: 0, Yellow: false, Green: true}, "ryG"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.colors.RYG()
			if got != tt.want {
				t.Errorf("expected %q, got %q", tt.want, got)
			}
		})
	}
}

func TestStatusName(t *testing.T) {
	s := &Status{Username: "collectiveidea", ProjectName: "buildlight"}
	if got := s.Name(); got != "collectiveidea/buildlight" {
		t.Errorf("expected collectiveidea/buildlight, got %s", got)
	}
}

func TestFindDevicesForStatus(t *testing.T) {
	db, ctx := setupTestDB(t)

	t.Run("finds devices watching by username", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{Usernames: []string{"alice"}})
		createDevice(t, db, ctx, deviceOpts{Usernames: []string{"bob"}})

		devices, err := FindDevicesForStatus(ctx, db, "alice", "repo")
		if err != nil {
			t.Fatalf("FindDevicesForStatus error: %v", err)
		}
		if len(devices) != 1 {
			t.Errorf("expected 1 device, got %d", len(devices))
		}
	})

	t.Run("finds devices watching by project", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{Projects: []string{"alice/repo"}})
		createDevice(t, db, ctx, deviceOpts{Projects: []string{"bob/other"}})

		devices, err := FindDevicesForStatus(ctx, db, "alice", "repo")
		if err != nil {
			t.Fatalf("FindDevicesForStatus error: %v", err)
		}
		if len(devices) != 1 {
			t.Errorf("expected 1 device, got %d", len(devices))
		}
	})

	t.Run("finds devices watching by username or project", func(t *testing.T) {
		truncate(t, db, ctx)
		createDevice(t, db, ctx, deviceOpts{Usernames: []string{"alice"}})
		createDevice(t, db, ctx, deviceOpts{Projects: []string{"alice/repo"}})
		createDevice(t, db, ctx, deviceOpts{Usernames: []string{"bob"}})

		devices, err := FindDevicesForStatus(ctx, db, "alice", "repo")
		if err != nil {
			t.Fatalf("FindDevicesForStatus error: %v", err)
		}
		if len(devices) != 2 {
			t.Errorf("expected 2 devices, got %d", len(devices))
		}
	})
}

func TestGetDeviceColors(t *testing.T) {
	db, ctx := setupTestDB(t)

	t.Run("returns colors for device statuses by username", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(false), Username: "bob"})

		d := createDevice(t, db, ctx, deviceOpts{Usernames: []string{"alice"}})
		colors, err := GetDeviceColors(ctx, db, d)
		if err != nil {
			t.Fatalf("GetDeviceColors error: %v", err)
		}
		if colors.Red != 1 {
			t.Errorf("expected red=1, got %d", colors.Red)
		}
	})

	t.Run("returns colors for device statuses by project", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice", ProjectName: "repo1"})
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice", ProjectName: "repo2"})

		d := createDevice(t, db, ctx, deviceOpts{Projects: []string{"alice/repo1"}})
		colors, err := GetDeviceColors(ctx, db, d)
		if err != nil {
			t.Fatalf("GetDeviceColors error: %v", err)
		}
		if colors.Red != 1 {
			t.Errorf("expected red=1, got %d", colors.Red)
		}
	})
}

func TestCurrentStatus(t *testing.T) {
	db, ctx := setupTestDB(t)

	t.Run("returns passing when no failures", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(false), Username: "alice"})

		status, err := CurrentStatus(ctx, db, []string{"alice"}, nil)
		if err != nil {
			t.Fatalf("CurrentStatus error: %v", err)
		}
		if status != "passing" {
			t.Errorf("expected passing, got %s", status)
		}
	})

	t.Run("returns failing when red", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Username: "alice"})

		status, err := CurrentStatus(ctx, db, []string{"alice"}, nil)
		if err != nil {
			t.Fatalf("CurrentStatus error: %v", err)
		}
		if status != "failing" {
			t.Errorf("expected failing, got %s", status)
		}
	})

	t.Run("returns failing-building when red and yellow", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(true), Yellow: boolPtr(true), Username: "alice"})

		status, err := CurrentStatus(ctx, db, []string{"alice"}, nil)
		if err != nil {
			t.Fatalf("CurrentStatus error: %v", err)
		}
		if status != "failing-building" {
			t.Errorf("expected failing-building, got %s", status)
		}
	})

	t.Run("returns passing-building when yellow only", func(t *testing.T) {
		truncate(t, db, ctx)
		createStatus(t, db, ctx, statusOpts{Red: boolPtr(false), Yellow: boolPtr(true), Username: "alice"})

		status, err := CurrentStatus(ctx, db, []string{"alice"}, nil)
		if err != nil {
			t.Fatalf("CurrentStatus error: %v", err)
		}
		if status != "passing-building" {
			t.Errorf("expected passing-building, got %s", status)
		}
	})
}

func TestUpsertStatus(t *testing.T) {
	db, ctx := setupTestDB(t)

	t.Run("inserts new status", func(t *testing.T) {
		truncate(t, db, ctx)
		s := &Status{
			Service:     "github",
			Username:    "alice",
			ProjectName: "repo",
			Red:         boolPtr(false),
			Yellow:      boolPtr(false),
		}
		if err := UpsertStatus(ctx, db, s); err != nil {
			t.Fatalf("UpsertStatus error: %v", err)
		}
		if s.ID == 0 {
			t.Error("expected status ID to be set")
		}
		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status, got %d", count)
		}
	})

	t.Run("updates existing status", func(t *testing.T) {
		truncate(t, db, ctx)
		s := &Status{
			Service:     "github",
			Username:    "alice",
			ProjectName: "repo",
			Red:         boolPtr(true),
			Yellow:      boolPtr(false),
		}
		UpsertStatus(ctx, db, s)

		s2 := &Status{
			Service:     "github",
			Username:    "alice",
			ProjectName: "repo",
			Red:         boolPtr(false),
			Yellow:      boolPtr(false),
		}
		if err := UpsertStatus(ctx, db, s2); err != nil {
			t.Fatalf("UpsertStatus error: %v", err)
		}

		if count := statusCount(t, db, ctx); count != 1 {
			t.Errorf("expected 1 status after upsert, got %d", count)
		}

		loaded := loadStatus(t, db, ctx, s2.ID)
		if *loaded.Red != false {
			t.Errorf("expected red=false after upsert, got %v", *loaded.Red)
		}
	})
}
