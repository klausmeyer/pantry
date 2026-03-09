package item

import "time"

type Unit string

const (
	UnitGrams Unit = "grams"
	UnitML    Unit = "ml"
	UnitL     Unit = "l"
)

type Item struct {
	ID            string
	Name          string
	BestBefore    time.Time
	ContentAmount float64
	ContentUnit   Unit
	PictureKey    string
	Comment       *string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}
