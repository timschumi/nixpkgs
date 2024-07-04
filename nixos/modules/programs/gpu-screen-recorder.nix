{ config, lib, pkgs, ... }:

let

  cfg = config.programs.gpu-screen-recorder;
  package = cfg.package.override {
    inherit (config.security) wrapperDir;
  };

in {
  options = {

    programs.gpu-screen-recorder = {
      package = lib.mkPackageOption pkgs "gpu-screen-recorder" {};

      wrapCapabilities = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Generate setcap wrappers.
        '';
      };
    };
  };

  config = lib.mkIf cfg.wrapCapabilities {
    security.wrappers."gsr-kms-server" = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+ep";
      source = "${package}/bin/gsr-kms-server";
    };
    security.wrappers."gpu-screen-recorder" = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_nice+ep";
      source = "${package}/bin/gpu-screen-recorder";
    };
  };

  meta.maintainers = with lib.maintainers; [ timschumi ];

}
