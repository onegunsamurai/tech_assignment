// Command pet-operator runs the Cat and Dog reconcilers.
//
// Configuration via flags / env:
//
//	--metrics-bind-address     :8080
//	--health-probe-bind-address :8081
//	--leader-elect             true
//	--reconcile-interval       30s
package main

import (
	"flag"
	"os"
	"time"

	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"
	"github.com/example/tech_assignment/operator/internal/controller"
)

var (
	scheme = runtime.NewScheme()
	log    = ctrl.Log.WithName("setup")
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))
	utilruntime.Must(v1alpha1.AddToScheme(scheme))
}

func main() {
	var (
		metricsAddr      string
		probeAddr        string
		enableLeader     bool
		reconcileEvery   time.Duration
	)
	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "Metrics endpoint")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "Health probe endpoint")
	flag.BoolVar(&enableLeader, "leader-elect", false, "Enable leader election (recommended for HA)")
	flag.DurationVar(&reconcileEvery, "reconcile-interval", 30*time.Second, "How often state advances")
	zapOpts := zap.Options{Development: false}
	zapOpts.BindFlags(flag.CommandLine)
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseFlagOptions(&zapOpts)))

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		Metrics:                metricsserver.Options{BindAddress: metricsAddr},
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeader,
		LeaderElectionID:       "pet-operator.pets.example.com",
	})
	if err != nil {
		log.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err := (&controller.CatReconciler{
		Client:   mgr.GetClient(),
		Scheme:   mgr.GetScheme(),
		Interval: reconcileEvery,
	}).SetupWithManager(mgr); err != nil {
		log.Error(err, "unable to create cat controller")
		os.Exit(1)
	}
	if err := (&controller.DogReconciler{
		Client:   mgr.GetClient(),
		Scheme:   mgr.GetScheme(),
		Interval: reconcileEvery,
	}).SetupWithManager(mgr); err != nil {
		log.Error(err, "unable to create dog controller")
		os.Exit(1)
	}

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		log.Error(err, "unable to set up health check")
		os.Exit(1)
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		log.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	log.Info("starting pet-operator", "interval", reconcileEvery)
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		log.Error(err, "manager stopped with error")
		os.Exit(1)
	}
}
