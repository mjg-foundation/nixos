{ lib, pkgs, ... }:

let
  ibroadcast = pkgs.stdenv.mkDerivation {
    pname = "ibroadcast";
    version = "1.0.0";

    src = ./ibroadcast-1.0.0.x86_64.rpm;

    unpackPhase = ''
      runHook preUnpack
      rpmextract "$src"
      runHook postUnpack
    '';

    nativeBuildInputs = with pkgs; [
      rpmextract
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      stdenv.cc.cc.lib
      systemd
      zlib
    ];

    runtimeDependencies = [ (lib.getLib pkgs.systemd) ];
    dontWrapGApps = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib" "$out/bin" "$out/share"
      cp -r opt/iBroadcast "$out/lib/ibroadcast"
      cp -r usr/share/applications usr/share/icons "$out/share/"
      substituteInPlace "$out/share/applications/ibroadcast.desktop" \
        --replace-fail /opt/iBroadcast/ibroadcast "$out/bin/ibroadcast"

      runHook postInstall
    '';

    preFixup = ''
      makeWrapper "$out/lib/ibroadcast/ibroadcast.bin" "$out/bin/ibroadcast" \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libGL ]}" \
        --prefix PATH : "${lib.makeBinPath [ pkgs.xdg-utils ]}"
    '';

    meta = {
      description = "iBroadcast music player and uploader";
      homepage = "https://www.ibroadcast.com";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = "ibroadcast";
    };
  };
in
{
  home.packages = [ ibroadcast ];
}
