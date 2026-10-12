# TODO

- [ ] Open UDP 9875 (SAP announcements) and UDP 46000-46099 (RTP audio) in the firewall: `networking.firewall.allowedUDPPorts = [ 9875 ];` and `networking.firewall.allowedUDPPortRanges = [ { from = 46000; to = 46099; } ];`
  - Why: smart speakers announce their mics via SAP and stream RTP multicast; PipeWire's `libpipewire-module-rtp-sap` auto-creates input devices from them. Right now the firewall drops the packets, so nothing is discovered (verified: a local multicast listener on 224.0.0.56:9875 receives nothing).
  - Optional follow-up: load `libpipewire-module-rtp-sap` permanently via `services.pipewire.extraConfig.pipewire."60-rtp-sap"` (config in esphome_snippets README once it lands).
  - From: ~/Code/personal/esphome_snippets, 2026-10-10
- [ ] Install the `forking` skill for Claude Code: copy it from hermes.lan (`/var/lib/hermes/workspace/units/forking/SKILL.md`, a released Hermes unit) into `home-manager/traverseda/skills/forking/SKILL.md` and add `home.file.".claude/skills/forking/SKILL.md".source = ./skills/forking/SKILL.md;` next to nixos-todo's.
  - Why: our preferences for forking open-source projects (from Pinwheel), shared with Hermes.
  - From: ~/Code/personal/hermes-nixos, 2026-10-11
