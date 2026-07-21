#import "Basic";
Math :: #import "Math";
Input :: #import "Input";
using Random :: #import "Random";
#import "Window_Creation";
#load "pixelbuffer.jai";
#load "obj.jai";
#load "draw.jai";

virtual_width: s32 = 100;
virtual_height: s32 = 100;
virtual_buffer: [..]u32;
scale: s32 = 8;
depth_buffer: [..] u8;

DEBUG       := true;
BB_DEBUG    := false;
DEBUG_DEPTH := false;
SCALE_GRID  := true;
SCALE_GRID_COLOR : u32 = WHITE;
SCALE_GRID_ALPHA := 0.3;

ENABLE_PROFILING :: false;
#import "Basic"()(MEMORY_DEBUGGER=false, VISUALIZE_MEMORY_DEBUGGER=false);

main :: () {
  #if ENABLE_PROFILING trace_init("trace.json");
  defer #if ENABLE_PROFILING trace_shutdown();
  width  = xx(virtual_width * scale);
  height = xx(virtual_height * scale);
  pixels_len = width * height;
  array_resize(*depth_buffer, virtual_width * virtual_height);
  array_resize(*virtual_buffer, virtual_width * virtual_height);


  window = create_window(width, height, "[floating] Software Renderer");
  // @TODO would be nice to make this portable eventually, which probably means
  // also not directly editing the pixel buffer like it's a simple array, since
  // the color format can changeo or whatever.
  pixel_buffer := cast(*u32) create_pixel_buffer();
  clear(virtual_buffer, BLACK);

  model: Model;
  // load_obj_from_file("./obj/head/head.obj", *model);
  load_obj_from_file("./obj/diablo_pose.obj", *model);
  // Main Loop
  should_quit := false;
  oscillate: u32 = 0;

  p1, p2, p3 := Math.Vector3.{-0.5, -0.5, 1}, Math.Vector3.{1.0, 1.0, 1}, Math.Vector3.{.5, -0.5, 1};

  q: Math.Quaternion;
  Math.set_from_axis_and_angle(*q, .{0, 0, 1}, Math.PI / 30);
  render_model(virtual_buffer, *model);
  draw(virtual_buffer, pixel_buffer);

  should_redraw := false;
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

          if it.key_code == cast(Input.Key_Code) #char "G" {
            SCALE_GRID = !SCALE_GRID;
            should_redraw = true;
          }
      }
    }

    if should_redraw {
      clear(virtual_buffer, BLACK);
      clear(depth_buffer);
      render_model(virtual_buffer, *model);
      if SCALE_GRID {
        draw_scale_grid(virtual_buffer, pixel_buffer);
      } else {
        draw(virtual_buffer, pixel_buffer);
      }
      should_redraw = false;
    }
    // triangle(pixel_buffer, Math.translate(tmatrix, p3), GREEN);

    // Math.rotate(*p1, q);
    // Math.rotate(*p2, q);
    // Math.rotate(*p3, q);

    flush();

    // rotate_model_in_place(*model, Math.PI / 30);

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
