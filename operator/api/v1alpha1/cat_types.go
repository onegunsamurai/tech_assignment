package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// CatState is the dynamic state of a cat. Mirrors the OpenAPI spec.
type CatState struct {
	IsMeowing bool `json:"isMeowing"`
	IsPurring bool `json:"isPurring"`
	IsHiding  bool `json:"isHiding"`
}

// CatSpec carries the immutable identity of a cat. Field-level immutability
// is enforced by CEL rules on the CRD (see charts/pet-crds).
type CatSpec struct {
	PetIdentity `json:",inline"`

	// InitialState seeds the very first .status.state. Optional — if omitted
	// the operator picks a neutral default.
	// +optional
	InitialState *CatState `json:"initialState,omitempty"`
}

// CatStatus carries observed dynamic state.
type CatStatus struct {
	StatusMeta `json:",inline"`
	// +optional
	State *CatState `json:"state,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:resource:scope=Namespaced,shortName=cat
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Color",type=string,JSONPath=`.spec.color`
// +kubebuilder:printcolumn:name="Breed",type=string,JSONPath=`.spec.breed`
// +kubebuilder:printcolumn:name="Gender",type=string,JSONPath=`.spec.gender`
// +kubebuilder:printcolumn:name="Meowing",type=boolean,JSONPath=`.status.state.isMeowing`
// +kubebuilder:printcolumn:name="Purring",type=boolean,JSONPath=`.status.state.isPurring`
// +kubebuilder:printcolumn:name="Hiding",type=boolean,JSONPath=`.status.state.isHiding`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type Cat struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   CatSpec   `json:"spec,omitempty"`
	Status CatStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true
type CatList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Cat `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Cat{}, &CatList{})
}

// DeepCopyObject is required for runtime.Object conformance. With a real
// kubebuilder run the zz_generated_deepcopy.go file would supply this. For
// this assignment we provide a minimal hand-written DeepCopy chain so the
// code compiles without invoking controller-gen.
func (in *Cat) DeepCopy() *Cat {
	if in == nil {
		return nil
	}
	out := &Cat{}
	in.DeepCopyInto(out)
	return out
}

func (in *Cat) DeepCopyObject() runtime.Object { return in.DeepCopy() }

func (in *Cat) DeepCopyInto(out *Cat) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	out.Spec = in.Spec
	if in.Spec.InitialState != nil {
		s := *in.Spec.InitialState
		out.Spec.InitialState = &s
	}
	out.Status = in.Status
	if in.Status.LastTransitionTime != nil {
		t := *in.Status.LastTransitionTime
		out.Status.LastTransitionTime = &t
	}
	if in.Status.State != nil {
		s := *in.Status.State
		out.Status.State = &s
	}
}

func (in *CatList) DeepCopy() *CatList {
	if in == nil {
		return nil
	}
	out := &CatList{}
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	out.Items = make([]Cat, len(in.Items))
	for i := range in.Items {
		in.Items[i].DeepCopyInto(&out.Items[i])
	}
	return out
}

func (in *CatList) DeepCopyObject() runtime.Object { return in.DeepCopy() }
