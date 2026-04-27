package state

import (
	"testing"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"
)

// fakeRand drives transitions deterministically: it returns each value in
// the queue in order, panicking if the test consumes more than expected.
type fakeRand struct {
	values []float64
	i      int
}

func (f *fakeRand) Float64() float64 {
	if f.i >= len(f.values) {
		panic("fakeRand exhausted")
	}
	v := f.values[f.i]
	f.i++
	return v
}

func TestNextDog_SleepingSuppressesBarking(t *testing.T) {
	// Force every transition to "stay" so flags don't flip; then prove the
	// post-rule clamp still zeroes barking when sleeping is true.
	r := &fakeRand{values: []float64{0.0, 0.0, 0.0}}
	out := NextDog(r, v1alpha1.DogState{IsSleeping: true, IsBarking: true})
	if !out.IsSleeping {
		t.Fatalf("sleeping should remain true; got %+v", out)
	}
	if out.IsBarking {
		t.Fatalf("a sleeping dog must not bark; got %+v", out)
	}
}

func TestNextCat_HidingSuppressesMeowing(t *testing.T) {
	r := &fakeRand{values: []float64{0.0, 0.0, 0.0}}
	out := NextCat(r, v1alpha1.CatState{IsHiding: true, IsMeowing: true})
	if !out.IsHiding {
		t.Fatalf("hiding should remain true")
	}
	if out.IsMeowing {
		t.Fatalf("a hiding cat must not meow; got %+v", out)
	}
}

func TestTransition_StayBranch(t *testing.T) {
	// p=0.5; rand=0.0 → flip(p)=true → stay
	if got := transition(&fakeRand{values: []float64{0.0}}, true, 0.5); got != true {
		t.Fatalf("expected stay=true; got %v", got)
	}
}

func TestTransition_FlipBranch(t *testing.T) {
	// p=0.5; rand=0.99 → flip(p)=false → flip
	if got := transition(&fakeRand{values: []float64{0.99}}, true, 0.5); got != false {
		t.Fatalf("expected flip to false; got %v", got)
	}
}

// TestNextDog_AllPossibleNextStatesReachable runs many seeded iterations and
// verifies every reachable combination is observed at least once. This guards
// against accidentally clamping to a single output.
func TestNextDog_AllPossibleNextStatesReachable(t *testing.T) {
	seen := map[v1alpha1.DogState]bool{}
	r := NewSeeded(42)
	cur := v1alpha1.DogState{}
	for i := 0; i < 5000; i++ {
		cur = NextDog(r, cur)
		seen[cur] = true
	}
	// 8 raw combos minus the impossible (sleeping=true,barking=true) pair = 6
	if len(seen) < 6 {
		t.Fatalf("expected at least 6 distinct dog states; got %d: %v", len(seen), seen)
	}
	for s := range seen {
		if s.IsSleeping && s.IsBarking {
			t.Fatalf("invariant violated: sleeping+barking observed: %+v", s)
		}
	}
}

func TestNextCat_AllPossibleNextStatesReachable(t *testing.T) {
	seen := map[v1alpha1.CatState]bool{}
	r := NewSeeded(7)
	cur := v1alpha1.CatState{}
	for i := 0; i < 5000; i++ {
		cur = NextCat(r, cur)
		seen[cur] = true
	}
	if len(seen) < 6 {
		t.Fatalf("expected at least 6 distinct cat states; got %d", len(seen))
	}
	for s := range seen {
		if s.IsHiding && s.IsMeowing {
			t.Fatalf("invariant violated: hiding+meowing observed: %+v", s)
		}
	}
}
