package router

import (
	"encoding/json"
	"net/http"
)

func Hack(w http.ResponseWriter, r *http.Request) {
	status := struct {
		Status string
	}{
		Status: "HACK",
	}

	json.NewEncoder(w).Encode(status)
}
