{ pkgs }: {
  deps = [
    # Backend toolchain — Java 21 LTS (canonical baseline for this template).
    pkgs.jdk21
    pkgs.maven

    # Frontend toolchain
    pkgs.nodejs_22

    # Postgres CLI client (psql) — useful for ad-hoc queries from the Replit
    # shell. The managed SQL Database itself is provided by the postgresql-16
    # module declared in .replit, not by this Nix package.
    pkgs.postgresql_16

    # Shell utilities the Agent uses while scaffolding.
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.yq-go
  ];
}
