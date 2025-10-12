{config, ...}: {
  services.walker = {
    enable = true;

    settings = {
      force_keyboard_focus = true;

      # keys = {
      #   next = ["ctrl n"];
      #   prev = ["ctrl p"];
      # };

      ui.window.box = {
        width = 664;
        min_width = 664;
        max_width = 664;
        height = 396;
        min_height = 396;
        max_height = 396;
      };

      # List constraints are critical - without these, the window shrinks when empty
      ui.window.box.scroll.list = {
        height = 300;
        min_height = 300;
        max_height = 300;
      };

      # Smaller icon size
      ui.window.box.scroll.list.item.icon = {
        pixel_size = 24;
      };

      providers = {
        default = ["desktopapplications"];
        # prefixes = [
        #   {
        #     prefix = "?";
        #     provider = "websearch";
        #   }
        # ];
      };
    };
  };
}
