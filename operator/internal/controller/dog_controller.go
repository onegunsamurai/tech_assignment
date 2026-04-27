package controller

import (
	"context"
	"time"

	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"
	"github.com/example/tech_assignment/operator/internal/state"
)

type DogReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Rand     state.Rand
	Interval time.Duration
}

// +kubebuilder:rbac:groups=pets.example.com,resources=dogs,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=pets.example.com,resources=dogs/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=pets.example.com,resources=dogs/finalizers,verbs=update

func (r *DogReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	var dog v1alpha1.Dog
	if err := r.Get(ctx, req.NamespacedName, &dog); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	patch := client.MergeFrom(dog.DeepCopy())

	if dog.Status.State == nil {
		seed := v1alpha1.DogState{}
		if dog.Spec.InitialState != nil {
			seed = *dog.Spec.InitialState
		}
		dog.Status.State = &seed
	} else {
		next := state.NextDog(r.Rand, *dog.Status.State)
		dog.Status.State = &next
	}

	now := metav1.NewTime(time.Now())
	dog.Status.LastTransitionTime = &now
	dog.Status.ObservedGeneration = dog.Generation

	if err := r.Status().Patch(ctx, &dog, patch); err != nil {
		logger.Error(err, "patch dog status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{RequeueAfter: r.Interval}, nil
}

func (r *DogReconciler) SetupWithManager(mgr ctrl.Manager) error {
	if r.Interval == 0 {
		r.Interval = 30 * time.Second
	}
	if r.Rand == nil {
		r.Rand = state.NewSeeded(time.Now().UnixNano())
	}
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1alpha1.Dog{}).
		Complete(r)
}
