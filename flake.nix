{
  description = "HyperNix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        elixir = pkgs.beam.packages.erlang.elixir;
        
        serverScript = pkgs.writeText "server.exs" ''
          Mix.install([
            {:bandit, "~> 1.0"},
            {:plug, "~> 1.14"},
            {:francis_htmx, "~> 0.1.0"}
          ])

          defmodule Example do
            use Francis
            import FrancisHtmx

            htmx(fn _conn ->
              assigns = %{}
              ~E"""
              <style>
                .smooth {   transition: all 1s ease-in; font-size: 8rem; }
              </style>
              <div hx-get="/colors" hx-trigger="every 1s">
                <p id="color-demo" class="smooth">Color Swap Demo</p>
              </div>
              """
            end)

            get("/colors", fn _ ->
              new_color = 3 |> :crypto.strong_rand_bytes() |> Base.encode16() |> then(&"##{&1}")
              assigns = %{new_color: new_color}

              ~E"""
              <p id="color-demo" class="smooth" style="<%= "color:#{@new_color}"%>">
              Color Swap Demo
              </p>
              """
            end)
          end
          IO.puts("Starting server at http://localhost:8000")
          Bandit.start_link(plug: Example, port: 8000)
          Process.sleep(:infinity)
        '';
        
        runScript = pkgs.writeShellScriptBin "run-server" ''
          mkdir -p .nix-mix .nix-hex
          export MIX_HOME=$PWD/.nix-mix
          export HEX_HOME=$PWD/.nix-hex
          export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
          export ELIXIR_ERL_OPTIONS="+fnu"
          ${elixir}/bin/elixir ${serverScript}
        '';
      in
      {
        packages.default = runScript;

        apps.default = {
          type = "app";
          program = "${runScript}/bin/run-server";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ elixir ];
          shellHook = ''
            mkdir -p .nix-mix .nix-hex
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
            export ELIXIR_ERL_OPTIONS="+fnu"
          '';
        };
      }
    );
}
