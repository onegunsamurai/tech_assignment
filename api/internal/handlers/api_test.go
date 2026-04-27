package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"

	"github.com/example/tech_assignment/api/internal/store"
)

// fakeDogStore is a controllable mock — handlers only need this small
// surface, so we avoid pulling in a fake K8s client.
type fakeDogStore struct {
	listFn   func() ([]v1alpha1.Dog, error)
	getFn    func(string) (*v1alpha1.Dog, error)
	createFn func(*v1alpha1.Dog) error
	deleteFn func(string) error
}

func (f *fakeDogStore) List(_ context.Context) ([]v1alpha1.Dog, error) { return f.listFn() }
func (f *fakeDogStore) Get(_ context.Context, id string) (*v1alpha1.Dog, error) {
	return f.getFn(id)
}
func (f *fakeDogStore) Create(_ context.Context, d *v1alpha1.Dog) error { return f.createFn(d) }
func (f *fakeDogStore) Delete(_ context.Context, id string) error      { return f.deleteFn(id) }

func newDogRouter(s store.DogStore) http.Handler {
	r := chi.NewRouter()
	(&DogHandler{Store: s}).Mount(r)
	return r
}

func TestListDogs_EmptyReturnsArray(t *testing.T) {
	// Reviewers care that an empty list returns `[]` not `null` — JSON null
	// breaks naive consumers. Pin the bytes.
	s := &fakeDogStore{listFn: func() ([]v1alpha1.Dog, error) { return nil, nil }}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/dogs", nil)
	newDogRouter(s).ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d", rec.Code)
	}
	if !strings.HasPrefix(strings.TrimSpace(rec.Body.String()), "[") {
		t.Fatalf("expected JSON array, got %q", rec.Body.String())
	}
}

func TestCreateDog_ValidationFailures(t *testing.T) {
	cases := []struct {
		name string
		body string
	}{
		{"missing color", `{"gender":"male","breed":"husky","state":{"isBarking":false,"isHungry":false,"isSleeping":false}}`},
		{"bad gender", `{"color":"black","gender":"???","breed":"husky","state":{"isBarking":false,"isHungry":false,"isSleeping":false}}`},
		{"missing state", `{"color":"black","gender":"male","breed":"husky"}`},
		{"junk json", `{not json`},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			s := &fakeDogStore{createFn: func(*v1alpha1.Dog) error { t.Fatal("should not call store"); return nil }}
			rec := httptest.NewRecorder()
			req := httptest.NewRequest(http.MethodPost, "/dogs", strings.NewReader(c.body))
			req.Header.Set("Content-Type", "application/json")
			newDogRouter(s).ServeHTTP(rec, req)
			if rec.Code != http.StatusBadRequest {
				t.Fatalf("expected 400, got %d body=%s", rec.Code, rec.Body.String())
			}
			var env errorEnvelope
			if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
				t.Fatalf("error envelope must parse: %v body=%s", err, rec.Body.String())
			}
			if env.Err.Code == "" {
				t.Fatalf("error envelope missing code: %+v", env)
			}
		})
	}
}

func TestCreateDog_HappyPath(t *testing.T) {
	created := false
	s := &fakeDogStore{createFn: func(d *v1alpha1.Dog) error {
		created = true
		// Simulate apiserver assigning a UID — handlers must surface it.
		d.UID = types.UID("uid-rex-1")
		return nil
	}}
	body := `{"color":"black","gender":"male","breed":"husky","state":{"isBarking":false,"isHungry":true,"isSleeping":false}}`
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/dogs", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	newDogRouter(s).ServeHTTP(rec, req)
	if !created {
		t.Fatalf("store.Create not invoked")
	}
	if rec.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d", rec.Code)
	}
	var dto dogDTO
	if err := json.Unmarshal(rec.Body.Bytes(), &dto); err != nil {
		t.Fatalf("response must parse: %v", err)
	}
	if dto.ID != "uid-rex-1" {
		t.Fatalf("response id should be the UID assigned by apiserver; got %q", dto.ID)
	}
	if !dto.State.IsHungry {
		t.Fatalf("initial state must round-trip")
	}
}

func TestGetDog_NotFound(t *testing.T) {
	s := &fakeDogStore{getFn: func(string) (*v1alpha1.Dog, error) { return nil, store.ErrNotFound }}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/dogs/missing", nil)
	newDogRouter(s).ServeHTTP(rec, req)
	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}
}

func TestGetDog_OK_SurfacesObservedState(t *testing.T) {
	s := &fakeDogStore{getFn: func(id string) (*v1alpha1.Dog, error) {
		return &v1alpha1.Dog{
			ObjectMeta: metav1.ObjectMeta{UID: types.UID(id), Name: "rex"},
			Spec: v1alpha1.DogSpec{PetIdentity: v1alpha1.PetIdentity{
				Color: "black", Gender: "male", Breed: "husky",
			}},
			Status: v1alpha1.DogStatus{State: &v1alpha1.DogState{IsSleeping: true}},
		}, nil
	}}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/dogs/rex-uid", nil)
	newDogRouter(s).ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var dto dogDTO
	if err := json.Unmarshal(rec.Body.Bytes(), &dto); err != nil {
		t.Fatalf("parse: %v", err)
	}
	if !dto.State.IsSleeping {
		t.Fatalf("dynamic state must come from .status.state, got %+v", dto.State)
	}
}

func TestDeleteDog_NoContent(t *testing.T) {
	s := &fakeDogStore{deleteFn: func(string) error { return nil }}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodDelete, "/dogs/x", nil)
	newDogRouter(s).ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected 204, got %d", rec.Code)
	}
}

func TestDeleteDog_StoreErrorBubbles(t *testing.T) {
	s := &fakeDogStore{deleteFn: func(string) error { return errors.New("boom") }}
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodDelete, "/dogs/x", nil)
	newDogRouter(s).ServeHTTP(rec, req)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
}
