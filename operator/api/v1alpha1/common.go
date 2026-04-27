package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// Gender is restricted to the two values defined by the OpenAPI spec.
// +kubebuilder:validation:Enum=male;female
type Gender string

const (
	GenderMale   Gender = "male"
	GenderFemale Gender = "female"
)

// PetIdentity is the immutable portion of a pet's spec. Embedded in both
// CatSpec and DogSpec to keep the contract single-sourced.
type PetIdentity struct {
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	Color string `json:"color"`

	// +kubebuilder:validation:Required
	Gender Gender `json:"gender"`

	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	Breed string `json:"breed"`
}

// StatusMeta is the bookkeeping shared by Cat and Dog statuses.
type StatusMeta struct {
	// LastTransitionTime is when the operator last patched state.
	// +optional
	LastTransitionTime *metav1.Time `json:"lastTransitionTime,omitempty"`

	// ObservedGeneration is the .metadata.generation the operator last reconciled.
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
}
