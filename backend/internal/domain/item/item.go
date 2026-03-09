package item

import "time"

type Unit string

const (
	UnitGrams Unit = "grams"
	UnitML    Unit = "ml"
	UnitL     Unit = "l"
)

type Packaging string

const (
	PackagingCan   Packaging = "can"
	PackagingBox   Packaging = "box"
	PackagingBag   Packaging = "bag"
	PackagingJar   Packaging = "jar"
	PackagingOther Packaging = "other"
)

type Item struct {
	ID            string
	Name          string
	BestBefore    time.Time
	ContentAmount float64
	ContentUnit   Unit
	Packaging     Packaging
	PictureKey    string
	Comment       *string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}
