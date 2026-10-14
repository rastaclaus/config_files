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
	settings = {
		ty = {
			diagnosticMode = "workspace",
			experimental = {
				rename = true,
				autoImport = true,
			},
		},
	},
}
