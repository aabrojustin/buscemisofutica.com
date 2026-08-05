/* Site behaviour: the full-screen nav panel and the photo carousel.
   No dependencies, no build step. */

/* ---------- Nav panel ----------
   The header "Menu" button opens a full-screen overlay. Closes on the X, on
   Escape, and on any in-page link so the anchor jump is visible. */
(() => {
  const toggle = document.querySelector("[data-nav-toggle]");
  const panel = document.querySelector("[data-nav]");
  if (!toggle || !panel) return;

  const closeBtn = panel.querySelector("[data-nav-close]");

  const setOpen = (open) => {
    panel.setAttribute("data-open", open ? "true" : "false");
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    // Stop the page behind the overlay from scrolling while it is open.
    document.body.style.overflow = open ? "hidden" : "";
    if (open) {
      const first = panel.querySelector("a");
      if (first) first.focus();
    } else {
      toggle.focus();
    }
  };

  toggle.addEventListener("click", () => {
    setOpen(panel.getAttribute("data-open") !== "true");
  });

  if (closeBtn) closeBtn.addEventListener("click", () => setOpen(false));

  panel.querySelectorAll("[data-nav-link]").forEach((link) => {
    link.addEventListener("click", () => setOpen(false));
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && panel.getAttribute("data-open") === "true") {
      setOpen(false);
    }
  });
})();

/* ---------- Gallery: continuously drifting slideshow ----------
   The photo row scrolls sideways on its own and loops forever. The item list
   is cloned once so that when the scroll position passes the end of the first
   copy it can snap back by exactly one copy's width - visually seamless.
   No arrows - the strip just drifts; it pauses only while a finger is on it,
   and never auto-drifts under prefers-reduced-motion (manual scroll works). */
(() => {
  const track = document.querySelector("[data-gallery-track]");
  if (!track) return;

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)");
  const items = [...track.children];
  // Only placeholder tiles or a single photo: nothing worth looping.
  const canLoop = items.length > 1 && !track.querySelector(".gallery__item--empty");

  let loopWidth = 0; // width of one full copy, incl. the trailing gap

  if (canLoop) {
    items.forEach((item) => {
      const clone = item.cloneNode(true);
      clone.setAttribute("aria-hidden", "true");
      track.appendChild(clone);
    });

    // The loop distance is the EXACT layout offset between the first card and
    // its clone - read from live geometry, never summed from widths, so
    // fractional sizes can't drift the seam. Crucially, card width at a fixed
    // height depends on each photo's aspect ratio, which the browser only
    // knows after the image loads: measure again as every photo arrives, and
    // load them eagerly so the seam is never blank when the drift reaches it.
    const firstItem = items[0];
    const firstClone = track.children[items.length];
    const measure = () => {
      loopWidth = firstClone.getBoundingClientRect().left - firstItem.getBoundingClientRect().left;
    };
    track.querySelectorAll("img").forEach((img) => {
      img.loading = "eager";
      if (!img.complete) img.addEventListener("load", measure, { once: true });
    });
    measure();
    window.addEventListener("resize", measure);
  }

  // Wrap scrollLeft into the first copy's range so the loop is invisible.
  const wrap = () => {
    if (!canLoop || loopWidth <= 0) return;
    if (track.scrollLeft >= loopWidth) track.scrollLeft -= loopWidth;
    else if (track.scrollLeft < 0) track.scrollLeft += loopWidth;
  };

  /* Auto-drift */
  const SPEED = 0.4; // px per frame at 60fps - a calm, readable glide
  let paused = false;
  let carry = 0; // scrollLeft is integer in some browsers; accumulate fractions

  const tick = () => {
    if (!paused && !reduced.matches && canLoop) {
      carry += SPEED;
      if (carry >= 1) {
        const px = Math.floor(carry);
        carry -= px;
        track.scrollLeft += px;
        wrap();
      }
    }
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);

  const pause = () => { paused = true; };
  const resume = () => { paused = false; };
  // Hovering does NOT pause the drift - it only stops while a finger is
  // actually on the track (so swiping doesn't fight the auto-scroll).
  track.addEventListener("touchstart", pause, { passive: true });
  track.addEventListener("touchend", () => { wrap(); resume(); });

  // NOTE: deliberately no wrap-on-scroll listener. Wrapping mid-scroll
  // teleports the position while the browser may still be animating toward
  // an old coordinate, which showed as a wild fly-back at the loop point.
  // The drift tick and touch release cover every wrap safely.
})();
