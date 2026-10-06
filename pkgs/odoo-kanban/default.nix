{
  lib,
  writers,
  kdePackages,
}:
# Stdlib-only Python CLI for Odoo project kanban boards via the Odoo 19
# JSON-2 API. The API key lives in kwallet; see odoo_kanban.py for details.
writers.writePython3Bin "odoo-kanban" {
  # E501: long f-strings; W503/W504: either line-break style around operators.
  flakeIgnore = ["E501" "W503" "W504"];
}
(lib.replaceStrings
  ["@kwalletQuery@"]
  ["${kdePackages.kwallet}/bin/kwallet-query"]
  (builtins.readFile ./odoo_kanban.py))
