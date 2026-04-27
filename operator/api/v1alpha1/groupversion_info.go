// Package v1alpha1 contains API Schema definitions for the pets v1alpha1 API
// group. The Cat and Dog kinds carry immutable identity in spec and observed
// dynamic state in status.
// +kubebuilder:object:generate=true
// +groupName=pets.example.com
package v1alpha1

import (
	"k8s.io/apimachinery/pkg/runtime/schema"
	"sigs.k8s.io/controller-runtime/pkg/scheme"
)

var (
	GroupVersion = schema.GroupVersion{Group: "pets.example.com", Version: "v1alpha1"}

	SchemeBuilder = &scheme.Builder{GroupVersion: GroupVersion}

	AddToScheme = SchemeBuilder.AddToScheme
)
