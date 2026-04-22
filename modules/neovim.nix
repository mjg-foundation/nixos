{
  lib,
  pkgs,
  config,
  ...
}: {
  home.shellAliases = {
    vim = "nvim";
  };
  programs.neovim = {
    enable = true;
    withRuby = true;
    withPython3 = true;

    initLua = ''
      vim.opt.number = true
      vim.opt.numberwidth = 1
      vim.opt.clipboard = "unnamedplus"
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.expandtab = true
      vim.opt.cindent = true
      vim.opt.hlsearch = true
      vim.opt.incsearch = true
      vim.cmd("filetype plugin on")

      -- Re-apply transparency after every colorscheme load so it isn't
      -- clobbered when a colorscheme resets all highlight groups.
      local function apply_transparency()
        vim.api.nvim_set_hl(0, 'Normal',      { bg = 'none' })
        vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
        vim.api.nvim_set_hl(0, 'FloatBorder', { bg = 'none' })
        vim.api.nvim_set_hl(0, 'Pmenu',       { bg = 'none' })
      end
      vim.api.nvim_create_autocmd('ColorScheme', { pattern = '*', callback = apply_transparency })
      apply_transparency()

      vim.keymap.set("i", "{", "{}<Left>", { noremap = true })
      vim.keymap.set("i", "(", "()<Left>", { noremap = true })
      vim.keymap.set("i", "[", "[]<Left>", { noremap = true })
      vim.keymap.set("v", "<", "<gv", { noremap = true })
      vim.keymap.set("v", ">", ">gv", { noremap = true })
    '';
  };
}
