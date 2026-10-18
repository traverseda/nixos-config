{pkgs, ...}: {
  # expose-synq (share/mount/run a workspace over SpiriSynq) and spirisynq's
  # `synq` CLI. Packaged in pkgs/expose-synq and pkgs/spirisynq. `mount` needs
  # the setuid fusermount3 wrapper (programs.fuse, on by default).
  environment.systemPackages = [pkgs.expose-synq pkgs.spirisynq];
}
