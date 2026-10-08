{pkgs, ...}: {
  # CLI for the work Odoo's project kanban boards (pkgs/odoo-kanban). Reads its
  # API key from kwallet (env_vars/ODOO_SPIRI_INTERNAL_API). Key rotation is
  # manual: `odoo-kanban rotate-key`, or a new key from Odoo's preferences.
  environment.systemPackages = [pkgs.odoo-kanban];

  # Teach Claude Code about the CLI.
  home-manager.users.traverseda.home.file = {
    ".claude/skills/odoo-kanban/SKILL.md".source = ../pkgs/odoo-kanban/SKILL.md;
    ".claude/skills/odoo-timesheet/SKILL.md".source = ../pkgs/odoo-kanban/timesheet-skill.md;
  };
}
