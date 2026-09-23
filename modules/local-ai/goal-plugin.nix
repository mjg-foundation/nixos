{ pkgs }:
let
  source = pkgs.fetchurl {
    url = "https://registry.npmjs.org/opencode-goal-plugin/-/opencode-goal-plugin-0.10.0.tgz";
    hash = "sha512-PQ3AgNQcVwdEnoQzDz42NVtov1yKbxOKlrnLdKXOykP0+0OV6eXSUSxKuyjVFVItbbWzoNTc2XjWIsIKF+F4AA==";
  };
  zod = pkgs.fetchurl {
    url = "https://registry.npmjs.org/zod/-/zod-4.5.4.tgz";
    hash = "sha512-sC95tT5iHHH9gtpj6A81kh+NEaRAUFN+qlUPDUbRfOMvNf5QCBqsb3WgvnpVtK5Y+4UfA6KqufotuTvMGiTlsA==";
  };
in pkgs.runCommand "opencode-goal-plugin-0.10.0" {} ''
  mkdir -p "$out/node_modules/zod"
  tar -xzf ${source} --strip-components=1 -C "$out"
  tar -xzf ${zod} --strip-components=1 -C "$out/node_modules/zod"
''
