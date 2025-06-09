{
  buildGhidraExtension,
  fetchFromGitHub,
  fetchpatch,
  lib,
}:
buildGhidraExtension rec {
  pname = "efiseek";
  version = "2022-04-26";

  src = fetchFromGitHub {
    owner = "DSecurity";
    repo = "efiSeek";
    rev = "573f4b9b5ba2731cdecafc6594d0fd0570e28fff";
    hash = "sha256-CJl2eNwisjxh+PEWXlVimjmCYfXoWXJu/FX4gy9qxGw=";
  };

  patches = [
    # Updated gradle version and subsequent file fixes for Ghidra 11.2
    (fetchpatch {
      url = "https://github.com/DSecurity/efiSeek/pull/16.patch";
      hash = "sha256-peOgoW1lObD9CLttnbQlbFGRaqRnj8HclsvPh7lFkTg=";
    })
  ];

  meta = {
    description = "Ghidra analyzer for UEFI firmware";
    homepage = "https://github.com/DSecurity/efiSeek";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ timschumi ];
  };
}
