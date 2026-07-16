#import "Basic";
Input :: #import "Input";
#import "Window_Creation";
#load "pixelbuffer.jai";

virtual_width: u32 = 64;
virtual_height: u32 = 64;
scale: u32 = 8;

clear :: (pixel_buffer: *u32, clear_color: u32) {
  for i: 0..pixels_len - 1 {
    pixel_buffer[i] = clear_color;
  }
}

set_tga :: (pixel_buffer: *u32, x: u32, y: u32, color: u32) {
  set(pixel_buffer, x, virtual_height - (y+1), color);
}

set :: (pixel_buffer: *u32, vx: u32, vy: u32, color: u32) {
  if (vx >= virtual_width || vy >= virtual_height) {
    log_error("bad pixel coord % %!\n", vx, vy);
    return;
  }

  for sy: 0..scale-1 {
    dest_y := (vy * scale + sy) * width;
    for sx: 0..scale-1 {
      dest_x := vx * scale + sx;
      pixel_buffer[dest_y + dest_x] = color;
    }
  }
}


main :: () {
  width  = virtual_width * scale;
  height = virtual_height * scale;
  pixels_len = width * height;

  window = create_window(width, height, "[floating] Software Renderer");
  pixel_buffer := cast(*u32) create_pixel_buffer();
  clear(pixel_buffer, 0x00000000);

  set_tga(pixel_buffer, 7, 3, 0x00ffffff);
  set_tga(pixel_buffer, 12, 37, 0x00ffffff);
  set_tga(pixel_buffer, 62, 53, 0x00ffffff);

  // Main Loop
  should_quit := false;
  oscillate: u32 = 0;
  while !should_quit {
    Input.update_window_events();
    for Input.events_this_frame {
      if it.type == {
        case .QUIT;
          should_quit = true;

        case .KEYBOARD;
          if it.key_pressed == 0 continue;

          if it.key_code == .ESCAPE {
            should_quit = true;
          }
      }
    }

    flush();

    reset_temporary_storage();
    sleep_milliseconds(16); // Target ~60 fps
  }

  cleanup();
}
