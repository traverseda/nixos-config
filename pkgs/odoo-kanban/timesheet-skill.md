---
name: odoo-timesheet
description: Draft and log the user's Odoo timesheet for a day from their Claude Code sessions and git commits. Use when the user asks to fill out, draft, check or catch up on timesheets or hours.
---

# Odoo timesheets

Turn a day's work into Odoo timesheet lines. Always draft first, get the user's
approval, then log. Timesheets feed billing and payroll, so never log hours
the user hasn't approved.

## 1. Gather

```bash
odoo-kanban worklog [YYYY-MM-DD|yesterday]   # sessions + commits per repo (default today)
odoo-kanban timesheet list --day DATE        # what's already logged, so nothing is doubled
cat ~/.config/odoo-kanban/timesheet-rules.toml
```

`worklog` hours are wall-clock. Parallel sessions in a repo are merged, and a
block ends after 20 idle minutes. Use the per-repo figure as the budget for
that repo, and split it across tickets in proportion to the per-session times.
Never add session times together, because they overlap.

The evidence only covers work in Claude and git. Meetings, reviews, calls and
reading aren't in it. Say so in the draft, and ask about anything the user
would know but the logs don't show.

## 2. Classify each piece of work

Classify each session or commit, not each repo. The rules file gives each
repo's default category:

- **spiri**: log against the ticket. Look for task ids (`#107`) in prompts and
  commit messages. Otherwise match the work to a ticket with
  `odoo-kanban tasks --project P --search WORD --closed`. If nothing fits, log
  it on the project with no task.
- **research** goes to Internal › #125 Research.
- **professional_development** goes to Internal › #126 Professional
  development.
- **internal_misc** (work tooling, admin, odds and ends) goes on the Internal
  project with no task.
- **untracked** isn't logged. List it in the draft as "not logged" so the
  user can overrule.

Personal-repo work that looks work-related, unknown repos and anything
borderline go to the user as a question. Don't guess. When the user corrects a
classification that will come up again (a new repo, or a kind of work), update
the rules file.

## 3. Draft

Show a table with these columns: hours (rounded to 15 min), project › task,
and a short description built from commit subjects and prompts. Add the
not-logged rows and the total. Flag what you're unsure of: rough splits,
closed tickets, and gaps in the day.

## 4. Log (after approval)

```bash
odoo-kanban timesheet log --date DATE --task ID --hours 1:15 --description "..."
odoo-kanban timesheet log --date DATE --project Internal --hours 0:30 --description "..."
odoo-kanban timesheet list --day DATE     # show the result
```

Fix mistakes with `timesheet update LINE ...` or `timesheet delete LINE`.
