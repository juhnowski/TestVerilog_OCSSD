# /home/ilya/TestVerilog/flake.nix
{
  description = "OCSSD Dev Environment: Clean Python & Verilog Simulation";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        customCocotb = pkgs . python311Packages . buildPythonPackage rec {
          pname = "cocotb";
          version = "2.0.1";
          src = pkgs . fetchFromGitHub {
            owner = "cocotb";
            repo = "cocotb";
            rev = "v${version}";
            hash = "sha256-LXQNqFlvP+WBaDGWPs5+BXBtW2dhDu+v+7lR/AMG21M="; # Хеш зафиксирован
          };
          pyproject = true;
          
          nativeBuildInputs = with pkgs . python311Packages; [ setuptools wheel ];
          
          # ФИКС: Прокидываем find-libpython как runtime-зависимость для cocotb
          propagatedBuildInputs = with pkgs . python311Packages; [ find-libpython ];
          
          doCheck = false;
        };

        pythonEnv = pkgs . python311 . withPackages (ps: with ps; [
          customCocotb
          pytest
        ]);
      in {
        devShells.default = pkgs . mkShell {
          buildInputs = with pkgs; [
            iverilog
            gtkwave
            pythonEnv
            gnumake
            git
          ];

          shellHook = ''
            echo "⚡ [Enterprise Lab] Окружение полностью готово."
            echo "Icarus Verilog + Cocotb успешно установлены!"
          '';
        };
      });
}
