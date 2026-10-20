return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml", "rust-project.json", ".git" },
	settings = {
		["rust-analyzer"] = {
			imports = {
				granularity = {
					group = "module",
				},
				prefix = "self",
			},
			check = {
				command = "clippy",
			},
			inlayHints = {
				lifetimeElisionHints = { enable = "always" },
			},
			cargo = {
				features = "all",
			},
		},
	},
}
