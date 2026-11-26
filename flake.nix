{
  description = "llama-swap with ready-only observability forwarding and a priority-shaped concurrency limit";

  inputs = {
    flake-lib.url = "github:jgus-org/flake-lib/v1";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      flake-lib,
      nixpkgs,
      ...
    }:
    flake-lib.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        orgFormatting = flake-lib.lib.mkFormatting {
          inherit self system;
        };
      in
      {
        checks.formatting = orgFormatting.check;
        formatter = orgFormatting.formatter;
        packages = rec {
          default = llama-swap;
          llama-swap = pkgs.llama-swap-minimal.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./observability.patch
              ./priority-admission.patch
            ];
          });
        };
      }
    );
}
