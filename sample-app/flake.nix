{
  description = "Hermetic sample application and deterministic OCI image";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          version = "1.0.0";
          app = pkgs.buildGoModule {
            pname = "sample-app";
            inherit version;
            src = ./.;
            vendorHash = null;
            env.CGO_ENABLED = "0";
            ldflags = [ "-s" "-w" "-X main.version=${version}" ];
            doCheck = true;
          };
        in {
          default = app;
          container = pkgs.dockerTools.buildImage {
            name = "sample-app";
            tag = "nix";
            created = "1970-01-01T00:00:01Z";
            copyToRoot = pkgs.buildEnv {
              name = "sample-app-root";
              paths = [ app pkgs.cacert ];
              pathsToLink = [ "/bin" "/etc/ssl/certs" ];
            };
            config = {
              Cmd = [ "/bin/sample-app" ];
              Env = [ "LISTEN_ADDRESS=:8080" ];
              ExposedPorts."8080/tcp" = { };
              User = "65532:65532";
            };
          };
        });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell { packages = [ pkgs.go pkgs.gopls ]; };
        });
    };
}
