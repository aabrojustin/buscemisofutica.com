# The Original Buscemi's — Utica, Hall Road

Single-location website for the Original Buscemi's Party Shoppe at **8315 Hall Rd, Utica, MI**. Static HTML/CSS/JS — no build dependencies at runtime.

## Local development

Two PowerShell helpers in `scripts/`:

```powershell
# Regenerate index.html from data/store.json
powershell -ExecutionPolicy Bypass -File scripts\generate.ps1

# Spin up a tiny local server at http://localhost:8080
powershell -ExecutionPolicy Bypass -File scripts\serve.ps1
```

To swap a menu-card photo, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\add-photo.ps1
```

It pops a file picker, asks which menu slot, copies the photo into `assets/menu/`, and re-runs the generator.

## Project structure

```
index.html              # Deployable landing page (generated)
css/styles.css          # Brand design system + components
js/main.js              # Mobile nav toggle
data/store.json         # Source of truth: address, phone, hours, URLs, rating
assets/
  logo.png              # Buscemi's shield logo
  menu/                 # Per-menu-card photos (torpedo, pizza, party-shoppe, catering)
scripts/
  generate.ps1          # Reads store.json -> writes index.html
  serve.ps1             # PowerShell HTTP file server for local preview
  add-photo.ps1         # File picker for swapping menu photos
```

## Editing content

Edit `data/store.json` for hours, address, phone, rating, or order/review URLs, then run `scripts/generate.ps1`. Edit `scripts/generate.ps1` directly for menu-card copy or section text.

## Deployment

Hosted via GitHub Pages from the `main` branch root. Any push that updates `index.html`, `css/`, `js/`, or `assets/` will roll out automatically.
