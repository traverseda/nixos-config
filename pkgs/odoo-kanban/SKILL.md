---
name: odoo-kanban
description: Read and edit the Spiri Odoo project kanban boards (projects, stages/columns, tasks, comments) with the `odoo-kanban` CLI. Use when the user mentions Odoo, work tasks, tickets, the kanban board, or moving/creating/commenting on tasks.
---

# Odoo kanban boards

`odoo-kanban` talks to https://odoo.internal.spiri.ca (Odoo 19, JSON-2 API) as
the user. Auth is automatic: it reads the API key from kwallet. Never ask for or
print the key.

Run `odoo-kanban <cmd> --help` for the full set of flags. Add `--json` (before
the subcommand) when you need to parse the output.

## Reading

```bash
odoo-kanban whoami                         # sanity check auth
odoo-kanban projects                       # boards: "#id name (N open)"
odoo-kanban stages "<project>"             # columns of a board
odoo-kanban board "<project>" [--mine]     # tasks grouped by column
odoo-kanban tasks --mine                   # my open tasks across all projects
odoo-kanban tasks --project P --stage S --search text --assignee NAME --tag T
odoo-kanban show 1234                      # details, description, last 10 messages
```

Projects, stages, users and tags accept an id or a unique case-insensitive
name (substring works if it's unambiguous; otherwise the error lists the
candidates, so pick by id). Closed (done/cancelled) tasks are hidden unless you
pass `--closed`. In task lines, ★ marks priority.

## Writing

These change shared work data that colleagues see. Confirm with the user before
creating tasks, moving them, reassigning people, or posting comments, unless
they've already asked for exactly that.

```bash
odoo-kanban create --project P --name "Title" [--stage S] [--description "text"] \
  [--assign me alice@spiri.ca] [--tag T] [--priority low|medium|high|urgent] \
  [--deadline 2026-10-31] [--parent 1234]
odoo-kanban move 1234 "In Progress"
odoo-kanban update 1234 --state done|in_progress|changes_requested|approved|canceled
odoo-kanban update 1234 --add-assignee me --unassign bob --tag T --untag T2 --deadline ''
odoo-kanban comment 1234 "text"            # internal log note (no email)
odoo-kanban comment 1234 "text" --send     # message that emails followers
```

`--assign` replaces all assignees. Use `--add-assignee` and `--unassign` for
incremental changes. New tasks are unassigned unless you pass `--assign`.

## Errors

- **HTTP 401**: the key expired or was revoked. Tell the user. Don't try to
  fix it yourself.

Never run `odoo-kanban rotate-key`. The user manages key rotation.
