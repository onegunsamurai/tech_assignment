// Package state holds the deterministic-given-RNG transition function used
// by the operator to advance a pet's dynamic state on each reconcile.
//
// The transitions are intentionally simple and biased toward stable states
// (e.g., a sleeping animal usually stays asleep) so that observers see a
// believable progression rather than uniform white noise.
package state

import (
	"math/rand"

	v1alpha1 "github.com/example/tech_assignment/operator/api/v1alpha1"
)

// Rand is the minimum randomness surface we need. *rand.Rand satisfies it.
// Tests inject a seeded source for determinism.
type Rand interface {
	Float64() float64
}

// NewSeeded returns a Rand backed by math/rand with the given seed.
func NewSeeded(seed int64) Rand {
	return rand.New(rand.NewSource(seed))
}

// flip returns true with probability p.
func flip(r Rand, p float64) bool { return r.Float64() < p }

// transition applies a Markov-like step to a single boolean. stayProb is the
// probability of keeping the current value; otherwise it flips.
func transition(r Rand, current bool, stayProb float64) bool {
	if flip(r, stayProb) {
		return current
	}
	return !current
}

// NextDog advances a dog's state. Sleep is the dominant attractor: a sleeping
// dog rarely wakes; a hungry dog stays hungry until the (simulated) feed.
// Barking is bursty (low stay-probability when on, high when off).
func NextDog(r Rand, cur v1alpha1.DogState) v1alpha1.DogState {
	next := v1alpha1.DogState{
		IsSleeping: transition(r, cur.IsSleeping, ifElse(cur.IsSleeping, 0.85, 0.30)),
		IsHungry:   transition(r, cur.IsHungry, ifElse(cur.IsHungry, 0.80, 0.40)),
		IsBarking:  transition(r, cur.IsBarking, ifElse(cur.IsBarking, 0.40, 0.85)),
	}
	// Sleeping dogs cannot bark; enforce that constraint after the
	// transition so behavior reads as physical, not random.
	if next.IsSleeping {
		next.IsBarking = false
	}
	return next
}

// NextCat advances a cat's state. Hiding is the dominant attractor (a hiding
// cat tends to keep hiding). Purring and meowing flip more freely.
func NextCat(r Rand, cur v1alpha1.CatState) v1alpha1.CatState {
	next := v1alpha1.CatState{
		IsHiding:  transition(r, cur.IsHiding, ifElse(cur.IsHiding, 0.85, 0.40)),
		IsPurring: transition(r, cur.IsPurring, ifElse(cur.IsPurring, 0.55, 0.65)),
		IsMeowing: transition(r, cur.IsMeowing, ifElse(cur.IsMeowing, 0.40, 0.80)),
	}
	// A hiding cat does not meow.
	if next.IsHiding {
		next.IsMeowing = false
	}
	return next
}

func ifElse[T any](cond bool, a, b T) T {
	if cond {
		return a
	}
	return b
}
