clear :: (virtual_buffer: [..]u32, clear_color: u32) {
  for i: 0..virtual_buffer.count - 1 {
    virtual_buffer[i] = clear_color;
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

set :: (virtual_buffer: [..]u32, x: s32, y: s32, color: u32) {
  set_raw(virtual_buffer, x, virtual_height - (y+1), color);
}

set_raw :: (virtual_buffer: [..]u32, vx: s32, vy: s32, color: u32) {
  if (vx < 0 || vx >= virtual_width || vy < 0 || vy >= virtual_height) {
    log_error("bad pixel coord % %!\n", vx, vy);
    return;
  }

  dest_y := vy * virtual_width;
  virtual_buffer[dest_y + vx] = color;
}

draw :: (virtual_buffer: [..]u32, pixel_buffer: *u32) {
  for vy: 0..(virtual_height)-1 {
    for sy: 0..scale-1{
      dest_y := (vy  * scale * width);
      dest_y += (sy * width);
      for vx: 0..(virtual_width)-1 {
        color := virtual_buffer[(vy * virtual_width) + vx];
        for sx: 0..scale-1 {
          dest_x := (vx * scale) + sx;
          pixel_buffer[dest_y + dest_x] = color;
        }
      }
    }
  }
}

draw_scale_grid :: (virtual_buffer: [..]u32, pixel_buffer: *u32) {
  for vy: 0..(virtual_height)-1 {
    for sy: 0..scale-1{
      on_vert := false;
      on_grid := false;
      if SCALE_GRID && (sy == 0 || sy == scale - 1) {
        on_vert = true;
      }
      dest_y := (vy  * scale * width);
      dest_y += (sy * width);
      for vx: 0..(virtual_width)-1 {
        color := virtual_buffer[(vy * virtual_width) + vx];
        for sx: 0..scale-1 {
          dest_x := (vx * scale) + sx;

          if SCALE_GRID && (sx == 0 || sx == scale - 1) {
            on_grid = true;
          } else {
            on_grid = on_vert;
          }

          if SCALE_GRID && on_grid {
            pixel_buffer[dest_y + dest_x] = alpha_blend(color, SCALE_GRID_COLOR, SCALE_GRID_ALPHA);
          } else {
            pixel_buffer[dest_y + dest_x] = color;
          }
        }
      }
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

project :: (v: Math.Vector3) -> s32, s32, s32 {
  return cast(s32) ((v.x + 1.0) * virtual_width / 2.0), cast(s32)((v.y + 1.0) * virtual_height / 2.0),  cast(s32)((v.z + 1.) *   255./2);
}


perspective :: (v: Math.Vector3) -> Math.Vector3 {
  c := 3.;
  return Math.multiply(v,  1 / (1-v.z/c));
}

scale_color :: (color: u32, scale: float64) -> u32 {
  r,g,b := color >> 16 & 0xFF, color >> 8 & 0xFF, color & 0xFF;

  r,g,b = xx(r * scale), xx(g * scale), xx(b * scale);

  return r << 16 + g << 8 + b;
}

alpha_blend :: (bg: u32, fg: u32, alpha: float) -> u32 {
  bg_r := (bg >> 16) & 0xFF;
  bg_g := (bg >> 8)  & 0xFF;
  bg_b := (bg)       & 0xFF;

  fg_r := (fg >> 16) & 0xFF;
  fg_g := (fg >> 8)  & 0xFF;
  fg_b := (fg)       & 0xFF;

  out_r := cast(u32)(bg_r * (1.0 - alpha) + fg_r * alpha);
  out_g := cast(u32)(bg_g * (1.0 - alpha) + fg_g * alpha);
  out_b := cast(u32)(bg_b * (1.0 - alpha) + fg_b * alpha);

  return (out_r << 16) | (out_g << 8) | out_b;
}

//byte order :: nil Red Green Blue
BLACK     :: 0x00000000;
WHITE     :: 0x00FFFFFF;
GREEN     :: 0x0000FF00;
BLUE      :: 0x000000FF;
NICE_BLUE :: 0x004080FF;
CYAN      :: 0x0000FFFF;
RED       :: 0x00FF0000;
YELLOW    :: 0x00FFC800;

line :: (virtual_buffer: [..]u32, ax: s32, ay: s32, ac: u32, bx: s32, by: s32, bc: u32) {
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
      set(virtual_buffer, ry, xx rx, color);
    } else  {
      set(virtual_buffer, xx rx, ry, color);
    }
  }
}


wireframe_triangle :: (virtual_buffer: [..]u32, ax: s32, ay: s32, ac: u32, bx: s32, by: s32, bc: u32, cx: s32, cy: s32, cc: u32) {
  ax, ay = screen_clamp(ax, ay);
  bx, by = screen_clamp(bx, by);
  cx, cy = screen_clamp(cx, cy);

  line(virtual_buffer, ax, ay, ac, bx, by, bc);
  line(virtual_buffer, bx, by, bc, cx, cy, cc);
  line(virtual_buffer, cx, cy, cc, ax, ay, ac);
}
triangle :: (virtual_buffer: [..]u32, p1: Math.Vector3, p2: Math.Vector3, p3: Math.Vector3, color: u32) {
  triangle(virtual_buffer, xx p1.x,xx p1.y,xx p1.z,xx p2.x,xx p2.y,xx p2.z,xx p3.x,xx p3.y,xx p3.z, color);
}

triangle :: (virtual_buffer: [..]u32, ax: s32, ay: s32, az: s32, bx: s32, by: s32, bz: s32, cx: s32, cy: s32, cz: s32, color: u32) {
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
      if depth < get_depth(depth_buffer, x, y) || depth > 255 continue;
      set_depth(depth_buffer, x, y, cast(u8) depth);

      if (DEBUG_DEPTH) {
        depth_color := depth << 16 + depth << 8 + depth;
        set(virtual_buffer, x, y, depth_color);
      } else {
        set(virtual_buffer, x, y, color);
      }

    }
  }

  if BB_DEBUG {
    line(virtual_buffer, bbminx, bbminy, WHITE, bbmaxx, bbminy, CYAN);
    line(virtual_buffer, bbminx, bbminy, WHITE, bbminx, bbmaxy, CYAN);
    line(virtual_buffer, bbminx, bbmaxy, WHITE, bbmaxx, bbmaxy, CYAN);
    line(virtual_buffer, bbmaxx, bbminy, WHITE, bbmaxx, bbmaxy, CYAN);
  }
}

Point :: struct {
  x,y,z: s32;
}
