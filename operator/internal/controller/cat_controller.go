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

// CatReconciler watches Cat CRs and advances their .status.state on a fixed
// cadence so that observers see believable, evolving dynamic state.
type CatReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Rand     state.Rand
	Interval time.Duration
}

// +kubebuilder:rbac:groups=pets.example.com,resources=cats,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=pets.example.com,resources=cats/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=pets.example.com,resources=cats/finalizers,verbs=update

func (r *CatReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	var cat v1alpha1.Cat
	if err := r.Get(ctx, req.NamespacedName, &cat); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	patch := client.MergeFrom(cat.DeepCopy())

	if cat.Status.State == nil {
		seed := v1alpha1.CatState{}
		if cat.Spec.InitialState != nil {
			seed = *cat.Spec.InitialState
		}
		cat.Status.State = &seed
	} else {
		next := state.NextCat(r.Rand, *cat.Status.State)
		cat.Status.State = &next
	}

	now := metav1.NewTime(time.Now())
	cat.Status.LastTransitionTime = &now
	cat.Status.ObservedGeneration = cat.Generation

	if err := r.Status().Patch(ctx, &cat, patch); err != nil {
		logger.Error(err, "patch cat status")
		return ctrl.Result{}, err
	}

	return ctrl.Result{RequeueAfter: r.Interval}, nil
}

func (r *CatReconciler) SetupWithManager(mgr ctrl.Manager) error {
	if r.Interval == 0 {
		r.Interval = 30 * time.Second
	}
	if r.Rand == nil {
		r.Rand = state.NewSeeded(time.Now().UnixNano())
	}
	return ctrl.NewControllerManagedBy(mgr).
		For(&v1alpha1.Cat{}).
		Complete(r)
}
