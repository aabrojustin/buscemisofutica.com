# Original Buscemi's - Utica Hall Road site generator
# Reads data/store.json and writes index.html.
# Run: powershell -ExecutionPolicy Bypass -File scripts\generate.ps1

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

# Returns the inner HTML for a menu card's media area.
# If a photo exists at assets/menu/<slug>.<ext>, render <img>.
# Otherwise, render the letter-placeholder fallback.
function MenuMedia([string]$slug, [string]$letter, [string]$alt) {
  $exts = @("jpg", "jpeg", "png", "webp")
  foreach ($ext in $exts) {
    $rel = "assets/menu/$slug.$ext"
    $abs = Join-Path $root ($rel -replace '/', '\')
    if (Test-Path $abs -PathType Leaf) {
      $altEnc = Encode-Html $alt
      return "<img src=`"$rel`" alt=`"$altEnc`" loading=`"lazy`">"
    }
  }
  return "<span class=`"menu-card__icon`">$letter</span>"
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
$rating     = $store.rating
$reviewCount= Encode-Html $store.reviewCount
$reviewUrl  = Encode-Html $store.googleReviewUrl
$listingUrl = Encode-Html $store.googleListingUrl
$ratingPct  = [math]::Round(($rating / 5) * 100, 1)
$ratingStr  = ([string]$rating).TrimEnd('0').TrimEnd('.')
if ([string]::IsNullOrEmpty($ratingStr)) { $ratingStr = [string]$rating }
# Always show one decimal for ratings (e.g. 4.7 not 4)
if ($ratingStr -notmatch '\.') { $ratingStr = "$ratingStr.0" }

# Build hours rows
$hoursRows = New-Object System.Text.StringBuilder
foreach ($h in $store.hours) {
  $days  = Encode-Html $h.days
  $open  = Encode-Html $h.open
  $close = Encode-Html $h.close
  [void]$hoursRows.AppendLine("          <tr><th scope=`"row`">$days</th><td>$open &ndash; $close</td></tr>")
}

# Resolve menu media (image-or-letter fallback)
$mediaTorpedo  = MenuMedia "torpedo"      "T" "Torpedo subs"
$mediaPizza    = MenuMedia "pizza"        "P" "Detroit-style square pizza"
$mediaShoppe   = MenuMedia "party-shoppe" "B" "Buscemi's Party Shoppe"
$mediaCatering = MenuMedia "catering"     "C" "Catering trays"

$indexBody = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>The Original Buscemi's &mdash; $city, $nbhd</title>
  <meta name="description" content="The Original Buscemi's at $address in $cityState. Italian Torpedo subs, Detroit-style pizza, and Party Shoppe favorites since 1956. Call $phone.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap">
  <link rel="stylesheet" href="css/styles.css">
</head>
<body>

  <header class="site-header">
    <div class="container site-header__inner">
      <a class="site-header__logo" href="#top" aria-label="The Original Buscemi's home">
        <img src="assets/logo.png" alt="The Original Buscemi's Party Shoppe Pizza">
      </a>
      <button class="nav-toggle" type="button" data-nav-toggle aria-expanded="false" aria-controls="primary-nav">
        <span aria-hidden="true">&#9776;</span>
        <span class="sr-only">Menu</span>
      </button>
      <nav class="site-nav" id="primary-nav" data-nav data-open="false" aria-label="Primary">
        <ul class="site-nav__list">
          <li><a href="#menu">Menu</a></li>
          <li><a href="#about">About</a></li>
          <li><a href="#visit">Visit</a></li>
          <li><a href="#hours">Hours</a></li>
          <li><a href="#reviews">Reviews</a></li>
          <li><a class="site-nav__cta" href="$orderUrl" target="_blank" rel="noopener">Order Online</a></li>
        </ul>
      </nav>
    </div>
  </header>

  <section class="hero hero--store" id="top">
    <div class="container hero__inner">
      <span class="hero__eyebrow">The Original &middot; Since 1956</span>
      <h1 class="hero__title">$city $nbhd</h1>
      <hr class="hero__divider">
      <p class="hero__subtitle">Family-recipe Italian Torpedo&reg; subs, square Detroit-style pizza, and a full Party Shoppe &mdash; right here at $address.</p>
      <div class="hero__actions">
        <a class="btn btn--primary" href="$orderUrl" target="_blank" rel="noopener">Order Online</a>
        <a class="btn btn--ghost-on-dark" href="tel:$tel">Call $phone</a>
      </div>
    </div>
  </section>

  <section class="welcome" id="about">
    <div class="container welcome__inner">
      <div class="welcome__copy">
        <span class="section-eyebrow">Our Story</span>
        <h2 class="section-title">Seventy years on the corner.</h2>
        <hr class="section-divider">
        <p>It started in 1956 when Paul A. Buscemi opened a small party store in Detroit and introduced the Italian submarine sandwich to the neighborhood &mdash; the now-legendary <strong>Torpedo&reg;</strong>. Three generations later, our Utica shop on Hall Road keeps the same family recipes, the same fresh-baked rolls, and the same easy stop-in for a hot pizza, a cold six-pack, and everything in between.</p>
        <p>You don't have to drive far for the original. You just have to walk in.</p>
      </div>
      <aside class="welcome__card">
        <div class="welcome__card-mark">est. 1956</div>
        <p class="welcome__card-text">Family-owned. Three generations. One Hall Road.</p>
      </aside>
    </div>
  </section>

  <section class="menu-highlights" id="menu">
    <div class="container">
      <span class="section-eyebrow">What we're known for</span>
      <h2 class="section-title">The Buscemi's Menu</h2>
      <hr class="section-divider">
      <div class="menu-grid">

        <article class="menu-card menu-card--torpedo">
          <div class="menu-card__media">$mediaTorpedo</div>
          <div class="menu-card__body">
            <h3 class="menu-card__title">Torpedo&reg; Subs</h3>
            <p class="menu-card__copy">Our 1956 original. Italian cold cuts piled on a fresh-baked Italian roll with lettuce, tomato, onion, oil &amp; vinegar. Available as a half, a full, or party-tray sized.</p>
          </div>
        </article>

        <article class="menu-card menu-card--pizza">
          <div class="menu-card__media">$mediaPizza</div>
          <div class="menu-card__body">
            <h3 class="menu-card__title">Detroit Square Pizza</h3>
            <p class="menu-card__copy">Crispy-edged Detroit-style pan pizza, hand-stretched, topped daily, and finished with a stripe of red sauce on top. Hot and ready or call ahead.</p>
          </div>
        </article>

        <article class="menu-card menu-card--shoppe">
          <div class="menu-card__media">$mediaShoppe</div>
          <div class="menu-card__body">
            <h3 class="menu-card__title">Party Shoppe</h3>
            <p class="menu-card__copy">Liquor, beer, wine, snacks, and grocery essentials &mdash; everything you need for game night, all under one roof.</p>
          </div>
        </article>

        <article class="menu-card menu-card--catering">
          <div class="menu-card__media">$mediaCatering</div>
          <div class="menu-card__body">
            <h3 class="menu-card__title">Catering &amp; Trays</h3>
            <p class="menu-card__copy">Torpedo trays, pizza, salad, and dessert platters for parties, offices, and events of any size. Call $phone to plan.</p>
          </div>
        </article>

      </div>
      <div class="menu-cta">
        <a class="btn btn--primary" href="$menuUrl" target="_blank" rel="noopener">See Full Menu</a>
      </div>
    </div>
  </section>

  <section class="visit" id="visit">
    <div class="container visit__inner">
      <div class="visit__info">
        <span class="section-eyebrow">Find Us</span>
        <h2 class="section-title section-title--left">Stop in.</h2>
        <hr class="section-divider section-divider--left">
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
          <a class="btn btn--ghost" href="tel:$tel">Call Store</a>
        </div>
      </div>
      <div class="visit__map">
        <iframe
          src="https://www.google.com/maps?q=$mapQuery&amp;output=embed"
          loading="lazy"
          referrerpolicy="no-referrer-when-downgrade"
          title="Map of The Original Buscemi's $city &mdash; $nbhd"></iframe>
      </div>
    </div>
  </section>

  <section class="reviews" id="reviews">
    <div class="container">
      <span class="section-eyebrow">What our customers say</span>
      <h2 class="section-title">$ratingStr Stars on Google</h2>
      <hr class="section-divider">

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
        <a class="btn btn--ghost" href="$listingUrl" target="_blank" rel="noopener">Read Reviews</a>
      </div>
    </div>
  </section>

  <section class="hours" id="hours">
    <div class="container">
      <span class="section-eyebrow">When we're open</span>
      <h2 class="section-title">Hours</h2>
      <hr class="section-divider">
      <table class="hours__table">
        <tbody>
$($hoursRows.ToString())
        </tbody>
      </table>
      <p class="hours__note">Holiday hours may vary &mdash; please call ahead to confirm.</p>
    </div>
  </section>

  <footer class="site-footer">
    <div class="container site-footer__inner">
      <div class="site-footer__brand">
        <img src="assets/logo.png" alt="The Original Buscemi's">
      </div>
      <div class="site-footer__contact">
        <p><strong>$city &middot; $nbhd</strong></p>
        <p>$address<br>$cityState</p>
        <p><a href="tel:$tel">$phone</a></p>
      </div>
      <ul class="site-footer__nav">
        <li><a href="#menu">Menu</a></li>
        <li><a href="#about">About</a></li>
        <li><a href="#visit">Visit</a></li>
        <li><a href="#hours">Hours</a></li>
        <li><a href="#reviews">Reviews</a></li>
        <li><a href="$orderUrl" target="_blank" rel="noopener">Order Online</a></li>
      </ul>
      <p class="site-footer__meta">&copy; 2026 The Original Buscemi&rsquo;s &middot; Serving Michigan since 1956</p>
    </div>
  </footer>

  <script src="js/main.js"></script>
</body>
</html>
"@

WriteUtf8 $indexPath $indexBody
Write-Host "[ok] Wrote index.html for $city -- $nbhd"
