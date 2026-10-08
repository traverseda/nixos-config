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
odoo-kanban tasks --project P --stage S --search text --assignee NAME --tag T --milestone M
odoo-kanban show 1234                      # details, description, last 10 messages
odoo-kanban milestones "<project>" [--reached]
```

Projects, stages, users and tags accept an id or a unique case-insensitive
name (substring works if it's unambiguous; otherwise the error lists the
candidates, so pick by id). Closed (done/cancelled) tasks are hidden unless you
pass `--closed`. In task lines, ★ marks priority, ⚑ the milestone and ⛔ open blockers.

Use real Odoo milestones and sub-tasks for structure. Don't fake them with
"M1:"-style name prefixes or placeholder parent tasks. Milestones belong to a
single project. If `milestones` reports that they're turned off for a project,
tell the user. Turning them on is a project setting in Odoo's UI.

## Writing

These change shared work data that colleagues see. Confirm with the user before
creating tasks, moving them, reassigning people, or posting comments, unless
they've already asked for exactly that.

```bash
odoo-kanban create --project P --name "Title" [--stage S] [--description "text"] \
  [--assign me alice@spiri.ca] [--tag T] [--priority low|medium|high|urgent] \
  [--deadline 2026-10-31] [--milestone M] [--parent 1234] [--hours 4]
odoo-kanban create --parent 1234 --name "Sub-task"   # project taken from the parent
odoo-kanban move 1234 "In Progress"
odoo-kanban update 1234 --state done|in_progress|changes_requested|approved|canceled
odoo-kanban update 1234 --add-assignee me --unassign bob --tag T --untag T2 --deadline ''
odoo-kanban update 1234 --milestone M      # '' clears it
odoo-kanban update 1234 --parent 99        # re-parent; --parent '' makes it top-level
odoo-kanban update 1234 --project P [--stage S]   # move to another board (clears milestone)
odoo-kanban update 1234 --blocked-by 99 --blocks 1300   # dependencies (repeatable)
odoo-kanban update 1234 --unblock 99 --unblocks 1300    # remove them
odoo-kanban update 1234 --hours 2:30      # estimate (allocated hours); show prints estimate vs spent
odoo-kanban project-settings P [--milestones on|off] [--dependencies on|off]   # no flags: show
odoo-kanban create-milestone P "Name" [--deadline 2026-12-01]
odoo-kanban update-milestone 15 [--name N] [--deadline D] [--reached|--unreached]
odoo-kanban comment 1234 "text"            # internal log note (no email)
odoo-kanban comment 1234 "text" --send     # message that emails followers
```

`--assign` replaces all assignees. Use `--add-assignee` and `--unassign` for
incremental changes. New tasks are unassigned unless you pass `--assign`.

`--blocked-by` and `--blocks` also work on `create`. In task lines,
`⛔ #193` means the task is waiting on open task #193. `show` lists "Blocked
by" and "Blocking" with each task's state. `tasks --ready` (and
`board --ready`) shows only open tasks with no open blockers, which answers
"what can be picked up next". Odoo refuses circular dependencies. Dependencies only take effect on
boards that have them turned on in project settings. Otherwise the command
prints a note, and you should pass it on to the user.

### Descriptions and comments

Plain text is converted for you. Blank lines separate paragraphs. Lines
starting with `- `, `* ` or `1. ` become lists. `#123` becomes a link to task
123.

### Creating several tasks at once

To create a set of linked tickets, write a YAML file and run
`odoo-kanban create --from tickets.yaml`. Check it first with `--dry-run`.
Each entry has a local `key`. `parent`, `blocked_by` and `blocks` can refer to
those keys or to existing task ids. Everything is validated before anything is
created. The command prints `key -> #id` for each task.

```yaml
project: cloud-deploy          # default for every entry
tasks:
  - key: A1
    name: Epic title
    description: |
      Why and what.
      - bullet
    hours: 8
    milestone: M1
    tag: [Software]
  - key: A2
    name: First step
    parent: A1
    assign: me                 # or a list
    priority: high
    deadline: 2026-11-01
  - key: A3
    name: Second step
    parent: A1
    blocked_by: A2             # or a list; keys or task ids
```

Fields: key, project, name, description, stage, assign, tag, priority,
deadline, state, milestone, parent, blocked_by, blocks, hours.

Use real milestones and dependencies only where the board has them on (see
`project-settings`). Turning a setting on changes the board for everyone, so
ask first.

## Tags

```bash
odoo-kanban tags [--project P] [--search text]   # list, with task counts
odoo-kanban create-tag "Name" [--color blue]
odoo-kanban update-tag "Name" [--name "New name"] [--color 0-11|red|orange|...]
odoo-kanban delete-tag "Name"
```

Tags are global: every project shares one list, and names are unique. Renaming
or deleting a tag affects every board, so confirm first and say how many tasks
use it. Use `update --tag/--untag` to tag individual tasks.

## Timesheets

```bash
odoo-kanban timesheet list                 # my hours this week, grouped by day
odoo-kanban timesheet list --last-week | --day 2026-10-06 | --from D --to D
odoo-kanban timesheet log --task 1234 --hours 1:30 --description "what was done" [--date yesterday]
odoo-kanban timesheet log --project P --hours 2 --description "..."   # no specific task
odoo-kanban timesheet update 555 --hours 2 --description "..." --task 1235
odoo-kanban timesheet delete 555
```

Hours accept `1.5`, `1:30` or `90m`. Logging, updating and deleting are writes,
so propose the entries first and get the user's OK. Timesheets feed billing and
payroll, so never guess hours. Odoo refuses to log time for a user who isn't
linked to an employee record. If that happens, tell the user to ask HR.

## Errors

- **HTTP 401**: the key expired or was revoked. Tell the user. Don't try to
  fix it yourself.

Never run `odoo-kanban rotate-key`. The user manages key rotation.
