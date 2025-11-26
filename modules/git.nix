{...}: {
  programs.git = {
    enable = true;
    userName = "Matt Gleason";
    userEmail = "mjgleason@foundationdevices.com";

    # aliases = {
    #   ca = "commit --amend --no-edit";
    # };

    extraConfig = {
      commit.gpgsign = true;
      tag.gpgsign = false;
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      # pull.rebase = true;
      core = {
        # pager = "delta";
        editor = "nvim";
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
