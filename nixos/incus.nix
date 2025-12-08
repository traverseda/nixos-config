{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:

let
  pam_proxy_helper = pkgs.rustPlatform.buildRustPackage rec {
    pname = "pam_proxy_helper";
    version = "0.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "mfrischknecht";
      repo = "pam_proxy_helper";
      rev = "versions/${version}";
      hash = "sha256-yRFsxUx0TUYYJo1HQlcJ7VI5YLmkduyY0SLQgDXUQ7I=";
    };

    cargoHash = "sha256-SEN+IHlu5b21khqj3L5RtBGQ3wPMqofDLEGpKQ8/6Sk=";

    buildInputs = [ pkgs.pam ];
    nativeBuildInputs = [ pkgs.rustPlatform.bindgenHook ];
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

    meta = {
      license = lib.licenses.agpl3Only;
      homepage = "https://github.com/mfrischknecht/pam_proxy_helper";
      description = "A proxy helper to run PAM auth requests through pam_exec";
    };
  };
in
{
  networking.firewall.enable = false;

  users.users.traverseda = {
    extraGroups = [ "incus-admin" "incus-users" ];
  };

  users.groups.incus-users = {};

  virtualisation.incus = {
    enable = true;
    ui.enable = true;  # Enable the web UI
    preseed = {
      config = {
        "core.https_address" = "127.0.0.1:8443";
      };
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.0.100.1/24";
            "ipv4.nat" = "true";
          };
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];
      storage_pools = [
        {
          name = "default";
          driver = "dir";
        }
      ];
    };
  };

  systemd.services.incus-proxy-cert = {
    description = "Generate Incus proxy client certificate";
    wantedBy = [ "multi-user.target" ];
    after = [ "incus.service" ];
    before = [ "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/incus-proxy-certs

      # Wait for Incus to be ready
      for i in {1..30}; do
        if ${pkgs.incus}/bin/incus info >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      if [ ! -f /var/lib/incus-proxy-certs/client.crt ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
          -keyout /var/lib/incus-proxy-certs/client.key \
          -out /var/lib/incus-proxy-certs/client.crt \
          -days 3650 -nodes \
          -subj "/CN=incus-proxy"

        ${pkgs.incus}/bin/incus config trust add-certificate /var/lib/incus-proxy-certs/client.crt --name incus-proxy
      fi

      chown nginx:nginx /var/lib/incus-proxy-certs/client.crt
      chown nginx:nginx /var/lib/incus-proxy-certs/client.key
      chmod 600 /var/lib/incus-proxy-certs/client.crt
      chmod 600 /var/lib/incus-proxy-certs/client.key
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/incus-proxy-certs 0700 nginx nginx - -"
  ];

  security.wrappers.pam_proxy_helper = {
    owner = "root";
    group = "shadow";
    setuid = true;
    setgid = true;
    source = "${pam_proxy_helper}/bin/pam_proxy_helper";
  };

  security.pam.services = {
    nginx_proxy = {
      setEnvironment = false;
      text = ''
        auth required pam_exec.so expose_authtok ${config.security.wrapperDir}/pam_proxy_helper nginx_target
        account required pam_permit.so
        session required pam_permit.so
      '';
    };

    nginx_target = {
      setEnvironment = false;
      text = ''
        auth required pam_unix.so
        account required pam_unix.so
        session required pam_permit.so
      '';
    };
  };

  services.nginx = {
    enable = true;
    additionalModules = [ pkgs.nginxModules.pam ];
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."incus.${hostname}" = {
      locations."/" = {
        proxyPass = "https://127.0.0.1:8443";
        proxyWebsockets = true;

        extraConfig = ''
          auth_pam "Incus Authentication";
          auth_pam_service_name "nginx_proxy";

          proxy_ssl_certificate /var/lib/incus-proxy-certs/client.crt;
          proxy_ssl_certificate_key /var/lib/incus-proxy-certs/client.key;
          proxy_ssl_verify off;
          proxy_ssl_server_name on;
        '';
      };
    };
  };

  systemd.services.nginx = {
    after = [ "incus-proxy-cert.service" ];
    wants = [ "incus-proxy-cert.service" ];
    serviceConfig = {
      NoNewPrivileges = lib.mkForce false;
      CapabilityBoundingSet = [ "CAP_SETUID" "CAP_NET_BIND_SERVICE" ];
      SystemCallFilter = [ "setuid" "setgid" "capset" ];
      ProtectSystem = lib.mkForce false;
      ReadWritePaths = [ "/var/lib/incus-proxy-certs" ];
    };
  };
}
