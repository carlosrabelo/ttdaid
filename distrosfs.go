// Package distrosfs embeds the distros/ component tree for standalone binaries.
package distrosfs

import "embed"

// FS is the embedded distros/ directory (distros/<distro>/<release>/…).
//
//go:embed all:distros
var FS embed.FS
