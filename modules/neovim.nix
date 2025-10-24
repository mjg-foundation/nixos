{
  lib,
  pkgs,
  config,
  ...
}: {
  programs.neovim = {
    enable = true;

    extraLuaConfig = ''
      vim.opt.number = true
      vim.opt.numberwidth = 1
      vim.opt.clipboard = "unnamedplus"
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.expandtab = true
      vim.opt.cindent = true
      vim.opt.hlsearch = true
      vim.opt.incsearch = true
      vim.cmd("hi Normal ctermbg=NONE")
      vim.cmd("filetype plugin on")

      vim.keymap.set("i", "{", "{}<Left>", { noremap = true })
      vim.keymap.set("i", "(", "()<Left>", { noremap = true })
      vim.keymap.set("i", "[", "[]<Left>", { noremap = true })
      vim.keymap.set("v", "<", "<gv", { noremap = true })
      vim.keymap.set("v", ">", ">gv", { noremap = true })
    '';
  };
}
