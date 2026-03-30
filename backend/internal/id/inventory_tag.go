package id

const (
	InventoryTagLength = 4
	inventoryTagAlphabet = "123456789ABCDEFGHJKMNPQRSTVWXYZ"
)

// EncodeCrockfordBase32 returns a fixed-length, left-padded Base32 (Crockford) code.
func EncodeCrockfordBase32(value uint64, length int) string {
	if length <= 0 {
		return ""
	}

	buf := make([]byte, length)
	base := uint64(len(inventoryTagAlphabet))
	for i := length - 1; i >= 0; i-- {
		buf[i] = inventoryTagAlphabet[value%base]
		value /= base
	}

	return string(buf)
}
