{
  description = "A Nix flake for the Helium browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    utils,
  }:
    utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        versionData = builtins.fromJSON (builtins.readFile ./versions.json);

        versions = versionData.versions;
        srcs = versionData.srcs;

        version = versions.linux;

        linuxWrapperArgs = [
          "--prefix"
          "LD_LIBRARY_PATH"
          ":"
          "${pkgs.lib.makeLibraryPath (with pkgs; [
            libGL
            libvdpau
            libva
            pipewire
            alsa-lib
            libpulseaudio
          ])}"
          "--add-flags"
          "--ozone-platform-hint=auto"
          "--add-flags"
          "--enable-features=WaylandWindowDecorations"
          "--add-flags"
          "--disable-component-update"
          "--add-flags"
          "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"
          "--add-flags"
          "--check-for-update-interval=0"
          "--add-flags"
          "--disable-background-networking"
        ];

        helium = pkgs.stdenv.mkDerivation {
          pname = "helium";
          inherit version;

          src = pkgs.fetchurl (srcs.${system} or (throw "Unsupported system: ${system}"));

          nativeBuildInputs = with pkgs;
            [
              makeWrapper
            ]
            ++ [
              autoPatchelfHook
              copyDesktopItems
            ];

          buildInputs = with pkgs;
            [
              alsa-lib
              at-spi2-atk
              at-spi2-core
              atk
              cairo
              cups
              dbus
              expat
              fontconfig
              freetype
              gdk-pixbuf
              glib
              gtk3
              libGL
              libx11
              libxscrnsaver
              libxcomposite
              libxcursor
              libxdamage
              libxext
              libxfixes
              libxi
              libxrandr
              libxrender
              libxtst
              libdrm
              libgbm
              libpulseaudio
              libxcb
              libxkbcommon
              mesa
              nspr
              nss
              pango
              pipewire
              systemd
              vulkan-loader
              wayland
              libxshmfence
              libuuid
              kdePackages.qtbase
            ];

          autoPatchelfIgnoreMissingDeps = [
            "libQt6Core.so.6"
            "libQt6Gui.so.6"
            "libQt6Widgets.so.6"
            "libQt5Core.so.5"
            "libQt5Gui.so.5"
            "libQt5Widgets.so.5"
          ];

          dontWrapQtApps = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin $out/opt/helium
            cp -r * $out/opt/helium
            cp -a ${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm $out/opt/helium/

            printf '%s\n' \
              '#!${pkgs.runtimeShell}' \
              'set -euo pipefail' \
              'widevine_dir="''${XDG_CONFIG_HOME:-''$HOME/.config}/net.imput.helium/WidevineCdm"' \
              'mkdir -p "$widevine_dir"' \
              "printf '{\"Path\":\"%s\"}' '$out/opt/helium/WidevineCdm' > \"\$widevine_dir/latest-component-updated-widevine-cdm\"" \
              > $out/opt/helium/setup-widevine
            chmod +x $out/opt/helium/setup-widevine

            # The binary is named 'helium' as of version 0.8.3.1
            makeWrapper $out/opt/helium/helium $out/bin/helium \
              ${pkgs.lib.escapeShellArgs linuxWrapperArgs} \
              --run "$out/opt/helium/setup-widevine"

            # Install icon
            mkdir -p $out/share/icons/hicolor/256x256/apps
            cp $out/opt/helium/product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

            runHook postInstall
          '';

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "helium";
              exec = "helium %U";
              icon = "helium";
              desktopName = "Helium";
              genericName = "Web Browser";
              categories = ["Network" "WebBrowser"];
              terminal = false;
              mimeTypes = ["text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https"];
            })
          ];

          meta = with pkgs.lib; {
            description = "Private, fast, and honest web browser based on ungoogled-chromium";
            homepage = "https://helium.computer/";
            license = licenses.gpl3Only;
            platforms = ["x86_64-linux" "aarch64-linux"];
            mainProgram = "helium";
          };
        };

        app = {
          type = "app";
          program = "${helium}/bin/helium";
          meta = {
            inherit (helium.meta) description homepage license platforms;
          };
        };
      in {
        packages.default = helium;
        packages.helium = helium;

        apps.default = app;
        apps.helium = app;

        devShells.default = pkgs.mkShell {
          buildInputs = [
            helium
            pkgs.jq
          ];
        };
      }
    );
}
