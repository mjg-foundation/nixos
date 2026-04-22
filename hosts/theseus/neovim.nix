{pkgs, ...}: {
  programs.neovim = {

    plugins = with pkgs.vimPlugins; [
      gruvbox
    ];

    initLua = ''
      vim.cmd([[
        colorscheme gruvbox
        set background=dark
        let g:gruvbox_contrast_dark='hard'
      ]])
    '';
  };
}
