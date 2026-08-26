# /home/ilya/TestVerilog/flake.nix
{
  description = "OCSSD Development Environment with verilog-pcie tests";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Исправленная функция сборки расширений
buildCocotbExt = pname: version: hash: deps: pkgs.python311.pkgs.buildPythonPackage {
  inherit pname version;
  src = pkgs.python311.pkgs.fetchPypi { 
    inherit pname version hash; 
  };
  # ИСПОЛЬЗУЙТЕ ТОЧКИ: pkgs . python311Packages . cocotb
  propagatedBuildInputs = [ pkgspythonPackagescocotb ] ++ deps;
  doCheck = false;
};



        pythonEnv = pkgs.python311.withPackages (ps: with ps; [
          cocotb
          pytest
          # Пример добавления расширений с заглушками хешей
          (buildCocotbExt "cocotbext-axi" "0.2.2" "sha-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" [])
          (buildCocotbExt "cocotbext-pcie" "0.2.1" "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" [ 
            (buildCocotbExt "cocotbext-common" "0.1.2" "sha-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" [])
          ])
        ]);
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            iverilog
            gtkwave
            pythonEnv
            git
            gnumake
          ];
        };
      });
}
