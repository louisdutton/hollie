package asset

import "core:os"
import "core:path/filepath"

// Returns the full path to an asset file
path :: proc(relative_path: string) -> string {
	buffer: [4096]u8
	base_path := os.get_env_buf(buffer[:], "RES_ROOT")
	if base_path == "" {
		base_path = "./res"
	}
	joined, _ := filepath.join({base_path, relative_path})
	return joined
}
