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
# Raw (un-HTML-encoded) URLs for JSON-LD - inside <script> blocks, entities
# like &amp; are NOT decoded, so encoded URLs would be corrupted there.
$menuUrlRaw    = $store.menuUrl
$listingUrlRaw = $store.googleListingUrl

# openingHoursSpecification blocks from store.json "hoursSpec" (Google's
# documented format for LocalBusiness - update alongside "hours").
$hoursSpecParts = foreach ($h in $store.hoursSpec) {
  $days = ($h.days | ForEach-Object { '"' + $_ + '"' }) -join ", "
  "{ `"@type`": `"OpeningHoursSpecification`", `"dayOfWeek`": [$days], `"opens`": `"$($h.opens)`", `"closes`": `"$($h.closes)`" }"
}
$hoursSpecJson = $hoursSpecParts -join ",`n      "

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
  # Intrinsic pixel dimensions per photo (keyed by filename) so every <img>
  # ships width/height attributes - stops layout shift while images load
  # (Core Web Vitals). Measured once per file; add a row when adding a photo.
  # Unknown files simply omit the attributes.
  $dimsMap = @{
    "02-round-pizza.png"        = @(243, 244)
    "04-round-pizza-box.webp"   = @(382, 510)
    "05-pepperoni-sunlight.webp" = @(382, 510)
    "06-bacon-pepperoni.webp"   = @(382, 510)
    "07-cheese-bread-tray.webp" = @(236, 510)
    "08-cheese-pizza.webp"      = @(382, 510)
    "09-calzones.webp"          = @(382, 510)
    "10-pepperoni-peel.webp"    = @(382, 510)
    "11-detroit-square.webp"    = @(680, 510)
    "12-mixed-pies.webp"        = @(382, 510)
    "13-detroit-closeup.webp"   = @(382, 510)
    "14-slices-box.webp"        = @(680, 510)
  }
  # Descriptive alt text per photo (keyed by filename) - tells search engines
  # and screen readers what each shot actually shows. Falls back to a generic
  # line for any photo not in the map.
  $altMap = @{
    "02-round-pizza"      = "Round sausage and pepperoni pizza from The Original Buscemi's"
    "04-round-pizza-box"  = "Buscemi's round pepperoni and sausage pizza in a takeout box"
    "05-pepperoni-sunlight" = "Buscemi's round pepperoni pizza in the box"
    "06-bacon-pepperoni"  = "Bacon and pepperoni pizza slices from Buscemi's"
    "07-cheese-bread-tray" = "Tray of Buscemi's cheese bread"
    "08-cheese-pizza"     = "Buscemi's round cheese pizza with a side of ranch"
    "09-calzones"         = "Fresh baked Buscemi's calzones wrapped in foil"
    "10-pepperoni-peel"   = "Sliced pepperoni pizza on the peel at Buscemi's"
    "11-detroit-square"   = "Detroit-style square pepperoni pizza in a Buscemi's box"
    "12-mixed-pies"       = "Close-up of Buscemi's specialty pizzas"
    "13-detroit-closeup"  = "Detroit-style square pizza with pepperoni from Buscemi's"
    "14-slices-box"       = "Buscemi's pizza slices in a takeout box"
  }
  foreach ($f in $files) {
    $galleryCount++
    # Stagger class is baked in per item (not nth-child) so the slideshow's
    # cloned copy always matches the original - keeps the loop seamless even
    # with an odd number of photos.
    $cls = "gallery__item"
    if ($galleryCount % 2 -eq 0) { $cls = "gallery__item gallery__item--low" }
    $rel = "assets/gallery/" + $f.Name
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    if ($altMap.ContainsKey($base)) { $altText = $altMap[$base] }
    else { $altText = "The Original Buscemi's " + $store.city + " - photo " + $galleryCount }
    $alt = Encode-Html $altText
    $dims = ""
    if ($dimsMap.ContainsKey($f.Name)) {
      $d = $dimsMap[$f.Name]
      $dims = " width=`"$($d[0])`" height=`"$($d[1])`""
    }
    [void]$galleryHtml.AppendLine("        <li class=`"$cls`"><img src=`"$rel`" alt=`"$alt`"$dims loading=`"lazy`"></li>")
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
  # NOTE: update these dims if the hero photo is ever replaced.
  $heroMedia = "<div class=`"hero__media`"><img src=`"$heroImg`" alt=`"$heroAlt`" width=`"680`" height=`"510`" fetchpriority=`"high`"></div>"
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
  <meta name="theme-color" content="#6E1F1F">
  <link rel="icon" type="image/png" sizes="144x144" href="assets/favicon.png">
  <link rel="apple-touch-icon" sizes="180x180" href="assets/apple-touch-icon.png">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="The Original Buscemi's">
  <meta property="og:title" content="Original Buscemi's - Hall Road, Utica">
  <meta property="og:description" content="Italian Torpedo subs, Detroit-style pizza, and Party Shoppe favorites since 1956. $address, $cityState.">
  <meta property="og:url" content="$siteUrl/">
  <meta property="og:image" content="$siteUrl/assets/og-logo.jpg">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="1200">
  <meta property="og:image:alt" content="The Original Buscemi's logo">
  <meta name="twitter:card" content="summary">
  <meta name="twitter:image" content="$siteUrl/assets/og-logo.jpg">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "Restaurant",
    "name": "The Original Buscemi's",
    "description": "Family-owned pizza and sub shop and Party Shoppe on Hall Road in Utica, Michigan. Detroit-style square pizza, the original Torpedo sub, calzones, cheese bread, and a full liquor, beer, and wine selection since 1956.",
    "url": "$siteUrl/",
    "image": [
      "$siteUrl/assets/seo/food-16x9.jpg",
      "$siteUrl/assets/gallery/11-detroit-square.webp",
      "$siteUrl/assets/seo/food-1x1.jpg"
    ],
    "logo": "$siteUrl/assets/og-logo.jpg",
    "telephone": "$tel",
    "priceRange": "$",
    "menu": "$menuUrlRaw",
    "hasMap": "$listingUrlRaw",
    "sameAs": [
      "$($store.yelpUrl)",
      "$($store.tripadvisorUrl)"
    ],
    "servesCuisine": ["Pizza", "Detroit-style pizza", "Italian", "Sandwiches"],
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "$address",
      "addressLocality": "$city",
      "addressRegion": "MI",
      "postalCode": "48317",
      "addressCountry": "US"
    },
    "geo": {
      "@type": "GeoCoordinates",
      "latitude": $($store.geo.lat),
      "longitude": $($store.geo.lng)
    },
    "openingHoursSpecification": [
      $hoursSpecJson
    ],
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
        <img src="assets/logo-lockup-red.png" alt="The Original Buscemi's Party Shoppe Pizza" width="847" height="328">
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
      <img class="hero__mark" src="assets/logo.png" alt="The Original Buscemi's" width="847" height="328">
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
      <figure class="statement__print statement__print--l1">
        <img src="assets/story/history-1.avif" alt="" width="320" height="301" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--l2">
        <img src="assets/story/history-4.png" alt="" width="224" height="224" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--l3">
        <img src="assets/story/history-5-sketch.png?v=2" alt="" width="312" height="352" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--r1">
        <img src="assets/story/history-2.avif" alt="" width="768" height="768" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--r2">
        <img src="assets/story/history-6-modelt.png?v=2" alt="" width="257" height="178" loading="lazy">
      </figure>
      <figure class="statement__print statement__print--r3">
        <img src="assets/story/history-7-building.png?v=2" alt="" width="340" height="172" loading="lazy">
      </figure>
    </div>
    <div class="container container--narrow">
      <img class="statement__mark" src="assets/logo-shield.png" alt="" aria-hidden="true" width="208" height="322">
      <span class="eyebrow">Our Story</span>
      <h1 class="statement-title">$statementHeading</h1>
      <p class="statement__body">$statementBody</p>
      <a class="btn btn--primary btn--lg" href="$menuUrl" target="_blank" rel="noopener">View Menu</a>
    </div>
  </section>

  <section class="section section--cream section--center" id="detroit-style">
    <div class="container container--narrow">
      <span class="eyebrow">The Square</span>
      <h2 class="section-title">What is Detroit style pizza?</h2>
      <hr class="rule">
      <p class="square__copy">Detroit style pizza is a square, deep pan pizza with a light, airy crumb and a crispy, caramelized cheese edge. The cheese goes all the way to the corners of the steel pan, and the sauce goes on top. That red stripe over the cheese is the signature. It was invented in Detroit in the 1940s, and it is the pizza this family has been baking since 1956.</p>
      <p class="square__copy">Ours is hand stretched and baked fresh every day at $address in Utica, just off M-59 and minutes from Sterling Heights, Shelby Township, and Clinton Township. Grab it hot and ready, or call ahead at <a href="tel:$tel">$phone</a>.</p>

      <div class="faq">
        <h3 class="faq__q">Do you deliver?</h3>
        <p class="faq__a">Yes. Order for delivery or pickup through our <a href="$orderUrl" target="_blank" rel="noopener">online ordering page</a>, or call the store at <a href="tel:$tel">$phone</a>.</p>

        <h3 class="faq__q">What is a Torpedo&reg; sub?</h3>
        <p class="faq__a">The Torpedo is the Italian submarine sandwich Paul A. Buscemi introduced to Detroit in 1956. It stacks Italian cold cuts on a fresh baked roll with lettuce, tomato, onion, and oil &amp; vinegar. It comes as a Baby Sub, a full Torpedo, or a party tray.</p>

        <h3 class="faq__q">Do you sell beer, wine, and liquor?</h3>
        <p class="faq__a">Yes. The Party Shoppe side of the store carries a full selection of liquor, beer, and wine, plus snacks and grocery essentials. One stop for game night.</p>

        <h3 class="faq__q">Do you cater parties and offices?</h3>
        <p class="faq__a">We do. Torpedo trays, party pizzas, salads, and dessert trays for groups of any size. Call <a href="tel:$tel">$phone</a> to plan your order.</p>
      </div>
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

  <section class="section section--cream" id="visit">
    <div class="container visit__inner">
      <div class="visit__info">
        <span class="eyebrow">Find Us</span>
        <h2 class="section-title">Visit Us in Utica, MI</h2>
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
            title="Map of The Original Buscemi's $city, $nbhd"></iframe>
        </div>
        <div class="visit__hours" id="hours">
          <span class="eyebrow">When we're open</span>
          <table class="hours__table hours__table--left">
            <tbody>
$($hoursRows.ToString())
            </tbody>
          </table>
          <p class="hours__note hours__note--left">Holiday hours may vary. Please call ahead to confirm.</p>
        </div>
      </div>
    </div>
  </section>

  </main>

  <footer class="site-footer">
    <div class="container">
      <div class="site-footer__top">
        <div class="site-footer__brand">
          <img src="assets/logo.png" alt="The Original Buscemi's" width="847" height="328">
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

    </div>

    <div class="container">
      <p class="site-footer__meta">&copy; 2026 The Original Buscemi&rsquo;s &middot; Serving Michigan since 1956</p>
    </div>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>
"@

WriteUtf8 $indexPath $indexBody

# ---- sitemap.xml (single-page site; lastmod = generation date) ----
$today = Get-Date -Format "yyyy-MM-dd"
$sitemap = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>$siteUrl/</loc>
    <lastmod>$today</lastmod>
    <changefreq>monthly</changefreq>
  </url>
</urlset>
"@
WriteUtf8 (Join-Path $root "sitemap.xml") $sitemap
if ($galleryCount -eq 0) {
  Write-Host "[note] No gallery photos found - rendered 5 placeholder tiles. Drop images into assets/gallery/."
} else {
  Write-Host "[ok] Gallery: $galleryCount photo(s)."
}
if (-not $heroImg) {
  Write-Host "[note] No hero photo found - rendered the striped fallback. Add assets/hero.jpg."
}
Write-Host "[ok] Wrote index.html for $city -- $nbhd"
