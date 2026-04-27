package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// DogState is the dynamic state of a dog. Mirrors the OpenAPI spec.
type DogState struct {
	IsBarking  bool `json:"isBarking"`
	IsHungry   bool `json:"isHungry"`
	IsSleeping bool `json:"isSleeping"`
}

type DogSpec struct {
	PetIdentity `json:",inline"`

	// +optional
	InitialState *DogState `json:"initialState,omitempty"`
}

type DogStatus struct {
	StatusMeta `json:",inline"`
	// +optional
	State *DogState `json:"state,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:resource:scope=Namespaced,shortName=dog
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Color",type=string,JSONPath=`.spec.color`
// +kubebuilder:printcolumn:name="Breed",type=string,JSONPath=`.spec.breed`
// +kubebuilder:printcolumn:name="Gender",type=string,JSONPath=`.spec.gender`
// +kubebuilder:printcolumn:name="Barking",type=boolean,JSONPath=`.status.state.isBarking`
// +kubebuilder:printcolumn:name="Hungry",type=boolean,JSONPath=`.status.state.isHungry`
// +kubebuilder:printcolumn:name="Sleeping",type=boolean,JSONPath=`.status.state.isSleeping`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type Dog struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DogSpec   `json:"spec,omitempty"`
	Status DogStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true
type DogList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Dog `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Dog{}, &DogList{})
}

func (in *Dog) DeepCopy() *Dog {
	if in == nil {
		return nil
	}
	out := &Dog{}
	in.DeepCopyInto(out)
	return out
}

func (in *Dog) DeepCopyObject() runtime.Object { return in.DeepCopy() }

func (in *Dog) DeepCopyInto(out *Dog) {
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

func (in *DogList) DeepCopy() *DogList {
	if in == nil {
		return nil
	}
	out := &DogList{}
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	out.Items = make([]Dog, len(in.Items))
	for i := range in.Items {
		in.Items[i].DeepCopyInto(&out.Items[i])
	}
	return out
}

func (in *DogList) DeepCopyObject() runtime.Object { return in.DeepCopy() }
