#import "X11";
#import "POSIX"; // For shmget, shmat, shmdt, shmctl, IPC_PRIVATE, IPC_CREAT, IPC_RMID

libXext :: #library,system "libXext";

XShmSegmentInfo :: struct {
  shmseg:   u64;  // ShmSeg in C (unsigned long)
  shmid:    s32;  // Segment ID
  shmaddr:  *u8;  // Address of shared memory
  readOnly: s32;  // Bool (X11 Bool is int / s32)
}

XShmQueryExtension :: (dpy: *Display) -> s32 #foreign libXext;

XShmCreateImage :: (
  dpy: *Display,
  visual: *Visual,
  depth: u32,
  format: s32,
  data: *u8,
  shminfo: *XShmSegmentInfo,
  width: u32,
  height: u32
) -> *XImage #foreign libXext;

XShmAttach :: (dpy: *Display, shminfo: *XShmSegmentInfo) -> s32 #foreign libXext;
XShmDetach :: (dpy: *Display, shminfo: *XShmSegmentInfo) -> s32 #foreign libXext;

XShmPutImage :: (
  dpy: *Display,
  d: Drawable,
  gc: GC,
  image: *XImage,
  src_x: s32, src_y: s32,
  dest_x: s32, dest_y: s32,
  src_width: u32, src_height: u32,
  send_event: s32
) -> s32 #foreign libXext;
