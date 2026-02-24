{
  description = ''
    Development environment for barney — a multi-GPU/multi-node ANARI renderer
  '';

  nixConfig = {
    extra-substituters = [
      "https://dldt.cachix.org/"
    ];
    extra-trusted-public-keys = [
      "dldt.cachix.org-1:lF3I8Yijsqk+5+ZjH3QCLYrPvKadXpL41fsdIpM5Rss="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    anari-nix = {
      url = "github:dldt/anari-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      anari-nix,
      flake-utils,
      systems,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (nixpkgs) lib;

        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = system == "x86_64-linux" || system == "aarch64-linux";
          };
          overlays = [
            anari-nix.overlays.default
          ];
        };

        anariDevices =
          with pkgs;
          (lib.optionals pkgs.config.cudaSupport [
            barney
            visrtx
          ])
          ++ [
            anari-cycles
            anari-helide
            anari-helide-gpu
            anari-ospray
            anari-visionaray
            anari-vsr
          ];

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        devShells.default = pkgs.mkShell {
          src = builtins.filterSource (_path: type: type == "regular") ./.;
          hardeningDisable = [ "all" ];
          packages = with pkgs; [
            cmakeCurses
            haystack
            jq
            vela
            mage
            go
            anari-cts
            anari-cat
            anari-sdk
          ];

          buildInputs = with pkgs; [
            lua54Packages.luafilesystem
            embree
            mpich
            # For haystack
            vtk
          ];

          nativeBuildInputs = with pkgs; [
            gdb
            lldb
            ninja
            cmakeCurses
            valgrind
            watchexec
            clang
            clang-tools
            mdl-sdk
          ];

          inputsFrom = with pkgs; [
            barney
            barney
            haystack
            visrtx
          ];

          CLAUDE_POWERUSER_PROFILE = "anari";
          LD_LIBRARY_PATH = "/run/opengl-driver/lib:${pkgs.mdl-sdk}/lib:${lib.makeLibraryPath anariDevices}";
          DYLD_LIBRARY_PATH = "${lib.makeLibraryPath anariDevices}";

          QT_PLUGIN_PATH = "${pkgs.qt6.qtwayland}/lib/qt-6/plugins";
          QT_QPA_PLATFORM = "xcb";
          QT_OPENGL = "desktop";
          PYOPENGL_PLATFORM = "glx";

          ANARI_LIBRARY = "barney_optix";
          VSR_ANARI_LIBRARIES = "barney_optix,barney_cuda,barney_cpu,${
            lib.concatStringsSep "," (map (p: lib.removePrefix "anari-" p.pname) anariDevices)
          }";
          VSR_LUA_PACKAGE_PATHS = "/data/VSR/scripts";
          shellHook = ''
            if xset -display :10 q >& /dev/null; then
              export DISPLAY=:10
            fi
          '';
        };

        formatter = treefmtEval.config.build.wrapper // {
          src = builtins.filterSource (_path: type: type == "regular") ./.;
        };
      }
    );
}
