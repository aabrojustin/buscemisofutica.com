/* Buscemi's photo save deterrent, loaded by Toast as an external script.
   Injects the protective CSS and, as a fallback where site styles override
   pointer-events, blocks the context menu and drag on images directly.
   Deterrent only: screenshots are always possible. */
(function () {
  var style = document.createElement("style");
  style.textContent =
    "img{pointer-events:none;user-select:none;-webkit-user-select:none;" +
    "-webkit-user-drag:none;-webkit-touch-callout:none}";
  (document.head || document.documentElement).appendChild(style);

  document.addEventListener("contextmenu", function (e) {
    var t = e.target;
    if (t && (t.tagName === "IMG" || (t.closest && t.closest("picture")))) {
      e.preventDefault();
    }
  });

  document.addEventListener("dragstart", function (e) {
    if (e.target && e.target.tagName === "IMG") {
      e.preventDefault();
    }
  });
})();
