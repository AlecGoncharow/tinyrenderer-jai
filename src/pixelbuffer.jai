#import "X11";
#load "xshm.jai";

display: *Display;
window: Window;
gc: GC;
ximage: *XImage;
xwa: XWindowAttributes;
xshminfo: XShmSegmentInfo;
width: u32;
height: u32;
pixels_len: u32;
visual: *Visual;
depth: s32;

create_pixel_buffer :: () -> *u8 {
  display = x_global_display;
  if !XShmQueryExtension(display) {
    log_error("X11 server does not support the MIT-SHM extension!\n");
    exit(1);
  }

  XGetWindowAttributes(display, window, *xwa);
  visual = xwa.visual;
  depth  = xwa.depth;
  gc = XCreateGC(display, window, 0, null);

  ximage = XShmCreateImage(
    display,
    visual,
    xx depth,
    2, // ZPixmap
    null, // Data
    *xshminfo,
    xx width,
    xx height
  );

  // Allocate the shared memory block on the system using POSIX shmget
  // We calculate the required size using the width, height, and bits-per-pixel from the XImage metadata
  image_size := ximage.bytes_per_line * ximage.height;
  xshminfo.shmid = shmget(IPC_PRIVATE, xx image_size, IPC_CREAT | 0x1FF);
  if xshminfo.shmid < 0 {
    log_error("shmget failed to allocate shared memory segment.\n");
    exit(1);
  }

  // Attach the shared memory to our address space and assign it to the XImage
  shmaddr := shmat(xshminfo.shmid, null, 0);
  if shmaddr == cast(*void) -1 {
    errno :: () -> s32 {
      libc :: #library,system "libc";
      __errno_location :: () -> *s32 #foreign libc;
      return (__errno_location()).*;
    }
    log_error("shmat failed! errno: %\n", errno());
    exit(1);
  }
  xshminfo.shmaddr = cast(*u8) shmaddr;
  ximage.data = xshminfo.shmaddr;
  xshminfo.readOnly = False;

  if !XShmAttach(display, *xshminfo) {
    log_error("XShmAttach failed!\n");
    exit(1);
  }

  // Unix kernel optimization: mark the segment for deletion.
  // It will not actually be destroyed until both the client and X server detach,
  // protecting your system from leaking shared memory if the program crashes.
  shmctl(xshminfo.shmid, IPC_RMID, null);

  return xshminfo.shmaddr;
}

flush :: () {
    // Blit directly (zero IPC copy overhead over the socket)
    XShmPutImage(
      display,
      window,
      gc,
      ximage,
      0, 0,
      0, 0,
      xx width,
      xx height,
      False // send_event (False means don't send XShmCompletionEvent)
    );

    XFlush(display);
}

cleanup :: () {
  XShmDetach(display, *xshminfo);
  XDestroyImage(ximage); // Frees the struct (ximage.data is managed by POSIX shmdt)
  shmdt(xshminfo.shmaddr); // Detach the shared memory from our process
  XFreeGC(display, gc);
}
