//go:build !production

package app

import (
	"html/template"
	"log"

	"buildlight"
)

func ReloadTemplates() {
	t, err := template.New("").Funcs(TemplateFuncs).ParseFS(buildlight.TemplateDir(), "templates/*.html")
	if err != nil {
		log.Printf("Template reload error: %v", err)
		return
	}
	Templates = t
}
