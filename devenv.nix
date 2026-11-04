{
  pkgs,
  lib,
  ...
}: {
  # Use the system Xcode toolchain: no Nix compiler or Apple SDK, so the shell
  # doesn't set CC, SDKROOT or DEVELOPER_DIR, which break SwiftPM and actool.
  stdenv = pkgs.stdenvNoCC;
  apple.sdk = null;

  # Development tools only. Swift, the macOS SDK, actool and codesign come from
  # the system Xcode; the app is never built with Nix.
  packages = with pkgs;
    [
      just
      git
      swiftformat
      swiftlint
      complgen
      # The website and docs (docs/)
      nodejs_22
      pnpm
    ]
    # Only for macOS. The Linux jobs of CI build the website and check commit messages
    ++ lib.optionals stdenv.isDarwin [periphery];

  # Git hooks.
  git-hooks = {
    hooks = {
      gitlint = {
        enable = true;
        description = "Run gitlint to check commit messages";
        stages = ["commit-msg"];
      };

      alejandra = {
        enable = true;
        description = "Run the Alejandra formatter on Nix files";
      };
    };
  };

  # Extra configuration files to symlink.
  files = {
    ".gitlint".ini = {
      general = {
        contrib = "contrib-title-conventional-commits";
        ignore = "body-is-missing,body-min-length";
      };

      title-max-length.line-length = 120;
      body-max-line-length.line-length = 120;
    };
  };
}
