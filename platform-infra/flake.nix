{
  description = "Pinned Pantanal control-plane toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cosign
              docker-client
              actionlint
              git
              gitleaks
              go
              golangci-lint
              govulncheck
              kubernetes-helm
              helmfile
              jq
              kind
              kubeconform
              kubectl
              kustomize
              markdownlint-cli
              nixfmt
              openssl
              pre-commit
              shellcheck
              shfmt
              skopeo
              statix
              trivy
              yamllint
              yq-go
            ];
          };
        });
    };
}
