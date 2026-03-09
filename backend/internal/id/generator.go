package id

import (
	"github.com/google/uuid"
)

type Generator struct{}

func NewGenerator() *Generator {
	return &Generator{}
}

func (g *Generator) New() string {
	return uuid.Must(uuid.NewV7()).String()
}
