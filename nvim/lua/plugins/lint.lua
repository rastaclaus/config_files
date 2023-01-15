require("lint").linters.pylint = require("plugins/pylint")

require("lint").linters_by_ft = {
    python = {"pycodestyle", "pylint", "mypy"},
    yaml = {"yamllint"}
}
