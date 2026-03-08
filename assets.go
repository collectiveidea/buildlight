//go:build !production

package buildlight

import (
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
)

// RootDir is the project root directory, used for resolving asset paths in
// development mode. Tests running from subdirectories should set this.
var RootDir = "."

func StaticHandler() http.Handler {
	return http.StripPrefix("/public/", http.FileServer(http.Dir(filepath.Join(RootDir, "public"))))
}

func TemplateDir() fs.FS {
	return os.DirFS(RootDir)
}

func ReadPublicFile(name string) ([]byte, error) {
	return os.ReadFile(filepath.Join(RootDir, "public", name))
}
