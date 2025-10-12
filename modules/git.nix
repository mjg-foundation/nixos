{...}: {
  programs.git = {
    enable = true;
    userName = "Matt Gleason";
    userEmail = "mjgleason@foundationdevices.com";

    signing = {
      key = "027D8671272F9DDA";
      signByDefault = true;
    };

    # aliases = {
    #   ca = "commit --amend --no-edit";
    # };

    extraConfig = {
      commit.gpgsign = true;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      # pull.rebase = true;
      core = {
        # pager = "delta";
        editor = "vim";
      };
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
        "https://github.com/rust-lang/crates.io-index" = {
          insteadOf = "https://github.com/rust-lang/crates.io-index";
        };
      };
      # delta = {
      #   navigate = true;
      #   side-by-side = true;
      #   line-numbers = true;
      #   hyperlinks = true;
      # };
    };
  };
}
