package asset

import "core:os"
import "core:path/filepath"

// Returns an allocated full path. The caller owns the result and must delete it.
path :: proc(relative_path: string) -> string {
	buffer: [4096]u8
	base_path := os.get_env_buf(buffer[:], "RES_ROOT")
	if base_path == "" {
		base_path = "./res"
	}
	joined, _ := filepath.join({base_path, relative_path})
	return joined
}
