{ stdenv
, lib
, fetchurl
, pkg-config
, makeWrapper
, gtk3
, libpulseaudio
, libdrm
, gpu-screen-recorder
, libglvnd
, wrapGAppsHook3
, wrapperDir ? "/run/wrappers/bin"
}:

stdenv.mkDerivation {
  pname = "gpu-screen-recorder-gtk";
  version = "3.2.5";

  src = fetchurl {
    url = "https://dec05eba.com/snapshot/gpu-screen-recorder-gtk.git.r175.cfd18af.tar.gz";
    hash = "sha256-HhZe22Hm9yGoy5WoyuP2+Wj8E3nMs4uf96mzmP6CMqU=";
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    libpulseaudio
    libdrm
  ];

  buildPhase = ''
    ./build.sh
  '';

  installPhase = let
    gpu-screen-recorder-wrapped = gpu-screen-recorder.override {
      inherit wrapperDir;
    };
  in ''
    install -Dt $out/bin/ gpu-screen-recorder-gtk
    install -Dt $out/share/applications/ gpu-screen-recorder-gtk.desktop

    gappsWrapperArgs+=(--prefix PATH : ${wrapperDir})
    gappsWrapperArgs+=(--suffix PATH : ${lib.makeBinPath [ gpu-screen-recorder-wrapped ]})
    # we also append /run/opengl-driver/lib as it otherwise fails to find libcuda.
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd ]}:/run/opengl-driver/lib)
  '';

  meta = with lib; {
    description = "GTK frontend for gpu-screen-recorder";
    mainProgram = "gpu-screen-recorder-gtk";
    homepage = "https://git.dec05eba.com/gpu-screen-recorder-gtk/about/";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ babbaj ];
    platforms = [ "x86_64-linux" ];
  };
}
