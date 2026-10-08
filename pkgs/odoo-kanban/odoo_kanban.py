"""odoo-kanban: read and edit Odoo project kanban boards over the JSON-2 API.

The API key is read from kwallet (folder env_vars) on every run, falling back
to the environment variable of the same name. Reading the wallet first means a
key rotated by `rotate-key` takes effect immediately, even in shells that
exported the old value at login.
"""

import argparse
import datetime
import html
import json
import os
import re
import socket
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

URL = os.environ.get("ODOO_KANBAN_URL", "https://odoo.internal.spiri.ca").rstrip("/")
DB = os.environ.get("ODOO_KANBAN_DB", "odoo")
WALLET_KEY = os.environ.get("ODOO_KANBAN_WALLET_KEY", "ODOO_SPIRI_INTERNAL_API")
WALLET_FOLDER = "env_vars"
WALLET = "kdewallet"
KWALLET_QUERY = "@kwalletQuery@"
STATE_FILE = (
    Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    / "odoo-kanban"
    / "key.json"
)
# Odoo keys are 20 random bytes, hex encoded. kwallet-query prints its errors
# to stdout, so anything that doesn't look like a key is treated as missing.
KEY_RE = re.compile(r"^[0-9a-f]{40}$")

PRIORITIES = {"0": "", "1": "★", "2": "★★", "3": "★★★"}
PRIORITY_NAMES = {"low": "0", "medium": "1", "high": "2", "urgent": "3"}
STATE_LABELS = {
    "01_in_progress": "in progress", "02_changes_requested": "changes requested",
    "03_approved": "approved", "04_waiting_normal": "waiting",
    "1_done": "done", "1_canceled": "cancelled",
}
STATES = {
    "in_progress": "01_in_progress",
    "changes_requested": "02_changes_requested",
    "approved": "03_approved",
    "done": "1_done",
    "canceled": "1_canceled",
}
TASK_LIST_FIELDS = [
    "name", "project_id", "stage_id", "user_ids", "tag_ids",
    "priority", "state", "date_deadline", "parent_id", "milestone_id", "depend_on_ids",
]
CLOSED = ("1_done", "1_canceled")


class OdooError(Exception):
    pass


# --- key storage -------------------------------------------------------------

def wallet_read():
    try:
        out = subprocess.run(
            [KWALLET_QUERY, "-r", WALLET_KEY, "-f", WALLET_FOLDER, WALLET],
            capture_output=True, text=True, timeout=30,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out if KEY_RE.match(out) else None


def wallet_write(value):
    subprocess.run(
        [KWALLET_QUERY, "-w", WALLET_KEY, "-f", WALLET_FOLDER, WALLET],
        # kwallet-query -w can only overwrite an existing entry, not create one.
        input=value + "\n", capture_output=True, text=True, timeout=30,
    )
    if wallet_read() != value:
        raise OdooError("writing the new key to kwallet failed (read-back mismatch)")


def get_key():
    key = wallet_read() or os.environ.get(WALLET_KEY, "").strip()
    if not key:
        raise OdooError(
            f"no API key: store one in kwallet ({WALLET}/{WALLET_FOLDER}/{WALLET_KEY}) "
            f"or export {WALLET_KEY}"
        )
    return key


def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n")


# --- JSON-2 transport --------------------------------------------------------

def call(model, method, auth=None, **params):
    """POST to /json/2/<model>/<method>; `auth` overrides the stored key."""
    req = urllib.request.Request(
        f"{URL}/json/2/{model}/{method}",
        data=json.dumps(params).encode(),
        headers={
            "Authorization": f"bearer {auth or get_key()}",
            "X-Odoo-Database": DB,
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "odoo-kanban",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        try:
            msg = json.load(e).get("message") or e.reason
        except ValueError:
            msg = e.reason
        if e.code == 401:
            msg += (
                f" (key expired or revoked? create a new one under Preferences > "
                f"Account Security at {URL} and store it in kwallet as {WALLET_KEY})"
            )
        raise OdooError(f"{model}.{method}: HTTP {e.code}: {msg}") from None
    except urllib.error.URLError as e:
        raise OdooError(f"cannot reach {URL}: {e.reason}") from None


def search_read(model, domain, fields, **kw):
    return call(model, "search_read", domain=domain, fields=fields, **kw)


def display_names(model, ids):
    ids = sorted(set(ids))
    if not ids:
        return {}
    return {r["id"]: r["display_name"] for r in call(model, "read", ids=ids, fields=["display_name"])}


def write(model, ids, vals):
    """Call write(), coping with the argument's name.

    JSON-2 only takes keyword arguments, bound against the outermost override.
    Core names it `vals`, but OCA's project_forecast_line overrides
    project.task.write as `values`, so retry with that name when needed.
    """
    try:
        return call(model, "write", ids=ids, vals=vals)
    except OdooError as e:
        if "missing a required argument" not in str(e):
            raise
        return call(model, "write", ids=ids, values=vals)


def current_uid():
    return call("res.users", "context_get")["uid"]


# --- resolution of human references to ids ---------------------------------

def resolve(model, ref, domain=(), field="name", what=None):
    """Accept a numeric id or a (case-insensitive, unique) name."""
    if str(ref).isdigit():
        return int(ref)
    what = what or model
    rows = search_read(model, list(domain) + [[field, "ilike", ref]], [field], limit=20)
    exact = [r for r in rows if (r[field] or "").lower() == ref.lower()]
    if len(exact) == 1:
        return exact[0]["id"]
    if len(rows) == 1:
        return rows[0]["id"]
    if not rows:
        raise OdooError(f"no {what} matching {ref!r}")
    listing = ", ".join(f"#{r['id']} {r[field]}" for r in rows)
    raise OdooError(f"{what} {ref!r} is ambiguous: {listing}")


def resolve_project(ref):
    return resolve("project.project", ref, what="project")


def resolve_stage(project_id, ref):
    return resolve("project.task.type", ref, [["project_ids", "in", [project_id]]], what="stage")


def resolve_user(ref):
    if ref == "me":
        return current_uid()
    if "@" in ref:
        return resolve("res.users", ref, [["share", "=", False]], field="login", what="user")
    return resolve("res.users", ref, [["share", "=", False]], what="user")


def resolve_tag(ref):
    return resolve("project.tags", ref, what="tag")


def resolve_milestone(project_id, ref):
    domain = [["project_id", "=", project_id]] if project_id else []
    return resolve("project.milestone", ref, domain, what="milestone")


def parent_ref(value):
    """argparse type for --parent: a task id, or '' / 0 for none."""
    if value in ("", "0"):
        return False
    if not value.isdigit():
        raise argparse.ArgumentTypeError("expected a task id, or '' for none")
    return int(value)


# --- formatting --------------------------------------------------------------

def html_to_text(value):
    if not value:
        return ""
    text = re.sub(r"(?i)<br\s*/?>|</(p|div|li|h[1-6]|tr)>", "\n", value)
    text = re.sub(r"(?i)<li[^>]*>", "- ", text)
    text = html.unescape(re.sub(r"<[^>]+>", "", text))
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def inline_html(text):
    """Escape text and turn `#123` into a link to task 123."""
    return re.sub(
        r"(?<![\w&/])#(\d+)\b",
        r'<a href="/odoo/project.task/\1" data-oe-model="project.task" data-oe-id="\1">#\1</a>',
        html.escape(text),
    )


def text_to_html(value):
    """Plain text to Odoo HTML: blank lines split paragraphs, `- `/`* `/`1. `
    lines become lists, and `#123` links to that task."""
    out, para, items, list_tag = [], [], [], None

    def flush_para():
        if para:
            out.append("<p>" + "<br>".join(inline_html(line) for line in para) + "</p>")
            para.clear()

    def flush_list():
        nonlocal list_tag
        if items:
            out.append(f"<{list_tag}>" + "".join(f"<li>{inline_html(i)}</li>" for i in items) + f"</{list_tag}>")
            items.clear()
        list_tag = None

    for line in value.strip().splitlines():
        m = re.match(r"\s*(?:[-*]|(\d+)[.)])\s+(.*)", line)
        if m:
            flush_para()
            tag = "ol" if m.group(1) else "ul"
            if list_tag and list_tag != tag:
                flush_list()
            list_tag = tag
            items.append(m.group(2))
        elif not line.strip():
            flush_para()
            flush_list()
        else:
            flush_list()
            para.append(line)
    flush_para()
    flush_list()
    return "".join(out)


def m2o(value):
    return value[1] if isinstance(value, list) else ""


def task_line(t, users, tags, show_stage=False, blockers=None):
    parts = [f"#{t['id']}"]
    if PRIORITIES.get(t["priority"]):
        parts.append(PRIORITIES[t["priority"]])
    parts.append(t["name"])
    if t["state"] in CLOSED:
        parts.append(f"[{t['state'][2:]}]")
    open_blockers = (blockers or {}).get(t["id"])
    if open_blockers:
        parts.append("⛔ " + ",".join(f"#{b}" for b in open_blockers))
    if show_stage and t["stage_id"]:
        parts.append(f"<{m2o(t['stage_id'])}>")
    if t["user_ids"]:
        parts.append("— " + ", ".join(users.get(u, str(u)) for u in t["user_ids"]))
    if t["tag_ids"]:
        parts.append("{" + ", ".join(tags.get(g, str(g)) for g in t["tag_ids"]) + "}")
    if t["date_deadline"]:
        parts.append(f"due {t['date_deadline'][:10]}")
    if t.get("milestone_id"):
        parts.append(f"⚑ {m2o(t['milestone_id'])}")
    if t["parent_id"]:
        parts.append(f"(sub of #{t['parent_id'][0]})")
    return " ".join(parts)


def open_blockers(tasks):
    """{task id: [ids of its blockers that aren't done/cancelled]}."""
    ids = sorted({b for t in tasks for b in t.get("depend_on_ids") or []})
    if not ids:
        return {}
    states = {r["id"]: r["state"] for r in call("project.task", "read", ids=ids, fields=["state"])}
    result = {}
    for t in tasks:
        still_open = [b for b in t.get("depend_on_ids") or [] if states.get(b) not in CLOSED]
        if still_open:
            result[t["id"]] = still_open
    return result


def dependencies_off_note(project_id, tasks):
    """Warn when a board shows dependency info Odoo itself ignores."""
    if project_id and any(t.get("depend_on_ids") for t in tasks):
        warn_if_dependencies_off(project_id)


def related_names(tasks):
    users = display_names("res.users", [u for t in tasks for u in t["user_ids"]])
    tags = display_names("project.tags", [g for t in tasks for g in t["tag_ids"]])
    return users, tags


def emit(args, data, render):
    if args.json:
        print(json.dumps(data, indent=2, default=str))
    else:
        render()


# --- commands ----------------------------------------------------------------

def cmd_whoami(args):
    uid = current_uid()
    user = call("res.users", "read", ids=[uid], fields=["name", "login"])[0]
    emit(args, user, lambda: print(f"#{uid} {user['name']} <{user['login']}> on {URL} (db {DB})"))


def cmd_projects(args):
    domain = [["is_favorite", "=", True]] if args.favorites else []
    rows = search_read(
        "project.project", domain, ["name", "open_task_count", "user_id"], order="name"
    )

    def render():
        for p in rows:
            print(f"#{p['id']} {p['name']} ({p['open_task_count']} open) — {m2o(p['user_id']) or 'no manager'}")
    emit(args, rows, render)


def project_stages(project_id):
    return search_read(
        "project.task.type", [["project_ids", "in", [project_id]]],
        ["name", "fold", "sequence"], order="sequence, id",
    )


def cmd_stages(args):
    rows = project_stages(resolve_project(args.project))

    def render():
        for s in rows:
            print(f"#{s['id']} {s['name']}{' (folded)' if s['fold'] else ''}")
    emit(args, rows, render)


def task_domain(args, project_id=None):
    domain = []
    if project_id:
        domain.append(["project_id", "=", project_id])
    if not getattr(args, "closed", False):
        domain.append(["is_closed", "=", False])
    if getattr(args, "mine", False):
        domain.append(["user_ids", "in", [current_uid()]])
    if getattr(args, "assignee", None):
        domain.append(["user_ids", "in", [resolve_user(args.assignee)]])
    if getattr(args, "tag", None):
        domain.append(["tag_ids", "in", [resolve_tag(args.tag)]])
    if getattr(args, "milestone", None):
        domain.append(["milestone_id", "=", resolve_milestone(project_id, args.milestone)])
    if getattr(args, "search", None):
        domain += ["|", ["name", "ilike", args.search], ["description", "ilike", args.search]]
    return domain


def cmd_board(args):
    project_id = resolve_project(args.project)
    stages = project_stages(project_id)
    tasks = search_read(
        "project.task", task_domain(args, project_id), TASK_LIST_FIELDS,
        order="priority desc, sequence, id",
    )
    blockers = open_blockers(tasks)
    if args.ready:
        tasks = [t for t in tasks if t["id"] not in blockers and t["state"] not in CLOSED]
    dependencies_off_note(project_id, tasks)
    by_stage = {}
    for t in tasks:
        by_stage.setdefault(t["stage_id"][0] if t["stage_id"] else None, []).append(t)
    columns = [
        {"id": s["id"], "name": s["name"], "fold": s["fold"], "tasks": by_stage.get(s["id"], [])}
        for s in stages
        if args.folded or not s["fold"] or by_stage.get(s["id"])
    ]
    if by_stage.get(None):
        columns.append({"id": None, "name": "(no stage)", "fold": False, "tasks": by_stage[None]})

    def render():
        users, tags = related_names(tasks)
        for col in columns:
            print(f"## {col['name']} (stage #{col['id']}) [{len(col['tasks'])}]")
            for t in col["tasks"]:
                print("  " + task_line(t, users, tags, blockers=blockers))
            print()
    emit(args, columns, render)


def cmd_tasks(args):
    project_id = resolve_project(args.project) if args.project else None
    domain = task_domain(args, project_id)
    if args.stage:
        if not project_id:
            raise OdooError("--stage needs --project")
        domain.append(["stage_id", "=", resolve_stage(project_id, args.stage)])
    tasks = search_read(
        "project.task", domain, TASK_LIST_FIELDS,
        order="date_deadline asc, priority desc, id desc", limit=args.limit,
    )
    blockers = open_blockers(tasks)
    if args.ready:
        tasks = [t for t in tasks if t["id"] not in blockers and t["state"] not in CLOSED]
    dependencies_off_note(project_id, tasks)

    def render():
        users, tags = related_names(tasks)
        for t in tasks:
            prefix = "" if project_id else f"[{m2o(t['project_id']) or 'private'}] "
            print(prefix + task_line(t, users, tags, show_stage=True, blockers=blockers))
    emit(args, tasks, render)


def cmd_show(args):
    fields = TASK_LIST_FIELDS + ["description", "child_ids", "create_date", "write_date",
                                 "depend_on_ids", "dependent_ids", "allocated_hours", "effective_hours"]
    rows = call("project.task", "read", ids=[args.task], fields=fields)
    if not rows:
        raise OdooError(f"no task #{args.task}")
    task = rows[0]
    messages = []
    if args.messages:
        messages = search_read(
            "mail.message",
            [["model", "=", "project.task"], ["res_id", "=", args.task],
             ["message_type", "in", ["comment", "email"]]],
            ["date", "author_id", "body", "subtype_id"],
            order="date desc", limit=args.messages,
        )[::-1]
    task["messages"] = messages
    linked = []
    if task["depend_on_ids"] or task["dependent_ids"]:
        linked = call("project.task", "read", ids=task["depend_on_ids"] + task["dependent_ids"],
                      fields=["name", "state"])
        if task["project_id"]:
            warn_if_dependencies_off(task["project_id"][0])
    task["linked_tasks"] = linked

    def render():
        users, tags = related_names([task])
        still_open = [r["id"] for r in linked if r["id"] in task["depend_on_ids"] and r["state"] not in CLOSED]
        print(task_line(task, users, tags, blockers={task["id"]: still_open}))
        print(f"Project: {m2o(task['project_id']) or 'private'}   Stage: {m2o(task['stage_id'])}   State: {task['state']}")
        if task["milestone_id"] or task["parent_id"]:
            print(f"Milestone: {m2o(task['milestone_id']) or '-'}   Parent: {m2o(task['parent_id']) or '-'}"
                  + (f" (#{task['parent_id'][0]})" if task["parent_id"] else ""))
        print(f"Created: {task['create_date']}   Updated: {task['write_date']}")
        if task["allocated_hours"] or task["effective_hours"]:
            print(f"Estimate: {fmt_hours(task['allocated_hours']) if task['allocated_hours'] else '-'}"
                  f"   Spent: {fmt_hours(task['effective_hours'])}")
        if task["child_ids"]:
            print("Sub-tasks: " + ", ".join(f"#{c}" for c in task["child_ids"]))
        for label, ids in (("Blocked by", task["depend_on_ids"]), ("Blocking", task["dependent_ids"])):
            if ids:
                print(f"{label}:")
                for r in linked:
                    if r["id"] in ids:
                        print(f"  #{r['id']} {r['name']} [{STATE_LABELS.get(r['state'], r['state'])}]")
        desc = html_to_text(task["description"])
        if desc:
            print("\n" + desc)
        if messages:
            print("\n--- messages ---")
            for m in messages:
                print(f"[{m['date']}] {m2o(m['author_id'])} ({m2o(m['subtype_id'])}):")
                print("  " + html_to_text(m["body"]).replace("\n", "\n  "))
    emit(args, task, render)


def task_vals(args, project_id=None):
    vals = {}
    if args.name:
        vals["name"] = args.name
    if args.description is not None:
        vals["description"] = text_to_html(args.description)
    if args.priority:
        vals["priority"] = PRIORITY_NAMES[args.priority]
    if args.deadline is not None:
        vals["date_deadline"] = args.deadline or False
    if args.state:
        vals["state"] = STATES[args.state]
    if args.stage:
        vals["stage_id"] = resolve_stage(project_id, args.stage)
    if args.assign is not None:
        vals["user_ids"] = [[6, 0, [resolve_user(u) for u in args.assign]]]
    if args.tag:
        vals["tag_ids"] = [[4, resolve_tag(t)] for t in args.tag]
    if args.milestone is not None:
        vals["milestone_id"] = resolve_milestone(project_id, args.milestone) if args.milestone else False
    if args.parent is not None:
        vals["parent_id"] = args.parent
    if args.hours is not None:
        vals["allocated_hours"] = args.hours
    if args.blocked_by:
        vals["depend_on_ids"] = [[4, i] for i in args.blocked_by]
    if args.blocks:
        vals["dependent_ids"] = [[4, i] for i in args.blocks]
    return vals


def warn_if_dependencies_off(project_id):
    if not project_id:
        return
    project = call("project.project", "read", ids=[project_id], fields=["allow_task_dependencies"])[0]
    if not project["allow_task_dependencies"]:
        print("note: task dependencies are turned off in this project's settings, so Odoo's "
              "UI won't show them or mark tasks as waiting", file=sys.stderr)


TASK_FILE_KEYS = {
    "key", "project", "name", "description", "stage", "assign", "tag", "priority",
    "deadline", "state", "milestone", "parent", "blocked_by", "blocks", "hours",
}


def load_task_file(path):
    """Read a YAML (or JSON) list of tasks; either a bare list or
    {project: default, tasks: [...]}."""
    import yaml  # only needed here
    with open(path) as fh:
        data = yaml.safe_load(fh)
    default_project = None
    if isinstance(data, dict):
        default_project, data = data.get("project"), data.get("tasks")
    if not isinstance(data, list) or not all(isinstance(t, dict) for t in data):
        raise OdooError(f"{path}: expected a list of tasks (or {{project: ..., tasks: [...]}})")
    return default_project, data


def as_list(value):
    if value is None:
        return []
    return value if isinstance(value, list) else [value]


def plan_task_file(path, cli_project):
    """Validate and resolve everything before anything is created."""
    default_project, entries = load_task_file(path)
    keys = {}
    for n, e in enumerate(entries, 1):
        unknown = set(e) - TASK_FILE_KEYS
        if unknown:
            raise OdooError(f"task {n}: unknown field(s) {', '.join(sorted(unknown))}")
        if not e.get("name"):
            raise OdooError(f"task {n}: missing name")
        key = str(e.get("key", f"#{n}"))
        if key in keys:
            raise OdooError(f"duplicate key {key!r}")
        keys[key] = e

    def ref(value, what, key):
        """A local key, or an existing task id."""
        if str(value) in keys:
            return ("key", str(value))
        if str(value).isdigit():
            return ("id", int(value))
        raise OdooError(f"{key}: {what} {value!r} is neither a key in this file nor a task id")

    plan = []
    for key, e in keys.items():
        project_ref = e.get("project") or default_project or cli_project
        parent = ref(e["parent"], "parent", key) if e.get("parent") not in (None, "") else None
        if not project_ref and parent and parent[0] == "key":
            project_ref = keys[parent[1]].get("project") or default_project or cli_project
        if project_ref:
            project_id = resolve_project(str(project_ref))
        elif parent and parent[0] == "id":
            project_id = task_project(parent[1])
        else:
            raise OdooError(f"{key}: no project (set it per task, at the top of the file, or with --project)")
        ns = argparse.Namespace(
            name=e["name"], description=e.get("description"), stage=e.get("stage"),
            assign=[str(u) for u in as_list(e["assign"])] if "assign" in e else None,
            tag=[str(t) for t in as_list(e.get("tag"))], priority=e.get("priority"),
            deadline=str(e["deadline"]) if e.get("deadline") else None, state=e.get("state"),
            milestone=str(e["milestone"]) if e.get("milestone") else None,
            hours=parse_hours(str(e["hours"])) if e.get("hours") is not None else None,
            parent=None, blocked_by=None, blocks=None,
        )
        if ns.priority and ns.priority not in PRIORITY_NAMES:
            raise OdooError(f"{key}: priority must be one of {', '.join(PRIORITY_NAMES)}")
        if ns.state and ns.state not in STATES:
            raise OdooError(f"{key}: state must be one of {', '.join(STATES)}")
        vals = task_vals(ns, project_id)
        vals["project_id"] = project_id
        if ns.assign is None:
            vals["user_ids"] = [[6, 0, []]]
        plan.append({
            "key": key, "vals": vals, "parent": parent,
            "blocked_by": [ref(b, "blocked_by", key) for b in as_list(e.get("blocked_by"))],
            "blocks": [ref(b, "blocks", key) for b in as_list(e.get("blocks"))],
        })

    # Parents must exist before their children: order by parent depth.
    order, done = [], set()

    def visit(item, path=()):
        if item["key"] in done:
            return
        if item["key"] in path:
            raise OdooError(f"parent cycle: {' -> '.join(path + (item['key'],))}")
        if item["parent"] and item["parent"][0] == "key":
            visit(by_key[item["parent"][1]], path + (item["key"],))
        done.add(item["key"])
        order.append(item)
    by_key = {item["key"]: item for item in plan}
    for item in plan:
        visit(item)
    return order


def create_from_file(args):
    order = plan_task_file(args.from_file, args.project)
    if args.dry_run:
        emit(args, [{"key": i["key"], "vals": i["vals"], "parent": i["parent"],
                     "blocked_by": i["blocked_by"], "blocks": i["blocks"]} for i in order],
             lambda: [print(f"{i['key']}: {i['vals']['name']} (project #{i['vals']['project_id']})"
                            + (f" parent={i['parent'][1]}" if i["parent"] else "")
                            + (f" blocked_by={[b[1] for b in i['blocked_by']]}" if i["blocked_by"] else "")
                            + (f" blocks={[b[1] for b in i['blocks']]}" if i["blocks"] else ""))
                      for i in order])
        return
    ids = {}

    def resolved(r):
        return ids[r[1]] if r[0] == "key" else r[1]
    try:
        for item in order:
            vals = dict(item["vals"])
            if item["parent"]:
                vals["parent_id"] = resolved(item["parent"])
            ids[item["key"]] = call("project.task", "create", vals_list=[vals])[0]
        for item in order:
            vals = {}
            if item["blocked_by"]:
                vals["depend_on_ids"] = [[4, resolved(b)] for b in item["blocked_by"]]
            if item["blocks"]:
                vals["dependent_ids"] = [[4, resolved(b)] for b in item["blocks"]]
            if vals:
                write("project.task", [ids[item["key"]]], vals)
    except OdooError as e:
        made = ", ".join(f"{k}=#{v}" for k, v in ids.items()) or "none"
        raise OdooError(f"{e}\ntasks already created: {made}") from None
    if any(i["blocked_by"] or i["blocks"] for i in order):
        for project_id in {i["vals"]["project_id"] for i in order}:
            warn_if_dependencies_off(project_id)
    emit(args, ids, lambda: [print(f"{k} -> #{v}") for k, v in ids.items()])


def cmd_create(args):
    if args.from_file:
        return create_from_file(args)
    if not args.name:
        raise OdooError("--name is required (or use --from FILE)")
    if args.project:
        project_id = resolve_project(args.project)
    elif args.parent:
        project_id = task_project(args.parent)
    else:
        raise OdooError("--project is required unless --parent is given")
    vals = task_vals(args, project_id)
    vals["project_id"] = project_id
    if args.assign is None:
        # Odoo would otherwise assign the creator; leave unassigned unless asked.
        vals["user_ids"] = [[6, 0, []]]
    task_id = call("project.task", "create", vals_list=[vals])[0]
    if args.blocked_by or args.blocks:
        warn_if_dependencies_off(project_id)
    emit(args, {"id": task_id}, lambda: print(f"created task #{task_id}"))


def task_project(task_id):
    rows = call("project.task", "read", ids=[task_id], fields=["project_id"])
    if not rows:
        raise OdooError(f"no task #{task_id}")
    return rows[0]["project_id"][0] if rows[0]["project_id"] else None


def cmd_update(args):
    if args.project:
        project_id = resolve_project(args.project)
    elif args.stage or args.milestone:
        project_id = task_project(args.task)
    else:
        project_id = None
    vals = task_vals(args, project_id)
    if args.project:
        # Odoo picks a stage in the new project by itself (unless --stage was
        # given); milestones are per project, so drop the old one.
        vals["project_id"] = project_id
        vals.setdefault("milestone_id", False)
    m2m = []
    for u in args.add_assignee or []:
        m2m.append([4, resolve_user(u)])
    for u in args.unassign or []:
        m2m.append([3, resolve_user(u)])
    if m2m:
        vals["user_ids"] = vals.get("user_ids", []) + m2m
    if args.untag:
        vals["tag_ids"] = vals.get("tag_ids", []) + [[3, resolve_tag(t)] for t in args.untag]
    if args.unblock:
        vals["depend_on_ids"] = vals.get("depend_on_ids", []) + [[3, i] for i in args.unblock]
    if args.unblocks:
        vals["dependent_ids"] = vals.get("dependent_ids", []) + [[3, i] for i in args.unblocks]
    if not vals:
        raise OdooError("nothing to update")
    write("project.task", [args.task], vals)
    if args.blocked_by or args.blocks:
        warn_if_dependencies_off(project_id or task_project(args.task))
    emit(args, {"id": args.task, "vals": vals}, lambda: print(f"updated task #{args.task}"))


def cmd_move(args):
    stage_id = resolve_stage(task_project(args.task), args.stage)
    write("project.task", [args.task], {"stage_id": stage_id})
    emit(args, {"id": args.task, "stage_id": stage_id},
         lambda: print(f"moved task #{args.task} to stage #{stage_id}"))


PROJECT_SETTINGS = {"milestones": "allow_milestones", "dependencies": "allow_task_dependencies"}


def cmd_project_settings(args):
    project_id = resolve_project(args.project)
    vals = {field: getattr(args, name) == "on"
            for name, field in PROJECT_SETTINGS.items() if getattr(args, name)}
    if vals:
        write("project.project", [project_id], vals)
    current = call("project.project", "read", ids=[project_id], fields=list(PROJECT_SETTINGS.values()))[0]
    data = {name: current[field] for name, field in PROJECT_SETTINGS.items()}

    def render():
        for name, on in data.items():
            print(f"{name}: {'on' if on else 'off'}")
    emit(args, data, render)


def cmd_milestones(args):
    project_id = resolve_project(args.project)
    domain = [["project_id", "=", project_id]]
    if not args.reached:
        domain.append(["is_reached", "=", False])
    rows = search_read("project.milestone", domain, ["name", "deadline", "is_reached", "task_ids"])
    project = call("project.project", "read", ids=[project_id], fields=["allow_milestones"])[0]
    if not project["allow_milestones"]:
        print("note: milestones are turned off in this project's settings, so Odoo's UI "
              "won't show them", file=sys.stderr)

    def render():
        for m in rows:
            print(f"#{m['id']} {m['name']}{' [reached]' if m['is_reached'] else ''}"
                  f"{' due ' + m['deadline'] if m['deadline'] else ''} ({len(m['task_ids'])} tasks)")
    emit(args, rows, render)


def cmd_create_milestone(args):
    vals = {"project_id": resolve_project(args.project), "name": args.name}
    if args.deadline:
        vals["deadline"] = args.deadline
    milestone_id = call("project.milestone", "create", vals_list=[vals])[0]
    emit(args, {"id": milestone_id}, lambda: print(f"created milestone #{milestone_id}"))


def cmd_update_milestone(args):
    vals = {}
    if args.name:
        vals["name"] = args.name
    if args.deadline is not None:
        vals["deadline"] = args.deadline or False
    if args.reached is not None:
        vals["is_reached"] = args.reached
    if not vals:
        raise OdooError("nothing to update")
    write("project.milestone", [args.milestone], vals)
    emit(args, {"id": args.milestone, "vals": vals},
         lambda: print(f"updated milestone #{args.milestone}"))


def cmd_comment(args):
    msg_id = call(
        "project.task", "message_post", ids=[args.task],
        body=text_to_html(args.text), body_is_html=True, message_type="comment",
        subtype_xmlid="mail.mt_comment" if args.send else "mail.mt_note",
    )
    kind = "message sent to followers" if args.send else "internal note"
    emit(args, {"id": msg_id[0]}, lambda: print(f"posted {kind} on task #{args.task}"))


# --- tags --------------------------------------------------------------------

# Odoo's color palette, as numbered in its many2many_tags widget.
TAG_COLORS = ["none", "red", "orange", "yellow", "cyan", "purple", "almond",
              "teal", "blue", "raspberry", "green", "violet"]


def parse_color(value):
    """argparse type: a color name or its number (0-11)."""
    v = value.strip().lower()
    if v.isdigit() and int(v) < len(TAG_COLORS):
        return int(v)
    if v in TAG_COLORS:
        return TAG_COLORS.index(v)
    raise argparse.ArgumentTypeError("color must be 0-11 or one of: " + ", ".join(TAG_COLORS))


def cmd_tags(args):
    domain = []
    if args.project:
        domain.append(["task_ids.project_id", "=", resolve_project(args.project)])
    if args.search:
        domain.append(["name", "ilike", args.search])
    rows = search_read("project.tags", domain, ["name", "color", "task_ids"], order="name")

    def render():
        for t in rows:
            color = TAG_COLORS[t["color"]] if 0 <= t["color"] < len(TAG_COLORS) else t["color"]
            print(f"#{t['id']} {t['name']} ({color}, {len(t['task_ids'])} tasks)")
    emit(args, rows, render)


def cmd_create_tag(args):
    vals = {"name": args.name}
    if args.color is not None:
        vals["color"] = args.color
    tag_id = call("project.tags", "create", vals_list=[vals])[0]
    emit(args, {"id": tag_id}, lambda: print(f"created tag #{tag_id}"))


def cmd_update_tag(args):
    tag_id = resolve_tag(args.tag)
    vals = {}
    if args.name:
        vals["name"] = args.name
    if args.color is not None:
        vals["color"] = args.color
    if not vals:
        raise OdooError("nothing to update")
    write("project.tags", [tag_id], vals)
    emit(args, {"id": tag_id, "vals": vals}, lambda: print(f"updated tag #{tag_id}"))


def cmd_delete_tag(args):
    tag_id = resolve_tag(args.tag)
    call("project.tags", "unlink", ids=[tag_id])
    emit(args, {"id": tag_id}, lambda: print(f"deleted tag #{tag_id} (removed from all tasks)"))


# --- timesheets --------------------------------------------------------------

TIMESHEET_FIELDS = ["date", "unit_amount", "name", "project_id", "task_id", "user_id"]


def parse_hours(value):
    """argparse type: '1.5', '1:30', '90m' or '2h' -> hours as a float."""
    v = value.strip().lower()
    try:
        if ":" in v:
            h, m = v.split(":", 1)
            return int(h or 0) + int(m) / 60
        if v.endswith("m"):
            return float(v[:-1]) / 60
        return float(v.removesuffix("h"))
    except ValueError:
        raise argparse.ArgumentTypeError(f"can't read {value!r} as hours (try 1.5, 1:30, 90m)") from None


def parse_date(value):
    """argparse type: YYYY-MM-DD, 'today' or 'yesterday'."""
    today = datetime.date.today()
    special = {"today": today, "yesterday": today - datetime.timedelta(days=1)}
    try:
        return special.get(value) or datetime.date.fromisoformat(value)
    except ValueError:
        raise argparse.ArgumentTypeError("expected YYYY-MM-DD, 'today' or 'yesterday'") from None


def fmt_hours(h):
    return f"{int(h)}:{round(h % 1 * 60):02d}"


def timesheet_range(args):
    if args.day:
        return args.day, args.day
    monday = datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())
    if args.last_week:
        monday -= datetime.timedelta(days=7)
    start = args.start or monday
    end = args.end or (start + datetime.timedelta(days=6) if not args.start else datetime.date.today())
    return start, end


def cmd_timesheet_list(args):
    start, end = timesheet_range(args)
    uid = resolve_user(args.user) if args.user else current_uid()
    domain = [["user_id", "=", uid], ["project_id", "!=", False],
              ["date", ">=", start.isoformat()], ["date", "<=", end.isoformat()]]
    if args.project:
        domain.append(["project_id", "=", resolve_project(args.project)])
    if args.task:
        domain.append(["task_id", "=", args.task])
    rows = search_read("account.analytic.line", domain, TIMESHEET_FIELDS, order="date, id")

    def render():
        print(f"{start} .. {end}")
        day = None
        for r in rows:
            if r["date"] != day:
                day = r["date"]
                total = sum(x["unit_amount"] for x in rows if x["date"] == day)
                weekday = datetime.date.fromisoformat(day).strftime("%a")
                print(f"\n{weekday} {day}  [{fmt_hours(total)}]")
            task = f" / #{r['task_id'][0]} {m2o(r['task_id'])}" if r["task_id"] else ""
            print(f"  #{r['id']} {fmt_hours(r['unit_amount'])}  {m2o(r['project_id'])}{task} — {r['name']}")
        print(f"\ntotal {fmt_hours(sum(r['unit_amount'] for r in rows))}")
    emit(args, rows, render)


def timesheet_vals(args):
    vals = {}
    if args.task:
        vals["task_id"] = args.task
    if args.project:
        vals["project_id"] = resolve_project(args.project)
    if args.hours is not None:
        vals["unit_amount"] = args.hours
    if args.description:
        vals["name"] = args.description
    if args.date:
        vals["date"] = args.date.isoformat()
    return vals


def cmd_timesheet_log(args):
    if not (args.task or args.project):
        raise OdooError("give --task or --project")
    vals = timesheet_vals(args)
    vals.setdefault("date", datetime.date.today().isoformat())
    if args.task and not args.project:
        # Set it explicitly; the compute from task_id isn't relied on at create.
        vals["project_id"] = task_project(args.task)
    line_id = call("account.analytic.line", "create", vals_list=[vals])[0]
    emit(args, {"id": line_id},
         lambda: print(f"logged {fmt_hours(vals['unit_amount'])} on {vals['date']} (line #{line_id})"))


def cmd_timesheet_update(args):
    vals = timesheet_vals(args)
    if not vals:
        raise OdooError("nothing to update")
    write("account.analytic.line", [args.line], vals)
    emit(args, {"id": args.line, "vals": vals}, lambda: print(f"updated timesheet line #{args.line}"))


def cmd_timesheet_delete(args):
    call("account.analytic.line", "unlink", ids=[args.line])
    emit(args, {"id": args.line}, lambda: print(f"deleted timesheet line #{args.line}"))


# --- worklog: raw material for timesheets ----------------------------------

CLAUDE_PROJECTS = Path.home() / ".claude" / "projects"
# Idle longer than IDLE_GAP ends a block of work; each block gets IDLE_TAIL
# extra for the reading/thinking after its last event.
IDLE_GAP = datetime.timedelta(minutes=20)
IDLE_TAIL = datetime.timedelta(minutes=5)


def active_blocks(times):
    times = sorted(times)
    blocks, start, prev = [], times[0], times[0]
    for t in times[1:]:
        if t - prev > IDLE_GAP:
            blocks.append((start, prev + IDLE_TAIL))
            start = t
        prev = t
    blocks.append((start, prev + IDLE_TAIL))
    return blocks


def blocks_hours(blocks):
    return sum((b - a).total_seconds() for a, b in blocks) / 3600


def fmt_blocks(blocks):
    return ", ".join(f"{a:%H:%M}-{b:%H:%M}" for a, b in blocks)


def message_text(d):
    content = (d.get("message") or {}).get("content")
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        return " ".join(c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text").strip()
    return ""


def claude_sessions(day):
    sessions = []
    for f in CLAUDE_PROJECTS.glob("*/*.jsonl"):
        if datetime.date.fromtimestamp(f.stat().st_mtime) < day:
            continue
        cwd, times, prompts = None, [], []
        with open(f, errors="replace") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(d, dict) or not d.get("timestamp") or d.get("isSidechain"):
                    continue
                t = datetime.datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00")).astimezone()
                if t.date() != day:
                    continue
                cwd = d.get("cwd") or cwd
                times.append(t)
                if d.get("type") == "user" and (d.get("origin") or {}).get("kind") == "human":
                    text = message_text(d)
                    # Skip harness-injected text (command caveats, reminders).
                    if text and not text.startswith("<"):
                        prompts.append((t, " ".join(text.split())[:300]))
        if times and cwd:
            sessions.append({"id": f.stem[:8], "cwd": cwd, "times": times, "prompts": prompts})
    return sessions


def git(repo, *argv):
    try:
        return subprocess.run(["git", "-C", str(repo), *argv], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def git_commits(repo, day):
    argv = ["log", "--all", "--no-merges", f"--since={day} 00:00", f"--until={day} 23:59:59",
            "--date=format-local:%H:%M", "--format=%ad%x09%h%x09%s"]
    email = git(repo, "config", "user.email").strip()
    if email:
        argv.append(f"--author={email}")
    rows = [line.split("\t", 2) for line in git(repo, *argv).splitlines()]
    return sorted(({"time": r[0], "hash": r[1], "subject": r[2]} for r in rows if len(r) == 3),
                  key=lambda c: c["time"])


def repo_roots(roots):
    found = set()
    for root in roots:
        root = Path(root).expanduser()
        for pattern in (".git", "*/.git", "*/*/.git"):
            found.update(str(g.parent) for g in root.glob(pattern))
    return found


def short_path(path):
    home = str(Path.home())
    return "~" + path[len(home):] if path.startswith(home) else path


def cmd_worklog(args):
    day = args.date
    sessions = claude_sessions(day)
    toplevel = {}
    for cwd in {s["cwd"] for s in sessions}:
        toplevel[cwd] = git(cwd, "rev-parse", "--show-toplevel").strip() or cwd
    repos = {}
    for s in sessions:
        repos.setdefault(toplevel[s["cwd"]], {"sessions": [], "commits": []})["sessions"].append(s)
    for path in repo_roots(args.root) | set(repos):
        commits = git_commits(path, day)
        if commits:
            repos.setdefault(path, {"sessions": [], "commits": []})["commits"] = commits

    all_times = [t for s in sessions for t in s["times"]]
    total = active_blocks(all_times) if all_times else []
    data = {"date": day.isoformat(), "timezone": datetime.datetime.now().astimezone().tzname(),
            "active_hours": round(blocks_hours(total), 2), "blocks": fmt_blocks(total), "repos": []}
    for path, r in sorted(repos.items()):
        times = [t for s in r["sessions"] for t in s["times"]]
        blocks = active_blocks(times) if times else []
        data["repos"].append({
            "path": short_path(path),
            "active_hours": round(blocks_hours(blocks), 2),
            "blocks": fmt_blocks(blocks),
            "sessions": [{
                "id": s["id"],
                "active_hours": round(blocks_hours(active_blocks(s["times"])), 2),
                "blocks": fmt_blocks(active_blocks(s["times"])),
                "prompts": [{"time": f"{t:%H:%M}", "text": p} for t, p in s["prompts"]],
            } for s in sorted(r["sessions"], key=lambda s: min(s["times"]))],
            "commits": r["commits"],
        })

    def render():
        print(f"{data['date']} ({data['timezone']})  active {fmt_hours(data['active_hours'])}  {data['blocks']}")
        print("Hours are wall-clock: parallel sessions in a repo are merged, not added.")
        for r in data["repos"]:
            print(f"\n== {r['path']}  {fmt_hours(r['active_hours'])}  {r['blocks']}")
            for s in r["sessions"]:
                print(f"  session {s['id']}  {fmt_hours(s['active_hours'])}  {s['blocks']}")
                for p in s["prompts"]:
                    print(f"    {p['time']} {p['text'][:160]}")
            if r["commits"]:
                print("  commits:")
                for c in r["commits"]:
                    print(f"    {c['time']} {c['hash']} {c['subject']}")
    emit(args, data, render)


# --- key rotation ------------------------------------------------------------

def cmd_key_status(args):
    keys = search_read(
        "res.users.apikeys", [["user_id", "=", current_uid()]],
        ["name", "scope", "create_date", "expiration_date"], order="create_date desc",
    )
    state = load_state()
    data = {"keys": keys, "state": state}

    def render():
        for k in keys:
            print(f"#{k['id']} {k['name']!r} scope={k['scope'] or 'global'} "
                  f"created={k['create_date'][:10]} expires={(k['expiration_date'] or 'never')[:10]}")
        if state:
            days = (datetime.date.fromisoformat(state["expires"]) - datetime.date.today()).days
            print(f"\nkey in wallet (prefix {state['prefix']}) expires {state['expires']} ({days} days)")
        else:
            print("\nexpiry of the key in the wallet is unknown (not created by rotate-key)")
    emit(args, data, render)


def cmd_rotate_key(args):
    old = get_key()
    state = load_state()
    today = datetime.date.today()
    # The expiry is only known for keys this tool created; a key put in the
    # wallet by hand (different prefix) is rotated right away so it becomes known.
    if args.if_needed and state.get("prefix") == old[:8]:
        days_left = (datetime.date.fromisoformat(state["expires"]) - today).days
        if days_left > args.threshold:
            print(f"key expires {state['expires']} ({days_left} days), no rotation needed")
            return
    expires = (today + datetime.timedelta(days=args.days)).isoformat()
    name = f"odoo-kanban {socket.gethostname()} {today.isoformat()}"
    new = call(
        "res.users.apikeys", "generate", auth=old,
        key=old, scope=None, name=name, expiration_date=expires,
    )
    try:
        call("res.users", "context_get", auth=new)
        wallet_write(new)
    except Exception:
        # Don't leave an orphaned live key behind if it couldn't be stored.
        call("res.users.apikeys", "revoke", auth=old, key=new)
        raise
    save_state({"prefix": new[:8], "expires": expires, "rotated": today.isoformat()})
    try:
        call("res.users.apikeys", "revoke", auth=new, key=old)
    except OdooError as e:
        print(f"warning: new key stored, but revoking the old one failed: {e}", file=sys.stderr)
    print(f"rotated API key: new key {new[:8]}… expires {expires}")


# --- CLI ---------------------------------------------------------------------

def task_edit_args(p):
    p.add_argument("--name", help="task title")
    p.add_argument("--description", help="plain text; blank lines separate paragraphs")
    p.add_argument("--stage", help="stage id or name (within the task's project)")
    p.add_argument("--assign", nargs="*", metavar="USER",
                   help="set assignees (replaces existing): 'me', login/email, name or id")
    p.add_argument("--tag", action="append", metavar="TAG", help="add a tag (repeatable)")
    p.add_argument("--priority", choices=PRIORITY_NAMES)
    p.add_argument("--deadline", metavar="YYYY-MM-DD", help="'' clears it")
    p.add_argument("--state", choices=STATES)
    p.add_argument("--milestone", help="milestone id or name in the task's project; '' clears it")
    p.add_argument("--parent", type=parent_ref, metavar="TASK_ID",
                   help="make it a sub-task of this task; '' makes it top-level")
    p.add_argument("--hours", type=parse_hours, help="estimate (allocated hours): 4, 1.5 or 1:30")
    p.add_argument("--blocked-by", type=int, action="append", metavar="TASK_ID",
                   help="this task can't proceed until TASK_ID is done (repeatable)")
    p.add_argument("--blocks", type=int, action="append", metavar="TASK_ID",
                   help="TASK_ID can't proceed until this task is done (repeatable)")


def build_parser():
    ap = argparse.ArgumentParser(
        prog="odoo-kanban",
        description=f"Odoo project kanban boards on {URL}. Projects, stages, users and "
                    "tags accept an id or a unique (case-insensitive) name.",
    )
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("whoami", help="check the key works").set_defaults(fn=cmd_whoami)

    p = sub.add_parser("projects", help="list projects (boards)")
    p.add_argument("--favorites", action="store_true")
    p.set_defaults(fn=cmd_projects)

    p = sub.add_parser("stages", help="list a project's columns")
    p.add_argument("project")
    p.set_defaults(fn=cmd_stages)

    filters = argparse.ArgumentParser(add_help=False)
    filters.add_argument("--mine", action="store_true", help="only tasks assigned to me")
    filters.add_argument("--assignee", help="only tasks assigned to this user")
    filters.add_argument("--tag", help="only tasks with this tag")
    filters.add_argument("--search", help="text in name or description")
    filters.add_argument("--milestone", help="only tasks in this milestone")
    filters.add_argument("--ready", action="store_true", help="only open tasks with no open blockers")
    filters.add_argument("--closed", action="store_true", help="include done/cancelled tasks")

    p = sub.add_parser("board", parents=[filters], help="show a project as kanban columns")
    p.add_argument("project")
    p.add_argument("--folded", action="store_true", help="include empty folded columns")
    p.set_defaults(fn=cmd_board)

    p = sub.add_parser("tasks", parents=[filters], help="flat task list, across projects by default")
    p.add_argument("--project")
    p.add_argument("--stage")
    p.add_argument("--limit", type=int, default=50)
    p.set_defaults(fn=cmd_tasks)

    p = sub.add_parser("show", help="task details, description and recent messages")
    p.add_argument("task", type=int)
    p.add_argument("--messages", type=int, default=10, metavar="N", help="0 to skip")
    p.set_defaults(fn=cmd_show)

    p = sub.add_parser("create", help="create a task")
    p.add_argument("--project", help="defaults to the --parent task's project")
    p.add_argument("--from", dest="from_file", metavar="FILE",
                   help="create several tasks from a YAML file (see the skill doc for the format)")
    p.add_argument("--dry-run", action="store_true", help="with --from: resolve and show, create nothing")
    task_edit_args(p)
    p.set_defaults(fn=cmd_create)

    p = sub.add_parser("update", help="edit a task")
    p.add_argument("task", type=int)
    task_edit_args(p)
    p.add_argument("--project", help="move the task to another project")
    p.add_argument("--add-assignee", action="append", metavar="USER")
    p.add_argument("--unassign", action="append", metavar="USER")
    p.add_argument("--untag", action="append", metavar="TAG")
    p.add_argument("--unblock", type=int, action="append", metavar="TASK_ID",
                   help="remove TASK_ID from what blocks this task")
    p.add_argument("--unblocks", type=int, action="append", metavar="TASK_ID",
                   help="stop this task blocking TASK_ID")
    p.set_defaults(fn=cmd_update)

    p = sub.add_parser("move", help="move a task to another column")
    p.add_argument("task", type=int)
    p.add_argument("stage")
    p.set_defaults(fn=cmd_move)

    p = sub.add_parser("project-settings", help="show or switch a project's milestones/dependencies")
    p.add_argument("project")
    p.add_argument("--milestones", choices=["on", "off"])
    p.add_argument("--dependencies", choices=["on", "off"])
    p.set_defaults(fn=cmd_project_settings)

    p = sub.add_parser("milestones", help="list a project's milestones")
    p.add_argument("project")
    p.add_argument("--reached", action="store_true", help="include reached milestones")
    p.set_defaults(fn=cmd_milestones)

    p = sub.add_parser("create-milestone", help="add a milestone to a project")
    p.add_argument("project")
    p.add_argument("name")
    p.add_argument("--deadline", metavar="YYYY-MM-DD")
    p.set_defaults(fn=cmd_create_milestone)

    p = sub.add_parser("update-milestone", help="edit a milestone")
    p.add_argument("milestone", type=int)
    p.add_argument("--name")
    p.add_argument("--deadline", metavar="YYYY-MM-DD", help="'' clears it")
    p.add_argument("--reached", action="store_true", default=None)
    p.add_argument("--unreached", dest="reached", action="store_false")
    p.set_defaults(fn=cmd_update_milestone)

    p = sub.add_parser("comment", help="post on a task's chatter (internal note by default)")
    p.add_argument("task", type=int)
    p.add_argument("text")
    p.add_argument("--send", action="store_true", help="send as a message to followers instead")
    p.set_defaults(fn=cmd_comment)

    p = sub.add_parser("tags", help="list tags (shared by all projects)")
    p.add_argument("--project", help="only tags used on this project's tasks")
    p.add_argument("--search")
    p.set_defaults(fn=cmd_tags)

    p = sub.add_parser("create-tag", help="create a tag")
    p.add_argument("name")
    p.add_argument("--color", type=parse_color, help="0-11 or " + "/".join(TAG_COLORS))
    p.set_defaults(fn=cmd_create_tag)

    p = sub.add_parser("update-tag", help="rename or recolor a tag")
    p.add_argument("tag")
    p.add_argument("--name")
    p.add_argument("--color", type=parse_color)
    p.set_defaults(fn=cmd_update_tag)

    p = sub.add_parser("delete-tag", help="delete a tag everywhere")
    p.add_argument("tag")
    p.set_defaults(fn=cmd_delete_tag)

    ts = sub.add_parser("timesheet", help="list and log timesheet hours").add_subparsers(dest="ts_cmd", required=True)

    p = ts.add_parser("list", help="my timesheet lines, this week by default")
    p.add_argument("--day", type=parse_date, help="a single day")
    p.add_argument("--from", dest="start", type=parse_date)
    p.add_argument("--to", dest="end", type=parse_date)
    p.add_argument("--last-week", action="store_true")
    p.add_argument("--user", help="someone else's lines (needs rights)")
    p.add_argument("--project")
    p.add_argument("--task", type=int)
    p.set_defaults(fn=cmd_timesheet_list)

    def line_args(p, creating):
        p.add_argument("--task", type=int, help="task id (sets the project too)")
        p.add_argument("--project", help="project, when not logging against a task")
        p.add_argument("--hours", type=parse_hours, required=creating, help="1.5, 1:30 or 90m")
        p.add_argument("--description", required=creating)
        p.add_argument("--date", type=parse_date, help="YYYY-MM-DD, today (default) or yesterday")

    p = ts.add_parser("log", help="add a timesheet line")
    line_args(p, creating=True)
    p.set_defaults(fn=cmd_timesheet_log)

    p = ts.add_parser("update", help="edit a timesheet line")
    p.add_argument("line", type=int)
    line_args(p, creating=False)
    p.set_defaults(fn=cmd_timesheet_update)

    p = ts.add_parser("delete", help="delete a timesheet line")
    p.add_argument("line", type=int)
    p.set_defaults(fn=cmd_timesheet_delete)

    p = sub.add_parser("worklog", help="a day's Claude sessions and git commits, for drafting timesheets")
    p.add_argument("date", nargs="?", type=parse_date, default=datetime.date.today(),
                   help="YYYY-MM-DD, today (default) or yesterday")
    p.add_argument("--root", action="append", default=["~/Code", "~/nixos-config"],
                   help="where to look for git repos with commits (repeatable)")
    p.set_defaults(fn=cmd_worklog)

    sub.add_parser("key-status", help="list my API keys and their expiry").set_defaults(fn=cmd_key_status)

    p = sub.add_parser("rotate-key", help="replace the stored API key with a fresh one")
    p.add_argument("--if-needed", action="store_true",
                   help="only rotate when the stored key is within --threshold days of expiry")
    p.add_argument("--threshold", type=int, default=30)
    p.add_argument("--days", type=int, default=90, help="lifetime of the new key")
    p.set_defaults(fn=cmd_rotate_key)
    return ap


def main():
    args = build_parser().parse_args()
    try:
        args.fn(args)
    except OdooError as e:
        print(f"odoo-kanban: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
