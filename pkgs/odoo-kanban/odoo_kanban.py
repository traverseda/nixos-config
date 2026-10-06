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
STATES = {
    "in_progress": "01_in_progress",
    "changes_requested": "02_changes_requested",
    "approved": "03_approved",
    "done": "1_done",
    "canceled": "1_canceled",
}
TASK_LIST_FIELDS = [
    "name", "project_id", "stage_id", "user_ids", "tag_ids",
    "priority", "state", "date_deadline", "parent_id",
]


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


# --- formatting --------------------------------------------------------------

def html_to_text(value):
    if not value:
        return ""
    text = re.sub(r"(?i)<br\s*/?>|</(p|div|li|h[1-6]|tr)>", "\n", value)
    text = re.sub(r"(?i)<li[^>]*>", "- ", text)
    text = html.unescape(re.sub(r"<[^>]+>", "", text))
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def text_to_html(value):
    paras = [p for p in re.split(r"\n\s*\n", value.strip()) if p]
    return "".join(f"<p>{html.escape(p).replace(chr(10), '<br>')}</p>" for p in paras)


def m2o(value):
    return value[1] if isinstance(value, list) else ""


def task_line(t, users, tags, show_stage=False):
    parts = [f"#{t['id']}"]
    if PRIORITIES.get(t["priority"]):
        parts.append(PRIORITIES[t["priority"]])
    parts.append(t["name"])
    if t["state"] in ("1_done", "1_canceled"):
        parts.append(f"[{t['state'][2:]}]")
    if show_stage and t["stage_id"]:
        parts.append(f"<{m2o(t['stage_id'])}>")
    if t["user_ids"]:
        parts.append("— " + ", ".join(users.get(u, str(u)) for u in t["user_ids"]))
    if t["tag_ids"]:
        parts.append("{" + ", ".join(tags.get(g, str(g)) for g in t["tag_ids"]) + "}")
    if t["date_deadline"]:
        parts.append(f"due {t['date_deadline'][:10]}")
    if t["parent_id"]:
        parts.append(f"(sub of #{t['parent_id'][0]})")
    return " ".join(parts)


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
                print("  " + task_line(t, users, tags))
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

    def render():
        users, tags = related_names(tasks)
        for t in tasks:
            prefix = "" if project_id else f"[{m2o(t['project_id']) or 'private'}] "
            print(prefix + task_line(t, users, tags, show_stage=True))
    emit(args, tasks, render)


def cmd_show(args):
    fields = TASK_LIST_FIELDS + ["description", "child_ids", "create_date", "write_date"]
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

    def render():
        users, tags = related_names([task])
        print(task_line(task, users, tags))
        print(f"Project: {m2o(task['project_id']) or 'private'}   Stage: {m2o(task['stage_id'])}   State: {task['state']}")
        print(f"Created: {task['create_date']}   Updated: {task['write_date']}")
        if task["child_ids"]:
            print("Sub-tasks: " + ", ".join(f"#{c}" for c in task["child_ids"]))
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
    return vals


def cmd_create(args):
    project_id = resolve_project(args.project)
    vals = task_vals(args, project_id)
    vals["project_id"] = project_id
    if args.parent:
        vals["parent_id"] = args.parent
    if args.assign is None:
        # Odoo would otherwise assign the creator; leave unassigned unless asked.
        vals["user_ids"] = [[6, 0, []]]
    task_id = call("project.task", "create", vals_list=[vals])[0]
    emit(args, {"id": task_id}, lambda: print(f"created task #{task_id}"))


def task_project(task_id):
    rows = call("project.task", "read", ids=[task_id], fields=["project_id"])
    if not rows:
        raise OdooError(f"no task #{task_id}")
    return rows[0]["project_id"][0] if rows[0]["project_id"] else None


def cmd_update(args):
    project_id = task_project(args.task) if args.stage else None
    vals = task_vals(args, project_id)
    m2m = []
    for u in args.add_assignee or []:
        m2m.append([4, resolve_user(u)])
    for u in args.unassign or []:
        m2m.append([3, resolve_user(u)])
    if m2m:
        vals["user_ids"] = vals.get("user_ids", []) + m2m
    if args.untag:
        vals["tag_ids"] = vals.get("tag_ids", []) + [[3, resolve_tag(t)] for t in args.untag]
    if not vals:
        raise OdooError("nothing to update")
    call("project.task", "write", ids=[args.task], vals=vals)
    emit(args, {"id": args.task, "vals": vals}, lambda: print(f"updated task #{args.task}"))


def cmd_move(args):
    stage_id = resolve_stage(task_project(args.task), args.stage)
    call("project.task", "write", ids=[args.task], vals={"stage_id": stage_id})
    emit(args, {"id": args.task, "stage_id": stage_id},
         lambda: print(f"moved task #{args.task} to stage #{stage_id}"))


def cmd_comment(args):
    msg_id = call(
        "project.task", "message_post", ids=[args.task],
        body=text_to_html(args.text), body_is_html=True, message_type="comment",
        subtype_xmlid="mail.mt_comment" if args.send else "mail.mt_note",
    )
    kind = "message sent to followers" if args.send else "internal note"
    emit(args, {"id": msg_id[0]}, lambda: print(f"posted {kind} on task #{args.task}"))


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

def task_edit_args(p, creating):
    p.add_argument("--name", required=creating, help="task title")
    p.add_argument("--description", help="plain text; blank lines separate paragraphs")
    p.add_argument("--stage", help="stage id or name (within the task's project)")
    p.add_argument("--assign", nargs="*", metavar="USER",
                   help="set assignees (replaces existing): 'me', login/email, name or id")
    p.add_argument("--tag", action="append", metavar="TAG", help="add a tag (repeatable)")
    p.add_argument("--priority", choices=PRIORITY_NAMES)
    p.add_argument("--deadline", metavar="YYYY-MM-DD", help="'' clears it")
    p.add_argument("--state", choices=STATES)


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
    p.add_argument("--project", required=True)
    p.add_argument("--parent", type=int, help="make it a sub-task of this task id")
    task_edit_args(p, creating=True)
    p.set_defaults(fn=cmd_create)

    p = sub.add_parser("update", help="edit a task")
    p.add_argument("task", type=int)
    task_edit_args(p, creating=False)
    p.add_argument("--add-assignee", action="append", metavar="USER")
    p.add_argument("--unassign", action="append", metavar="USER")
    p.add_argument("--untag", action="append", metavar="TAG")
    p.set_defaults(fn=cmd_update)

    p = sub.add_parser("move", help="move a task to another column")
    p.add_argument("task", type=int)
    p.add_argument("stage")
    p.set_defaults(fn=cmd_move)

    p = sub.add_parser("comment", help="post on a task's chatter (internal note by default)")
    p.add_argument("task", type=int)
    p.add_argument("text")
    p.add_argument("--send", action="store_true", help="send as a message to followers instead")
    p.set_defaults(fn=cmd_comment)

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
