-- @brief
---
--- https://github.com/astral-sh/ty
---
--- `ty`, a static type checker and language server for python
--- @type vim.lsp.Config
return {
	cmd = { "ty", "server" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"requirements.txt",
		"Pipfile",
		"ruff.toml",
		".git",
	},
	-- `settings.ty` is the payload Neovim serves for ty's
	-- `workspace/configuration` request (section "ty"). Unlike Helix, Neovim does
	-- not reuse it as `initializationOptions`, so the `ty` wrapper is correct here.
	-- `experimental.rename`/`experimental.autoImport` no longer exist (rename is
	-- always on; autoImport moved under `completions`).
	settings = {
		ty = {
			diagnosticMode = "workspace",
			completions = {
				autoImport = true,
			},
		},
	},
}
