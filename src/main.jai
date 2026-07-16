#import "Basic";
Math :: #import "Math";
Input :: #import "Input";
#import "Window_Creation";
#load "pixelbuffer.jai";
#load "obj.jai";

virtual_width: s32 = 1000;
virtual_height: s32 = 1000;
scale: s32 = 1;

clear :: (pixel_buffer: *u32, clear_color: u32) {
  for i: 0..pixels_len - 1 {
    pixel_buffer[i] = clear_color;
  }
}

set_tga :: (pixel_buffer: *u32, x: s32, y: s32, color: u32) {
  set(pixel_buffer, x, virtual_height - (y+1), color);
}

set :: (pixel_buffer: *u32, vx: s32, vy: s32, color: u32) {
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

round :: (f: float) -> s32 {
  if Math.frac(f) > 0.5 {
    return cast(s32) Math.ceil(f);
  } else {
    return cast(s32) Math.floor(f);
  }
}

wrapping_add :: (min: s32, max :s32, x: s32, dx: s32) -> s32 {
  x += dx;
  if x >= max {
    x = x - max;
  }

  if x < min {
    x = max - x;
  }

  return x;
}

project :: (v: *Math.Vector4) -> s32, s32 {
  return cast(s32) ((v.x + 1.0) * virtual_width / 2.0), cast(s32)((v.y + 1.0) * virtual_height / 2.0);
}


//byte order :: nil Red Green Blue
BLACK   :: 0x00000000;
WHITE   :: 0x00FFFFFF;
GREEN   :: 0x0000FF00;
BLUE    :: 0x004080FF;
RED     :: 0x00FF0000;
YELLOW  :: 0x00FFC800;

line :: (pixel_buffer: *u32, ax: s32, ay: s32, bx: s32, by: s32, color: u32) {
  dx := Math.abs(ax - bx);
  dy := Math.abs(ay - by);
  steep := dy > dx;
  if steep {
    // transpose for steeper lines
    ax, ay = ay, ax;
    bx, by = by, bx;
  }

  if (ax > bx) {
    // swap so sampling logic works
    ax, bx = bx, ax;
    ay, by = by, ay;
  }

  for x: ax..bx {
    // t(x) = (x - ax) / (bx - ax)
    t := cast(float)(x - ax) / (bx-ax);
    y := (ay + (by-ay)*t );

    rx := x;
    ry := round(y);

    if steep {
      // de-transpose
      set_tga(pixel_buffer, ry, xx rx, color);
    } else  {
      set_tga(pixel_buffer, xx rx, ry, color);
    }
  }
}

main :: () {
  width  = xx(virtual_width * scale);
  height = xx(virtual_height * scale);
  pixels_len = width * height;

  window = create_window(width, height, "[floating] Software Renderer");
  pixel_buffer := cast(*u32) create_pixel_buffer();
  clear(pixel_buffer, BLACK);

  // ax, ay : s32 = 7, 3;
  // bx, by : s32 = 12, 37;
  // cx, cy : s32 = 62, 53;

  model: Model;
  load_obj_from_file("./pose.obj", *model);
  print("% %", model.verts.count, model.faces.count);

  nfaces : s32 = cast(s32) model.faces.count / 3;
  for 0..nfaces-1{
    ax, ay := project(vert(*model, it, 0));
    bx, by := project(vert(*model, it, 1));
    cx, cy := project(vert(*model, it, 2));

    line(pixel_buffer, ax, ay, bx, by, RED);
    line(pixel_buffer, bx, by, cx, cy, RED);
    line(pixel_buffer, cx, cy, ax, ay, RED);
  }

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

    // if oscillate > 2 {
      // oscillate = 0;
      // ax = wrapping_add(0, virtual_width, ax, 1);
      // bx = wrapping_add(0, virtual_width, bx, 1);
      // cx = wrapping_add(0, virtual_width, cx, 1);
    // }

    // clear(pixel_buffer, BLACK);
    // line(pixel_buffer, ax, ay, bx, by, BLUE);
    // line(pixel_buffer, cx, cy, bx, by, GREEN);
    // line(pixel_buffer, cx, cy, ax, ay, YELLOW);
    // line(pixel_buffer, ax, ay, cx, cy, RED);
    // set_tga(pixel_buffer, ax, ay, WHITE);
    // set_tga(pixel_buffer, bx, by, WHITE);
    // set_tga(pixel_buffer, cx, cy, WHITE);


    flush();

    reset_temporary_storage();
    sleep_milliseconds(16); // Target ~60 fps
    oscillate += 1;
  }

  cleanup();
}
