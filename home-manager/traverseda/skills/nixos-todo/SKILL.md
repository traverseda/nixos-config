---
name: nixos-todo
description: Request an OS-level change (system package, service, kernel/driver, permissions, firewall, etc.) that you can't make yourself. Use when a task is blocked on something that needs a NixOS config change or sudo.
---

# Requesting OS-level changes

The system is managed declaratively from `~/nixos-config` and you can't apply
changes (no `sudo`). Don't edit the NixOS config from another project's session.
Instead, append an entry to `~/nixos-config/TODO.md` (create it if missing):

```markdown
- [ ] <what's needed, e.g. "install `ffmpeg` system-wide">
  - Why: <what you were doing and how it's blocked>
  - From: <project path>, <date>
```

Append only — never rewrite or remove existing entries. Then tell the user what
you added and carry on with a workaround if one exists (e.g. `nix shell nixpkgs#foo`).
