// Package handlers exposes HTTP endpoints that mirror the OpenAPI spec.
// They are intentionally thin: validation + delegate to the store + render.
package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"

	"github.com/example/tech_assignment/api/internal/store"
)

// errorEnvelope follows the canonical error shape from .claude/rules/api-design.md
type errorEnvelope struct {
	Err errorBody `json:"error"`
}
type errorBody struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	RequestID string `json:"request_id,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeErr(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, errorEnvelope{Err: errorBody{Code: code, Message: msg}})
}

// --- DTOs (the wire shape required by the spec) ---

type dogDTO struct {
	ID     string             `json:"id"`
	Color  string             `json:"color"`
	Gender string             `json:"gender"`
	Breed  string             `json:"breed"`
	State  v1alpha1.DogState  `json:"state"`
}

type catDTO struct {
	ID     string             `json:"id"`
	Color  string             `json:"color"`
	Gender string             `json:"gender"`
	Breed  string             `json:"breed"`
	State  v1alpha1.CatState  `json:"state"`
}

type dogCreate struct {
	Color  string             `json:"color"`
	Gender string             `json:"gender"`
	Breed  string             `json:"breed"`
	State  *v1alpha1.DogState `json:"state"`
}

type catCreate struct {
	Color  string             `json:"color"`
	Gender string             `json:"gender"`
	Breed  string             `json:"breed"`
	State  *v1alpha1.CatState `json:"state"`
}

func dogToDTO(d *v1alpha1.Dog) dogDTO {
	state := v1alpha1.DogState{}
	if d.Status.State != nil {
		state = *d.Status.State
	}
	return dogDTO{
		ID:     string(d.UID),
		Color:  d.Spec.Color,
		Gender: string(d.Spec.Gender),
		Breed:  d.Spec.Breed,
		State:  state,
	}
}

func catToDTO(c *v1alpha1.Cat) catDTO {
	state := v1alpha1.CatState{}
	if c.Status.State != nil {
		state = *c.Status.State
	}
	return catDTO{
		ID:     string(c.UID),
		Color:  c.Spec.Color,
		Gender: string(c.Spec.Gender),
		Breed:  c.Spec.Breed,
		State:  state,
	}
}

func validateGender(g string) bool { return g == "male" || g == "female" }

// DogHandler / CatHandler bind a store. Two structs (rather than one generic
// handler) keep call sites obvious and side-step Go's lack of method-level
// generics.

type DogHandler struct{ Store store.DogStore }

func (h *DogHandler) Mount(r chi.Router) {
	r.Get("/dogs", h.list)
	r.Post("/dogs", h.create)
	r.Get("/dogs/{id}", h.get)
	r.Delete("/dogs/{id}", h.del)
}

func (h *DogHandler) list(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.List(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	out := make([]dogDTO, 0, len(items))
	for i := range items {
		out = append(out, dogToDTO(&items[i]))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *DogHandler) create(w http.ResponseWriter, r *http.Request) {
	var in dogCreate
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid JSON: "+err.Error())
		return
	}
	if in.Color == "" || in.Breed == "" || !validateGender(in.Gender) || in.State == nil {
		writeErr(w, http.StatusBadRequest, "VALIDATION_FAILED",
			"color, breed, gender (male|female), and state are required")
		return
	}
	dog := &v1alpha1.Dog{
		Spec: v1alpha1.DogSpec{
			PetIdentity: v1alpha1.PetIdentity{
				Color:  in.Color,
				Gender: v1alpha1.Gender(in.Gender),
				Breed:  in.Breed,
			},
			InitialState: in.State,
		},
	}
	if err := h.Store.Create(r.Context(), dog); err != nil {
		writeErr(w, http.StatusInternalServerError, "CREATE_FAILED", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, dogToDTO(dog))
}

func (h *DogHandler) get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	dog, err := h.Store.Get(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeErr(w, http.StatusNotFound, "NOT_FOUND", "dog not found")
			return
		}
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, dogToDTO(dog))
}

func (h *DogHandler) del(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Delete(r.Context(), id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeErr(w, http.StatusNotFound, "NOT_FOUND", "dog not found")
			return
		}
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type CatHandler struct{ Store store.CatStore }

func (h *CatHandler) Mount(r chi.Router) {
	r.Get("/cats", h.list)
	r.Post("/cats", h.create)
	r.Get("/cats/{id}", h.get)
	r.Delete("/cats/{id}", h.del)
}

func (h *CatHandler) list(w http.ResponseWriter, r *http.Request) {
	items, err := h.Store.List(r.Context())
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	out := make([]catDTO, 0, len(items))
	for i := range items {
		out = append(out, catToDTO(&items[i]))
	}
	writeJSON(w, http.StatusOK, out)
}

func (h *CatHandler) create(w http.ResponseWriter, r *http.Request) {
	var in catCreate
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeErr(w, http.StatusBadRequest, "VALIDATION_FAILED", "invalid JSON: "+err.Error())
		return
	}
	if in.Color == "" || in.Breed == "" || !validateGender(in.Gender) || in.State == nil {
		writeErr(w, http.StatusBadRequest, "VALIDATION_FAILED",
			"color, breed, gender (male|female), and state are required")
		return
	}
	cat := &v1alpha1.Cat{
		Spec: v1alpha1.CatSpec{
			PetIdentity: v1alpha1.PetIdentity{
				Color:  in.Color,
				Gender: v1alpha1.Gender(in.Gender),
				Breed:  in.Breed,
			},
			InitialState: in.State,
		},
	}
	if err := h.Store.Create(r.Context(), cat); err != nil {
		writeErr(w, http.StatusInternalServerError, "CREATE_FAILED", err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, catToDTO(cat))
}

func (h *CatHandler) get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	cat, err := h.Store.Get(r.Context(), id)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeErr(w, http.StatusNotFound, "NOT_FOUND", "cat not found")
			return
		}
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	writeJSON(w, http.StatusOK, catToDTO(cat))
}

func (h *CatHandler) del(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := h.Store.Delete(r.Context(), id); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeErr(w, http.StatusNotFound, "NOT_FOUND", "cat not found")
			return
		}
		writeErr(w, http.StatusInternalServerError, "INTERNAL", err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
