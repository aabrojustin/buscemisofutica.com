# Original Buscemi's - Utica Hall Road site generator
# Reads data/store.json and writes index.html.
# Run: powershell -ExecutionPolicy Bypass -File scripts\generate.ps1
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads the source as
# ANSI unless there is a UTF-8 BOM, so literal Unicode characters get mangled.
# Use HTML entities (&mdash; &middot; &reg; &copy;) in the markup instead.

$ErrorActionPreference = "Stop"

$root      = Split-Path -Parent $PSScriptRoot
$dataPath  = Join-Path $root "data\store.json"
$indexPath = Join-Path $root "index.html"

$store = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Encode-Html([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }
function PhoneToTel([string]$p)  { "+1" + ($p -replace '[^0-9]','') }
function UrlEncode([string]$s)   { [uri]::EscapeDataString($s) }
function WriteUtf8([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# Finds the first existing image for a base path (extension-agnostic).
# Returns the web-relative path, or $null when no photo has been supplied.
function FindImage([string]$relBase) {
  foreach ($ext in @("jpg", "jpeg", "png", "webp")) {
    $rel = "$relBase.$ext"
    $abs = Join-Path $root ($rel -replace '/', '\')
    if (Test-Path $abs -PathType Leaf) { return $rel }
  }
  return $null
}

$city       = Encode-Html $store.city
$nbhd       = Encode-Html $store.neighborhood
$address    = Encode-Html $store.address
$cityState  = Encode-Html $store.cityStateZip
$phone      = Encode-Html $store.phone
$tel        = PhoneToTel $store.phone
$mapQuery   = UrlEncode "$($store.address), $($store.cityStateZip)"
$orderUrl   = Encode-Html $store.orderUrl
$menuUrl    = Encode-Html $store.menuUrl
$igUrl      = Encode-Html $store.instagramUrl
$rating     = $store.rating
$reviewCount= Encode-Html $store.reviewCount
$reviewUrl  = Encode-Html $store.googleReviewUrl
$listingUrl = Encode-Html $store.googleListingUrl
$ratingPct  = [math]::Round(($rating / 5) * 100, 1)
$ratingStr  = ([string]$rating).TrimEnd('0').TrimEnd('.')
if ([string]::IsNullOrEmpty($ratingStr)) { $ratingStr = [string]$rating }
# Always show one decimal for ratings (e.g. 4.7 not 4)
if ($ratingStr -notmatch '\.') { $ratingStr = "$ratingStr.0" }

$siteUrl = ($store.siteUrl).TrimEnd('/')
# schema.org opening hours (update alongside store.json "hours")
$hoursSchemaJson = ($store.hoursSchema | ForEach-Object { '"' + $_ + '"' }) -join ", "

$statementHeading = Encode-Html $store.statementHeading
$statementBody    = Encode-Html $store.statementBody
$galleryCaption   = Encode-Html $store.galleryCaption

# ---- Hours rows ----
$hoursRows = New-Object System.Text.StringBuilder
foreach ($h in $store.hours) {
  $days  = Encode-Html $h.days
  $open  = Encode-Html $h.open
  $close = Encode-Html $h.close
  [void]$hoursRows.AppendLine("          <tr><th scope=`"row`">$days</th><td>$open &ndash; $close</td></tr>")
}

# ---- Ticker ----
# The track holds FOUR identical copies of the phrase list and the CSS
# animation translates by exactly one copy (-25%), looping seamlessly. Four,
# not two: the shifted track must still cover the widest viewport (one copy
# is ~1400px, so two copies left a growing blank gap on wide screens right
# before each reset). Duplicate copies are aria-hidden so screen readers
# only announce the phrases once.
$tickerOnce = New-Object System.Text.StringBuilder
foreach ($t in $store.ticker) {
  $tx = Encode-Html $t
  [void]$tickerOnce.AppendLine("        <span class=`"ticker__item`">$tx</span>")
}
$tickerCopy = $tickerOnce.ToString()

# ---- Gallery ----
# Any image dropped into assets/gallery/ is picked up automatically, in
# filename order. With none supplied, render labelled placeholder tiles so the
# layout still reads correctly.
$galleryDir  = Join-Path $root "assets\gallery"
$galleryHtml = New-Object System.Text.StringBuilder
$galleryCount = 0
if (Test-Path $galleryDir -PathType Container) {
  $files = Get-ChildItem -Path $galleryDir -File |
           Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|webp)$' } |
           Sort-Object Name
  foreach ($f in $files) {
    $galleryCount++
    # Stagger class is baked in per item (not nth-child) so the slideshow's
    # cloned copy always matches the original - keeps the loop seamless even
    # with an odd number of photos.
    $cls = "gallery__item"
    if ($galleryCount % 2 -eq 0) { $cls = "gallery__item gallery__item--low" }
    $rel = "assets/gallery/" + $f.Name
    $alt = Encode-Html ("The Original Buscemi's " + $store.city + " - photo " + $galleryCount)
    [void]$galleryHtml.AppendLine("        <li class=`"$cls`"><img src=`"$rel`" alt=`"$alt`" loading=`"lazy`"></li>")
  }
}
if ($galleryCount -eq 0) {
  for ($i = 1; $i -le 5; $i++) {
    $cls = "gallery__item"
    if ($i % 2 -eq 0) { $cls = "gallery__item gallery__item--low" }
    [void]$galleryHtml.AppendLine("        <li class=`"$cls`"><div class=`"gallery__item--empty`">Photo $i<br>drop a file in assets/gallery</div></li>")
  }
}

# ---- Hero photo ----
$heroImg = FindImage "assets/hero"
if ($heroImg) {
  $heroAlt = Encode-Html ("The Original Buscemi's " + $store.city + " " + $store.neighborhood)
  $heroMedia = "<div class=`"hero__media`"><img src=`"$heroImg`" alt=`"$heroAlt`" fetchpriority=`"high`"></div>"
} else {
  $heroMedia = "<div class=`"hero__media hero__media--empty`" aria-hidden=`"true`"></div>"
}

# ---- Footer "Follow" column (only when an Instagram URL is set) ----
if ([string]::IsNullOrWhiteSpace($store.instagramUrl)) {
  $followCol = ""
} else {
  $followCol = @"
        <div class="site-footer__col">
          <h2><a href="$igUrl" target="_blank" rel="noopener">Follow</a></h2>
          <ul>
            <li><a href="$igUrl" target="_blank" rel="noopener">Instagram</a></li>
          </ul>
        </div>
"@
}

$indexBody = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Original Buscemi's - Hall Road, Utica</title>
  <meta name="description" content="The Original Buscemi's at $address in $cityState. Italian Torpedo subs, Detroit-style pizza, and Party Shoppe favorites since 1956. Call $phone.">
  <link rel="canonical" href="$siteUrl/">
  <link rel="icon" type="image/png" sizes="144x144" href="assets/favicon.png">
  <link rel="apple-touch-icon" href="assets/favicon.png">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="The Original Buscemi's">
  <meta property="og:title" content="Original Buscemi's - Hall Road, Utica">
  <meta property="og:description" content="Italian Torpedo subs, Detroit-style pizza, and Party Shoppe favorites since 1956. $address, $cityState.">
  <meta property="og:url" content="$siteUrl/">
  <meta property="og:image" content="$siteUrl/assets/og-logo.png">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:image" content="$siteUrl/assets/og-logo.png">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Restaurant",
    "name": "The Original Buscemi's",
    "url": "$siteUrl/",
    "image": "$siteUrl/assets/og-logo.png",
    "logo": "$siteUrl/assets/og-logo.png",
    "telephone": "$tel",
    "servesCuisine": ["Pizza", "Italian", "Sandwiches"],
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "$address",
      "addressLocality": "$city",
      "addressRegion": "MI",
      "postalCode": "48317",
      "addressCountry": "US"
    },
    "openingHours": [$hoursSchemaJson],
    "foundingDate": "1956"
  }
  </script>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@700;900&family=Archivo:wght@400;500;600;700&display=swap">
  <link rel="stylesheet" href="css/styles.css">
</head>
<body>

  <a class="skip-link" href="#main">Skip to content</a>

  <header class="site-header">
    <div class="container site-header__inner">
      <a class="site-header__logo" href="#top" aria-label="The Original Buscemi's home">
        <img src="assets/logo-lockup-red.png" alt="The Original Buscemi's Party Shoppe Pizza">
      </a>
      <div class="site-header__actions">
        <button class="btn btn--primary" type="button" data-nav-toggle aria-expanded="false" aria-controls="nav-panel">Menu</button>
        <a class="btn btn--outline" href="$orderUrl" target="_blank" rel="noopener">Order Online</a>
      </div>
    </div>
  </header>

  <div class="nav-panel" id="nav-panel" data-nav data-open="false" role="dialog" aria-modal="true" aria-label="Site navigation">
    <button class="nav-panel__close" type="button" data-nav-close aria-label="Close menu">&times;</button>
    <nav>
      <ul class="nav-panel__list">
        <li><a href="$menuUrl" target="_blank" rel="noopener">Menu</a></li>
        <li><a href="#story" data-nav-link>Our Story</a></li>
        <li><a href="#visit" data-nav-link>Visit</a></li>
        <li><a href="#hours" data-nav-link>Hours</a></li>
        <li><a href="#reviews" data-nav-link>Reviews</a></li>
        <li><a href="$orderUrl" target="_blank" rel="noopener">Order Online</a></li>
      </ul>
      <p class="nav-panel__meta">$address &middot; $cityState &middot; $phone</p>
    </nav>
  </div>

  <main id="main">

  <section class="hero" id="top">
    $heroMedia
    <div class="container hero__inner">
      <img class="hero__mark" src="assets/logo.png" alt="The Original Buscemi's">
      <div class="hero__actions">
        <a class="btn btn--primary btn--lg" href="$orderUrl" target="_blank" rel="noopener">Order Online</a>
        <a class="btn btn--on-dark btn--lg" href="tel:$tel">Call $phone</a>
      </div>
    </div>
  </section>

  <div class="ticker">
    <div class="ticker__track">
      <div class="ticker__group">
$tickerCopy
      </div>
      <div class="ticker__group" aria-hidden="true">
$tickerCopy
      </div>
      <div class="ticker__group" aria-hidden="true">
$tickerCopy
      </div>
      <div class="ticker__group" aria-hidden="true">
$tickerCopy
      </div>
    </div>
  </div>

  <section class="statement" id="story">
    <div class="statement__prints" aria-hidden="true">
      <figure class="statement__print statement__print--left">
        <img src="assets/story/history-1.avif" alt="" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--right">
        <img src="assets/story/history-2.avif" alt="" loading="lazy">
      </figure>
    </div>
    <div class="container container--narrow">
      <img class="statement__mark" src="assets/logo-shield.png" alt="" aria-hidden="true">
      <span class="eyebrow">Our Story</span>
      <h1 class="statement-title">$statementHeading</h1>
      <p class="statement__body">$statementBody</p>
      <a class="btn btn--primary btn--lg" href="$menuUrl" target="_blank" rel="noopener">View Menu</a>
    </div>
  </section>

  <section class="gallery">
    <div class="container">
      <div class="gallery__head">
        <div>
          <span class="eyebrow">$galleryCaption</span>
          <h2 class="section-title">On Hall Road</h2>
        </div>
      </div>
      <ul class="gallery__track" data-gallery-track>
$($galleryHtml.ToString())
      </ul>
    </div>
  </section>

  <section class="section" id="visit">
    <div class="container visit__inner">
      <div class="visit__info">
        <span class="eyebrow">Find Us</span>
        <h2 class="section-title">Stop in.</h2>
        <hr class="rule rule--left">
        <dl class="visit__details">
          <div>
            <dt>Address</dt>
            <dd>$address<br>$cityState</dd>
          </div>
          <div>
            <dt>Phone</dt>
            <dd><a href="tel:$tel">$phone</a></dd>
          </div>
        </dl>
        <div class="visit__actions">
          <a class="btn btn--primary" href="https://www.google.com/maps/search/?api=1&amp;query=$mapQuery" target="_blank" rel="noopener">Get Directions</a>
          <a class="btn btn--outline" href="tel:$tel">Call Store</a>
        </div>

        <div class="visit__reviews" id="reviews">
          <span class="eyebrow">What our customers say</span>
          <div class="reviews__rating" role="img" aria-label="Rated $ratingStr out of 5 stars from $reviewCount Google reviews">
            <div class="reviews__stars">
              <span class="reviews__stars-empty" aria-hidden="true">&#9733;&#9733;&#9733;&#9733;&#9733;</span>
              <span class="reviews__stars-fill" aria-hidden="true" style="width: $ratingPct%;">&#9733;&#9733;&#9733;&#9733;&#9733;</span>
            </div>
            <div class="reviews__numbers">
              <span class="reviews__rating-value">$ratingStr</span>
              <span class="reviews__rating-of">/ 5</span>
              <span class="reviews__count">$reviewCount Google reviews</span>
            </div>
          </div>
          <p class="reviews__copy">Decades of regulars and counting. Loved your visit? Tell Google and help your neighbors find us.</p>
          <div class="reviews__actions">
            <a class="btn btn--primary" href="$reviewUrl" target="_blank" rel="noopener">Leave a Google Review</a>
            <a class="btn btn--outline" href="$listingUrl" target="_blank" rel="noopener">Read Reviews</a>
          </div>
        </div>
      </div>
      <div class="visit__side">
        <div class="visit__map">
          <iframe
            src="https://www.google.com/maps?q=$mapQuery&amp;output=embed"
            loading="lazy"
            referrerpolicy="no-referrer-when-downgrade"
            title="Map of The Original Buscemi's $city &mdash; $nbhd"></iframe>
        </div>
        <div class="visit__hours" id="hours">
          <span class="eyebrow">When we're open</span>
          <table class="hours__table hours__table--left">
            <tbody>
$($hoursRows.ToString())
            </tbody>
          </table>
          <p class="hours__note hours__note--left">Holiday hours may vary &mdash; please call ahead to confirm.</p>
        </div>
      </div>
    </div>
  </section>

  </main>

  <footer class="site-footer">
    <div class="container">
      <div class="site-footer__top">
        <div class="site-footer__brand">
          <img src="assets/logo.png" alt="The Original Buscemi's">
        </div>
        <div class="site-footer__col">
          <h2><a href="#visit">Contact</a></h2>
          <ul>
            <li><a href="tel:$tel">Call the store</a></li>
            <li><a href="https://www.google.com/maps/search/?api=1&amp;query=$mapQuery" target="_blank" rel="noopener">Directions</a></li>
          </ul>
        </div>
        <div class="site-footer__col">
          <h2><a href="$menuUrl" target="_blank" rel="noopener">Menu</a></h2>
          <ul>
            <li><a href="$orderUrl" target="_blank" rel="noopener">Order Online</a></li>
            <li><a href="$menuUrl" target="_blank" rel="noopener">See the full menu</a></li>
          </ul>
        </div>
$followCol
      </div>

      <div class="site-footer__contact-lines">
        <p><a href="tel:$tel">Call Us: $phone</a></p>
        <p>$address, $cityState</p>
      </div>

      <p class="site-footer__meta">&copy; 2026 The Original Buscemi&rsquo;s &middot; Serving Michigan since 1956</p>
    </div>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>
"@

WriteUtf8 $indexPath $indexBody
if ($galleryCount -eq 0) {
  Write-Host "[note] No gallery photos found - rendered 5 placeholder tiles. Drop images into assets/gallery/."
} else {
  Write-Host "[ok] Gallery: $galleryCount photo(s)."
}
if (-not $heroImg) {
  Write-Host "[note] No hero photo found - rendered the striped fallback. Add assets/hero.jpg."
}
Write-Host "[ok] Wrote index.html for $city -- $nbhd"
