#import "Basic";
Math :: #import "Math";
Input :: #import "Input";
using Random :: #import "Random";
#import "Window_Creation";
#load "pixelbuffer.jai";
#load "obj.jai";

virtual_width: s32 = 100;
virtual_height: s32 = 100;
scale: s32 = 8;
depth_buffer: [..] u8;

clear :: (pixel_buffer: *u32, clear_color: u32) {
  for i: 0..pixels_len - 1 {
    pixel_buffer[i] = clear_color;
  }
}

clear :: (depth_buffer: [..]u8) {
  for i: 0..depth_buffer.count - 1 {
    depth_buffer[i] = 0;
  }
}

get_depth :: (buffer: [..]u8, x: s32, y: s32) -> u8 {
  y = virtual_height - (y+1);

  return buffer[y*virtual_width + x];
}

set_depth:: (buffer: [..]u8, x: s32, y: s32, depth: u8) {
  y = virtual_height - (y+1);

  buffer[y*virtual_width + x] = depth;
}

set :: (pixel_buffer: *u32, x: s32, y: s32, color: u32) {
  set_raw(pixel_buffer, x, virtual_height - (y+1), color);
}

set_raw :: (pixel_buffer: *u32, vx: s32, vy: s32, color: u32) {
  if (vx < 0 || vx >= virtual_width || vy < 0 || vy >= virtual_height) {
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

screen_clamp :: (x: s32, y: s32) -> s32, s32{
  return clamp(x, 0, virtual_width - 1), clamp(y, 0, virtual_height - 1);
}

project :: (v: *Math.Vector3) -> s32, s32, s32 {
  return cast(s32) ((v.x + 1.0) * virtual_width / 2.0), cast(s32)((v.y + 1.0) * virtual_height / 2.0),  cast(s32)((v.z + 1.) *   255./2);
}

scale_color :: (color: u32, scale: float64) -> u32 {
  r,g,b := color >> 16 & 0xFF, color >> 8 & 0xFF, color & 0xFF;

  r,g,b = xx(r * scale), xx(g * scale), xx(b * scale);

  return r << 16 + g << 8 + b;
}

DEBUG       :: true;
BB_DEBUG    :: false;
DEBUG_DEPTH :: true;

//byte order :: nil Red Green Blue
BLACK     :: 0x00000000;
WHITE     :: 0x00FFFFFF;
GREEN     :: 0x0000FF00;
BLUE      :: 0x000000FF;
NICE_BLUE :: 0x004080FF;
CYAN      :: 0x0000FFFF;
RED       :: 0x00FF0000;
YELLOW    :: 0x00FFC800;

line :: (pixel_buffer: *u32, ax: s32, ay: s32, ac: u32, bx: s32, by: s32, bc: u32) {
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
    ac, bc = bc, ac;
  }

  for x: ax..bx {
    // t(x) = (x - ax) / (bx - ax)
    t := cast(float)(x - ax) / (bx-ax);
    y := (ay + (by-ay)*t );

    rx := x;
    ry := round(y);

    alpha := 1 - t;
    beta  := t;
    color := cast(u32)(scale_color(ac, alpha) + scale_color(bc, beta));

    if steep {
      // de-transpose
      set(pixel_buffer, ry, xx rx, color);
    } else  {
      set(pixel_buffer, xx rx, ry, color);
    }
  }
}


wireframe_triangle :: (pixel_buffer: *u32, ax: s32, ay: s32, ac: u32, bx: s32, by: s32, bc: u32, cx: s32, cy: s32, cc: u32) {
  ax, ay = screen_clamp(ax, ay);
  bx, by = screen_clamp(bx, by);
  cx, cy = screen_clamp(cx, cy);

  line(pixel_buffer, ax, ay, ac, bx, by, bc);
  line(pixel_buffer, bx, by, bc, cx, cy, cc);
  line(pixel_buffer, cx, cy, cc, ax, ay, ac);
}
triangle :: (pixel_buffer: *u32, p1: Math.Vector3, p2: Math.Vector3, p3: Math.Vector3, color: u32) {
  triangle(pixel_buffer, xx p1.x,xx p1.y,xx p1.z,xx p2.x,xx p2.y,xx p2.z,xx p3.x,xx p3.y,xx p3.z, color);
}

triangle :: (pixel_buffer: *u32, ax: s32, ay: s32, az: s32, bx: s32, by: s32, bz: s32, cx: s32, cy: s32, cz: s32, color: u32) {
  signed_triangle_area :: (ax: s32, ay: s32, bx: s32, by: s32, cx: s32, cy: s32) -> float64 {
    return .5*((by-ay)*(bx+ax) + (cy-by)*(cx+bx) + (ay-cy)*(ax+cx));
  }

  bbminx, bbminy  := screen_clamp(min(min(ax, bx), cx), min(min(ay, by), cy));
  bbmaxx, bbmaxy  := screen_clamp(max(max(ax, bx), cx), max(max(ay, by), cy));
  area := signed_triangle_area(ax, ay, bx, by, cx, cy);

  if area < 1 {
    // backface culling + discarding triangles that cover less than a pixel
    return;
  }

  for x:bbminx..bbmaxx {
    for y:bbminy..bbmaxy {
      alpha := signed_triangle_area(x, y, bx, by, cx, cy) / area;
      beta  := signed_triangle_area(x, y, cx, cy, ax, ay) / area;
      gamma := signed_triangle_area(x, y, ax, ay, bx, by) / area;

      if (alpha<0 || beta<0 || gamma<0) continue;

      // color := cast(u32)(scale_color(az, alpha) + scale_color(bz, beta) + scale_color(cz, gamma));
      depth := cast(u32)(az * alpha + bz * beta + cz * gamma);
      if depth < get_depth(depth_buffer, x, y) continue;
      set_depth(depth_buffer, x, y, cast(u8) depth);

      if (DEBUG_DEPTH) {
        depth_color := depth << 16 + depth << 8 + depth;
        set(pixel_buffer, x, y, depth_color);
      } else {
        set(pixel_buffer, x, y, color);
      }

    }
  }

  if BB_DEBUG {
    line(pixel_buffer, bbminx, bbminy, WHITE, bbmaxx, bbminy, CYAN);
    line(pixel_buffer, bbminx, bbminy, WHITE, bbminx, bbmaxy, CYAN);
    line(pixel_buffer, bbminx, bbmaxy, WHITE, bbmaxx, bbmaxy, CYAN);
    line(pixel_buffer, bbmaxx, bbminy, WHITE, bbmaxx, bbmaxy, CYAN);
  }
}

Point :: struct {
  x,y,z: s32;
}

ENABLE_PROFILING :: true;
#import "Basic"()(MEMORY_DEBUGGER=true, VISUALIZE_MEMORY_DEBUGGER=true);

main :: () {
  #if ENABLE_PROFILING trace_init("trace.json");
  defer #if ENABLE_PROFILING trace_shutdown();
  width  = xx(virtual_width * scale);
  height = xx(virtual_height * scale);
  pixels_len = width * height;
  array_resize(*depth_buffer, virtual_width * virtual_height);


  window = create_window(width, height, "[floating] Software Renderer");
  // @TODO would be nice to make this portable eventually, which probably means
  // also not directly editing the pixel buffer like it's a simple array, since
  // the color format can changeo or whatever.
  pixel_buffer := cast(*u32) create_pixel_buffer();
  clear(pixel_buffer, BLACK);

  model: Model;
  // load_obj_from_file("./obj/head/head.obj", *model);
  load_obj_from_file("./obj/diablo_pose.obj", *model);
  // Main Loop
  should_quit := false;
  oscillate: u32 = 0;

  p1, p2, p3 := Math.Vector3.{-0.5, -0.5, 1}, Math.Vector3.{1.0, 1.0, 1}, Math.Vector3.{.5, -0.5, 1};

  q: Math.Quaternion;
  Math.set_from_axis_and_angle(*q, .{0, 0, 1}, Math.PI / 30);
  tmatrix := Math.make_translation_matrix4(Math.Vector3.{30, 30, 0});

  while !should_quit {
    #if ENABLE_PROFILING memory_visualizer_per_frame_update();
    profile_scope("Frame");
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

    clear(pixel_buffer, BLACK);
    clear(depth_buffer);
    render_model(pixel_buffer, *model);
    // triangle(pixel_buffer, Math.translate(tmatrix, p3), GREEN);

    // Math.rotate(*p1, q);
    // Math.rotate(*p2, q);
    // Math.rotate(*p3, q);

    flush();
     rotate_model_in_place(*model, Math.PI / 30);

    reset_temporary_storage();
    sleep_milliseconds(16); // Target ~60 fps
    oscillate += 1;
  }

  cleanup();
}

trace_file: File;
trace_initialized := false;
trace_is_first := true;

trace_init :: (filename: string) -> bool {
  f, success := file_open(filename, for_writing=true, keep_existing_content=false);
  if !success {
    log_error("Failed to open trace file: %\n", filename);
    return false;
  }
  trace_file = f;
  trace_initialized = true;
  file_write(*trace_file, "[\n");
  return true;
}

trace_shutdown :: () {
  if !trace_initialized return;
  file_write(*trace_file, "\n]\n");
  file_close(*trace_file);
  trace_initialized = false;
}

trace_write_event :: (name: string, phase: string, timestamp: Apollo_Time) {
  if !trace_initialized return;

  us_time, success := to_microseconds(timestamp);

  comma := ifx trace_is_first then "  " else ",\n  ";
  trace_is_first = false;

  event_str := tprint("%{\"name\": \"%\", \"ph\": \"%\", \"ts\": %, \"pid\": 1, \"tid\": 1}", comma, name, phase, us_time);
  file_write(*trace_file, event_str);
}

profile_scope :: (name: string) #expand {
  #if ENABLE_PROFILING {
    trace_write_event(name, "B", current_time_monotonic());
    `defer trace_write_event(name, "E", current_time_monotonic());
  }
}
