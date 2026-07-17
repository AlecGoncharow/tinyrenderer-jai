
scanline_rasterized_triangle :: (pixel_buffer: *u32, ax: s32, ay: s32, bx: s32, by: s32, cx: s32, cy: s32, color: u32) {
  interpolate_x :: (ax: s32, ay: s32, bx: s32, by: s32, y: s32) -> s32 {
    dx := Math.abs(ax - bx);
    dy := Math.abs(ay - by);

    if (ay > by) {
      // swap so sampling logic works
      ax, bx = bx, ax;
      ay, by = by, ay;
    }

    t := cast(float)(y - ay) / (by-ay);

    x := (ax + (bx-ax)*t );
    return round(x);
  }

  if ay > by {
    ax, bx = bx, ax;
    ay, by = by, ay;
  }
  if ay > cy {
    ax, cx = cx, ax;
    ay, cy = cy, ay;
  }
  if by > cy {
    cx, bx = bx, cx;
    cy, by = by, cy;
  }

  // so we know we are rasterizing from (ax, ay) -> (cx, cy) to the other two lines, we now need to scan across the triangle
  // and fill the pixels between the two lines at a given y level, this requries us to interpolate the x coords and draw a line
  // at each point in each line,
  // however where lines (ax, ay) -> (bx, by) and (cx, cy) -> (bx, by) meet we need to switch the target line, which is at y = by

  // to determine our first target, we simply scan from ay -> target line which is ay -> by, so we interpolate on lines ax,ay -> cx, cy to ax,ay -> bx,by until by
  // then we switch to interpolating from ax,ay -> cx,cy to bx,by -> cx,cy once y > by

  // first we need to find start x on start line, then we need to find target x on target line for given y coord
  for scan_y: ay..by {
    inta, intb := interpolate_x(ax, ay, cx, cy, scan_y), interpolate_x(ax, ay, bx, by, scan_y);
    if inta == intb {
      continue;
    }
    line(pixel_buffer, inta, scan_y, intb, scan_y, GREEN);
  }

  for scan_y: by..cy {
    inta, intb := interpolate_x(ax, ay, cx, cy, scan_y), interpolate_x(bx, by, cx, cy, scan_y);
    if inta == intb {
      continue;
    }
    line(pixel_buffer, inta, scan_y, intb, scan_y, GREEN);
  }

  line(pixel_buffer, ax, ay, bx, by, WHITE);
  line(pixel_buffer, bx, by, cx, cy, WHITE);
  line(pixel_buffer, cx, cy, ax, ay, RED);
}


// ax, ay : s32 = 7, 3;
// bx, by : s32 = 12, 37;
// cx, cy : s32 = 62, 53;

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
