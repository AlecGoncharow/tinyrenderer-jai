#import "File";
#import "String";

Model :: struct {
  verts:  [..] Math.Vector4;
  faces:  [..] s32;
}

vert :: (m: *Model, face: s32, nvert: s32) -> *Math.Vector4 {
  return *m.verts[m.faces[(face*3)+nvert]];
}

load_obj_from_file :: (filename: string, model: *Model) {
  f, okay := file_open(filename);
  if (!okay) {
    log_error("failed to open file %!\n", filename);
    return;
  }

  s, okay2 := read_entire_file(f);
  if (!okay2) {
    log_error("failed to read file %!\n", filename);
  }

  lines := split(s, "\n");

  for lines {
    if begins_with(it, "v ") {
      // parse vert
      floats := split(slice(it, 2, it.count - 2), " ");
      x, okx := parse_float(*floats[0]);
      y, oky := parse_float(*floats[1]);
      z, okz := parse_float(*floats[2]);

      if (!okx || !oky || !okz) {
        log_error("failed to parse floats % % %!\n", floats[0], floats[1], floats[2]);
        return;
      }

      r: Math.Vector4 = ---;
      r.x = x;
      r.y = y;
      r.z = z;
      r.w = 1.0;

      array_add(*model.verts, r);

      continue;
    }

    if begins_with(it, "f ") {
      groups := split(slice(it, 2, it.count - 2), " ");
      for group: groups {
        indices := split(group, "/");

        idx, ok := parse_int(*indices[0]);
        array_add(*model.faces, cast(s32) idx - 1);
      }

      continue;
    }
  }
}
