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
            {:plug, "~> 1.14"}
          ])

          defmodule Server do
            use Plug.Router

            plug :match
            plug Plug.Parsers, 
              parsers: [:urlencoded],
              pass: ["*/*"]
            plug :dispatch

            get "/" do
              html = """
              <!DOCTYPE html>
              <html lang="en">
              <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Hypernix</title>
                  <script src="https://unpkg.com/htmx.org@2.0.3"></script>
                  <style>
                      body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 2rem; }
                      .counter { font-size: 2rem; margin: 1rem 0; }
                  </style>
              </head>
              <body>
                  <h1>Hypernix</h1>
                  <div class="counter">
                      Count: <span id="count">0</span>
                  </div>
                  <form>
                    <input type="hidden" name="count" value="0"/>
                    <button hx-post="/increment"
                            hx-include="[name='count']"
                            hx-target="#count"
                            hx-swap="innerHTML"
                            onclick="this.previousElementSibling.value = document.getElementById('count').innerText">
                        Increment
                    </button>
                  </form>
              </body>
              </html>
              """
              send_resp(conn, 200, html)
            end

            post "/increment" do
              IO.inspect(conn.body_params, label: "Body params")
              count = 
                case conn.body_params["count"] do
                  nil -> 0
                  str -> String.to_integer(str)
                end
              new_count = count + 1
              send_resp(conn, 200, Integer.to_string(new_count))
            end

            match _ do
              send_resp(conn, 404, "Not found")
            end
          end

          IO.puts("Starting server at http://localhost:8000")
          Bandit.start_link(plug: Server, port: 8000)
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
