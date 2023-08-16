package router

import (
	"context"
	"encoding/json"
	"net/http"
)

func Hack(ctx context.Context, w http.ResponseWriter, r *http.Request) error {
	status := struct {
		Status string
	}{
		Status: "HACK",
	}

	return json.NewEncoder(w).Encode(status)
}
