{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  writeScript,
  curl,
  jq,
  common-updater-scripts,
}:

# The raw package that fetches and extracts the Plex RPM. Override the source
# and version of this derivation if you want to use a Plex Pass version of the
# server, and the FHS userenv and corresponding NixOS module should
# automatically pick up the changes.
stdenv.mkDerivation rec {
  version = "1.41.9.9961-46083195d";
  pname = "plexmediaserver";

  # Fetch the source
  src =
    if stdenv.hostPlatform.system == "aarch64-linux" then
      fetchurl {
        url = "https://downloads.plex.tv/plex-media-server-new/${version}/debian/plexmediaserver_${version}_arm64.deb";
        sha256 = "1gxiwzv799w2b18mlq1yx5z3x9k51f88yc9k7mmcn5a224a11kxf";
      }
    else
      fetchurl {
        url = "https://downloads.plex.tv/plex-media-server-new/${version}/debian/plexmediaserver_${version}_amd64.deb";
        sha256 = "0hnwsh9x48xx9grgv4j30ymbr7v9bdfkl3dnfwjbqr0g3zb22av2";
      };

  outputs = [
    "out"
    "basedb"
  ];

  nativeBuildInputs = [ dpkg ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    cp -dr --no-preserve='ownership' usr/lib/plexmediaserver $out/lib/

    # Location of the initial Plex plugins database
    f=$out/lib/plexmediaserver/Resources/com.plexapp.plugins.library.db

    # Store the base database in the 'basedb' output
    cat $f > $basedb

    # Overwrite the base database in the Plex package with an absolute symlink
    # to the '/db' file; we create this path in the FHS userenv (see the "plex"
    # package).
    ln -fs /db $f
    runHook postInstall
  '';

  # We're running in a FHS userenv; don't patch anything
  dontPatchShebangs = true;
  dontStrip = true;
  dontPatchELF = true;
  dontAutoPatchelf = true;

  passthru.updateScript = writeScript "${pname}-updater" ''
    #!${stdenv.shell}
    set -eu -o pipefail
    PATH=${
      lib.makeBinPath [
        curl
        jq
        common-updater-scripts
      ]
    }:$PATH

    plexApiJson=$(curl -sS https://plex.tv/api/downloads/5.json)
    latestVersion="$(echo $plexApiJson | jq .computer.Linux.version | tr -d '"\n')"

    for platform in ${lib.concatStringsSep " " meta.platforms}; do
      arch=$(echo $platform | cut -d '-' -f1)
      dlUrl="$(echo $plexApiJson | jq --arg arch "$arch" -c '.computer.Linux.releases[] | select(.distro == "debian") | select(.build | contains($arch)) .url' | tr -d '"\n')"

      latestSha="$(nix-prefetch-url $dlUrl)"

      update-source-version plexRaw "$latestVersion" "$latestSha" --system=$platform --ignore-same-version
    done
  '';

  meta = with lib; {
    homepage = "https://plex.tv/";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = with maintainers; [
      badmutex
      forkk
      lnl7
      pjones
      thoughtpolice
      MayNiklas
    ];
    description = "Media library streaming server";
    longDescription = ''
      Plex is a media server which allows you to store your media and play it
      back across many different devices.
    '';
  };
}
