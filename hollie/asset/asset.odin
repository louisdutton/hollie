package asset

import "core:os"
import "core:path/filepath"

@(private)
base_path := os.get_env("RES_ROOT")

// Returns the full path to an asset file
path :: proc(relative_path: string) -> string {
	return filepath.join({base_path, relative_path})
}
