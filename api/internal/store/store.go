// Package store wraps controller-runtime's typed client so handlers can
// remain thin. Two interfaces — DogStore and CatStore — make handler tests
// trivial to mock without standing up a real apiserver.
package store

import (
	"context"
	"errors"

	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"
)

// ErrNotFound is returned when a pet ID does not match any CR.
var ErrNotFound = errors.New("pet not found")

// CatStore is the surface handlers need.
type CatStore interface {
	List(ctx context.Context) ([]v1alpha1.Cat, error)
	Get(ctx context.Context, id string) (*v1alpha1.Cat, error)
	Create(ctx context.Context, c *v1alpha1.Cat) error
	Delete(ctx context.Context, id string) error
}

type DogStore interface {
	List(ctx context.Context) ([]v1alpha1.Dog, error)
	Get(ctx context.Context, id string) (*v1alpha1.Dog, error)
	Create(ctx context.Context, d *v1alpha1.Dog) error
	Delete(ctx context.Context, id string) error
}

// K8sStore implements both Cat- and DogStore on top of a controller-runtime
// client. State lives in etcd via CRs — no in-process cache, no DB.
type K8sStore struct {
	C         client.Client
	Namespace string
}

func (s *K8sStore) List(ctx context.Context) ([]v1alpha1.Cat, error) {
	var list v1alpha1.CatList
	if err := s.C.List(ctx, &list, client.InNamespace(s.Namespace)); err != nil {
		return nil, err
	}
	return list.Items, nil
}

// findCat scans the list for the matching .metadata.uid. The OpenAPI `id`
// is mapped to UID — a stable, RFC4122 string assigned by the apiserver.
// A field selector index would scale better; for the assignment list+filter
// is fine and avoids registering a custom indexer on the client.
func (s *K8sStore) Get(ctx context.Context, id string) (*v1alpha1.Cat, error) {
	items, err := s.List(ctx)
	if err != nil {
		return nil, err
	}
	for i := range items {
		if string(items[i].UID) == id {
			return &items[i], nil
		}
	}
	return nil, ErrNotFound
}

func (s *K8sStore) Create(ctx context.Context, c *v1alpha1.Cat) error {
	if c.Namespace == "" {
		c.Namespace = s.Namespace
	}
	if c.Name == "" && c.GenerateName == "" {
		c.GenerateName = "cat-"
	}
	return s.C.Create(ctx, c)
}

func (s *K8sStore) Delete(ctx context.Context, id string) error {
	cat, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	if err := s.C.Delete(ctx, cat); err != nil {
		if apierrors.IsNotFound(err) {
			return ErrNotFound
		}
		return err
	}
	return nil
}

// --- Dog mirror ---

type DogK8sStore struct {
	C         client.Client
	Namespace string
}

func (s *DogK8sStore) List(ctx context.Context) ([]v1alpha1.Dog, error) {
	var list v1alpha1.DogList
	if err := s.C.List(ctx, &list, client.InNamespace(s.Namespace)); err != nil {
		return nil, err
	}
	return list.Items, nil
}

func (s *DogK8sStore) Get(ctx context.Context, id string) (*v1alpha1.Dog, error) {
	items, err := s.List(ctx)
	if err != nil {
		return nil, err
	}
	for i := range items {
		if string(items[i].UID) == id {
			return &items[i], nil
		}
	}
	return nil, ErrNotFound
}

func (s *DogK8sStore) Create(ctx context.Context, d *v1alpha1.Dog) error {
	if d.Namespace == "" {
		d.Namespace = s.Namespace
	}
	if d.Name == "" && d.GenerateName == "" {
		d.GenerateName = "dog-"
	}
	return s.C.Create(ctx, d)
}

func (s *DogK8sStore) Delete(ctx context.Context, id string) error {
	dog, err := s.Get(ctx, id)
	if err != nil {
		return err
	}
	if err := s.C.Delete(ctx, dog); err != nil {
		if apierrors.IsNotFound(err) {
			return ErrNotFound
		}
		return err
	}
	return nil
}

// Compile-time guards so a refactor that breaks the interface fails loudly.
var (
	_ CatStore = (*K8sStore)(nil)
	_ DogStore = (*DogK8sStore)(nil)
)
