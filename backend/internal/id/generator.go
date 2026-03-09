package id

import (
	"fmt"
	"math/rand"
	"time"
)

var adjectives = []string{"amber", "brisk", "calm", "crisp", "green", "quiet", "solid", "vivid"}
var nouns = []string{"apple", "barrel", "bottle", "leaf", "plate", "shelf", "spoon", "tin"}

type Generator struct {
	rnd *rand.Rand
}

func NewGenerator() *Generator {
	return &Generator{
		rnd: rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

func (g *Generator) New() string {
	adjective := adjectives[g.rnd.Intn(len(adjectives))]
	noun := nouns[g.rnd.Intn(len(nouns))]
	number := g.rnd.Intn(900) + 100
	return fmt.Sprintf("%s-%s-%d", adjective, noun, number)
}
