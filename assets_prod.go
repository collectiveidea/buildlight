//go:build production

package buildlight

import (
	"embed"
	"io/fs"
	"net/http"
)

//go:embed public
var publicFS embed.FS

//go:embed templates
var templateFS embed.FS

func StaticHandler() http.Handler {
	return http.FileServerFS(publicFS)
}

func TemplateDir() fs.FS {
	return templateFS
}

func ReadPublicFile(name string) ([]byte, error) {
	return publicFS.ReadFile("public/" + name)
}
