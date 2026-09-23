{ lib, pkgs, osConfig, ... }:
let
  performanceHost = osConfig.networking.hostName == "framework";
  models = import ./models.nix { inherit pkgs; };
  goalPlugin = import ./goal-plugin.nix { inherit pkgs; };
  profiles = {
    eco = {
      model = "${models.eco}";
      name = "Qwen3.5 4B · Eco";
      server = "${pkgs.llama-cpp}/bin/llama-server";
      port = 8087;
      threads = 2;
      vision = true;
      extraArgs = [ "--device" "none" "--n-gpu-layers" "0" "--reasoning" "off"
        "--mmproj" "${models.ecoVision}" "--no-mmproj-offload" "--image-max-tokens" "1024" ];
    };
  } // lib.optionalAttrs performanceHost {
    performance = {
      model = "${models.performance}";
      name = "Qwen3 Coder 30B-A3B · AC performance";
      server = "${pkgs.llama-cpp-vulkan}/bin/llama-server";
      port = 8088;
      threads = 6;
      vision = false;
      # The 840M is a small integrated GPU. Keep the large expert tensors in
      # system RAM; accelerate attention/shared layers without a 19 GB GPU heap.
      extraArgs = [ "--n-gpu-layers" "99" "--cpu-moe" ];
    };
  };
  androidTools = pkgs.writeShellApplication {
    name = "local-android-tools";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./android-tools.py} "$@"
    '';
  };
  webTools = pkgs.writeShellApplication {
    name = "local-web-tools";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./web-tools.py} "$@"
    '';
  };
  settings = pkgs.writeText "local-code-settings.json" (builtins.toJSON {
    inherit profiles;
    goalPlugin = "file://${goalPlugin}/src/goal-plugin.js";
    statusPlugin = "file://${./status-plugin.mjs}";
    opencode = "${pkgs.opencode}/bin/opencode";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    tmux = "${pkgs.tmux}/bin/tmux";
    notify = "${pkgs.libnotify}/bin/notify-send";
    bwrap = "${pkgs.bubblewrap}/bin/bwrap";
    socat = "${pkgs.socat}/bin/socat";
    bash = "${pkgs.bash}/bin/bash";
    git = "${pkgs.git}/bin/git";
    python = "${pkgs.python3}/bin/python3";
    androidTools = "${androidTools}/bin/local-android-tools";
    webTools = "${webTools}/bin/local-web-tools";
    caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    # Language toolchains can also be supplied by entering nix develop first.
    toolPath = lib.makeBinPath (with pkgs; [
      bash coreutils findutils gnugrep gnused gawk git ripgrep
      gnumake gcc pkg-config python3
    ]);
  });
  launcher = pkgs.writeShellApplication {
    name = "local-code";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./local-code.py} ${settings} "$@"
    '';
  };
  mkService = profile: _: {
    Unit = {
      Description = "Local coding model (${profile})";
      # Prevent two models from competing for shared RAM.
      Conflicts = map (other: "local-ai-${other}.service")
        (lib.filter (other: other != profile) (builtins.attrNames profiles));
    };
    Service = {
      ExecStart = "${launcher}/bin/local-code _serve ${profile}";
      Environment = [ "OPENBLAS_NUM_THREADS=1" "OMP_NUM_THREADS=1" ];
      Restart = "no";
      TimeoutStopSec = 15;
      Nice = if profile == "eco" then 15 else 5;
      CPUWeight = if profile == "eco" then 10 else 50;
      CPUQuota = if profile == "eco" then "150%" else "600%";
      MemoryHigh = if profile == "eco" then "6G" else "24G";
      MemoryMax = if profile == "eco" then "8G" else "26G";
      MemorySwapMax = 0;
    };
    # Intentionally no WantedBy: load a model only when requested.
  };
in {
  home.packages = [ pkgs.opencode pkgs.tmux launcher androidTools ];
  systemd.user.services = lib.mapAttrs' (name: profile:
    lib.nameValuePair "local-ai-${name}" (mkService name profile)
  ) profiles;
}
