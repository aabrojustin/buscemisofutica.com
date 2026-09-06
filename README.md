# The Original Buscemi's — Utica, Hall Road

Single-location website for the Original Buscemi's Party Shoppe at **8315 Hall Rd, Utica, MI**. Static HTML/CSS/JS — no build dependencies at runtime.

## Local development

Two PowerShell helpers in `scripts/`:

```powershell
# Regenerate sitemap.xml (index.html is hand-authored and is NOT rewritten)
powershell -ExecutionPolicy Bypass -File scripts\generate.ps1

# Spin up a tiny local server at http://localhost:8080
powershell -ExecutionPolicy Bypass -File scripts\serve.ps1
```

Menu photos are transparent cutouts in `assets/menu/cut/` and are referenced directly from `menu/index.html`; `scripts/add-photo.ps1` belongs to the old generated homepage and no longer affects the live site.

## Project structure

```
index.html              # Homepage (hand-authored)
css/styles.css          # Shared "Night Oven" design system
css/pages/*.css         # One stylesheet per subpage (menu, story, party-shoppe, catering, jobs)
js/main.js              # Nav overlay + drifting gallery
data/store.json         # Source of truth: address, phone, hours, URLs, rating
assets/
  logo.png              # Buscemi's shield logo
  menu/                 # Product photos; cut/ holds the transparent cutouts used on /menu/
scripts/
  generate.ps1          # Reads store.json -> writes sitemap.xml (index.html write is disabled)
  serve.ps1             # PowerShell HTTP file server for local preview
  add-photo.ps1         # File picker for swapping menu photos
```

## Editing content

Edit the page HTML directly (`index.html`, `menu/index.html`, and so on). `data/store.json` still feeds `scripts/generate.ps1` for `sitemap.xml`, but the homepage is no longer generated from it. After editing any stylesheet or `js/main.js`, restamp the `?v=` hashes in every page.

## Deployment

Hosted via GitHub Pages from the `main` branch root. Any push that updates `index.html`, `css/`, `js/`, or `assets/` will roll out automatically.


## Design (September 2026)

The site uses the "Night Oven" design: `css/styles.css` is the shared stylesheet and each subpage adds `css/pages/<page>.css`. `index.html` is hand-authored; `scripts/generate.ps1` no longer rewrites it (it still regenerates `sitemap.xml`). Menu item photos are transparent cutouts in `assets/menu/cut/`. Stylesheet and script links carry content-hash versions (`?v=`) that must be restamped after any edit.
