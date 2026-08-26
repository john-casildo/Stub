# Stub — Design System

This is the single source of truth for Stub's visual design. Everything here was
decided and approved in the mockup phase (`mockups.html` in this folder /
published artifact). **Follow this file, and only this file, for anything
visual.** If a new screen or component needs something not covered here, add
it to this doc first, then build it — don't introduce a one-off choice
directly in code.

Reference implementation: `mockups.html` (7 screens: scan, ledger/dashboard,
edit entry, budgets, manual entry, app lock, home-screen widget). When in
doubt about how a rule renders, check that file — it's the working proof of
every rule below.

---

## 1. Typography — exactly three fonts, each with one job

| Font | Role | Never used for |
|---|---|---|
| **Archivo** | The workhorse. All UI text: body copy, field labels, buttons, nav, captions, headings (h2/h3), the "AUGUST" month label on the dashboard/budgets status row. | Numbers, the brand wordmark |
| **Domine** | Reserved *only* for the brand name. The "Stub" wordmark (intro title + the small per-screen brand label), and the widget's "Stub · August" subtitle line. | Anything else — do not use for generic headings |
| **Unbounded** | Reserved *only* for actual currency numbers — applied via the `.mono` class. Hero amounts, transaction/category/budget line amounts, field amount values, the manual-entry big amount display. | Labels, timestamps, hints, receipt mock text, any non-numeric string |

Google Fonts import:
```
family=Archivo:wght@400;500;600;700
family=Domine:wght@400;500;600;700
family=Unbounded:wght@400;500;600;700;800
```

Rule of thumb: **if it's a dollar figure, it's Unbounded. If it's the brand
name, it's Domine. Everything else is Archivo.**

---

## 2. Color tokens

All colors are CSS custom properties, defined three times for full theme
support: default `:root` (light), `@media (prefers-color-scheme: dark)`
(system dark), and `:root[data-theme="dark"]` (explicit user toggle). **All
three blocks must always match** — this file previously had a bug where an
edit only updated two of the three, which silently broke the explicit
dark-mode toggle. Double check all three whenever a color changes.

### Light

| Token | Value | Use |
|---|---|---|
| `--bg` | `#ECE7DC` | App/page background |
| `--bg-weave` | `#E4DECE` | Subtle background gradient texture |
| `--surface` | `#FBF9F3` | Cards |
| `--surface-alt` | `#F3EFE3` | Secondary card surfaces |
| `--ink` | `#211C15` | Primary text |
| `--ink-70` / `--ink-50` / `--ink-30` | opacities of ink | Secondary/tertiary text |
| `--line` | `rgba(33,28,21,.13)` | Hairlines, borders |
| `--accent` | `#0080FF` | Bright blue — data/emphasis only, see §4 |
| `--accent-strong` | `#0060B8` | Gradient's darker stop reference, hover/strong states |
| `--accent-10` / `--accent-18` | tinted accent | Backgrounds behind accent-colored text/tags |
| `--on-accent` | `#F5F9FF` | Text/icons placed on accent-colored fills |
| `--good` | `#4B7A5B` | Green — save/confirm actions, see §4 |
| `--good-10` | tinted | Backgrounds behind green tags/pills |
| `--on-good` | `#F1F6F2` | Text on green fills |
| `--danger` | `#B03A2E` | Red — destructive actions only |
| `--warn` | `#8C6A2F` | Amber — over-budget warning state only |
| `--warn-10` | tinted | reserved, currently unused in shipped screens |
| `--shadow` | `rgba(58,42,18,.20)` | All drop shadows |
| `--phone-body` | `#1B1712` | Phone bezel; also the fixed dark background of the scan screen and lock screen |
| `--grad-pop` | `linear-gradient(135deg, var(--accent) 0%, #00D9B5 100%)` | The one decorative gradient, see §5 |
| `--grad-b-color` | `#00D9B5` | Second gradient stop (kept separate for the SVG `<stop>` use) |

### Dark (both the system-dark and explicit-toggle blocks use these same values)

| Token | Value |
|---|---|
| `--bg` | `#17130F` |
| `--bg-weave` | `#1E1811` |
| `--surface` | `#221B14` |
| `--surface-alt` | `#2B2318` |
| `--ink` | `#F3ECDD` |
| `--line` | `rgba(243,236,221,.14)` |
| `--accent` | `#2E9CFF` |
| `--accent-strong` | `#66B6FF` |
| `--accent-10` / `--accent-18` | tinted accent |
| `--on-accent` | `#00243F` |
| `--good` | `#7FB88F` |
| `--good-10` | tinted |
| `--on-good` | `#10241A` |
| `--danger` | `#E2776A` |
| `--warn` | `#D3A85F` |
| `--shadow` | `rgba(0,0,0,.55)` |
| `--phone-body` | `#0E0C09` |
| `--grad-pop` | `linear-gradient(135deg, var(--accent) 0%, #34F5D0 100%)` |
| `--grad-b-color` | `#34F5D0` |

**`--ink` and `--bg` double as the "black in light mode / white in dark mode"
pair** — used directly (not just for text) on the one secondary button that
needs to invert with theme (see §4).

---

## 3. Semantic color system — three colors, three meanings, never mixed

- 🔵 **Blue (`--accent` / `--grad-pop`)** — data and emphasis *only*. Numbers,
  graphs, the active state of a filter chip. **Never used as a button fill.**
- 🟢 **Green (`--good`)** — confirm/save actions, and the "successfully
  parsed" category pill on the scan screen.
- 🔴 **Red (`--danger`)** — destructive actions only (currently: the Delete
  entry link). Distinct from amber — do not reuse `--warn` for destructive
  actions or vice versa.
- 🟡 **Amber (`--warn`)** — over-budget warning state only (the budget
  progress bar when a category is close to/over its limit).
- ⚫⚪ **Ink/bg pair** — secondary, less-important actions that aren't a
  save/delete/data moment. Solid black in light mode, solid white in dark
  mode, automatically via `var(--ink)` / `var(--bg)`.

---

## 4. Buttons — solid colors, chosen by what the button *does*

| Button | Class | Color | Why |
|---|---|---|---|
| **Add** actions ("Add to ledger") | `.cta` | `--grad-pop` gradient bg, `--on-accent` text | Creating something new — uses the app's main color |
| **Save** actions ("Save changes", "Save entry") | `.cta.save` | Solid `--good` (green) bg, `--on-good` text | Confirming/persisting an edit — distinct from a fresh Add |
| Delete entry | `.danger-link` | `--danger` (red) text, no fill (it's a text link) | Destructive |
| Round scan/"+" nav button | `.tab.scan-btn` | `--grad-pop` gradient bg, `--on-accent` text | Same treatment as Add — launching a scan starts a new entry |
| Lock-screen "Unlock with Face ID" | `.lock-btn` | `--grad-pop` gradient bg, `--on-accent` text | Same rule as everywhere else — the gradient works fine against the screen's fixed-dark `--phone-body` background, since the button's own fill (not the screen bg) needs to follow the theme rule |

**Rule of thumb: Add/scan = blue, Save = green, Delete = red — no
exceptions.** Every button uses one of these three semantic colors; nothing
is neutral (black/white) or hardcoded outside the token system.

**Blue = gradient, always — there is no plain solid blue anywhere in the
app.** Every place blue appears — buttons above, hero numerals, the
progress ring/bars, the active nav-tab label, the scan-confirmation stamp,
the wordmark icon — uses `--grad-pop`, never flat `--accent`. `--accent` /
`--accent-strong` still exist as tokens (the gradient's own stops, tints
like `--accent-10`, and text/icon colors that must stay solid for a
technical reason — see the exceptions below) but never as a plain fill on
their own. Green and red stay solid — the gradient is blue's identity, not
a generic decorative device to spread across every color.

**Two narrow exceptions, both for technical reasons, not taste:**
- The small caption tags on the mockup gallery page ("the peak moment" etc.)
  stay solid blue — these are page chrome describing the mockups, not
  in-app UI, and `background-clip: text` would clip the pill's own
  background along with the text, breaking the shape.
- `.tab.active svg` (the active nav icon) stays solid `--accent-strong` —
  SVG `stroke="currentColor"` resolves against `color`, and the gradient-text
  trick requires `color: transparent`, which would make the icon invisible.
  The adjacent text label still gets the true gradient.

---

## 5. The gradient (`--grad-pop`) — blue's only form, used deliberately

Blue → teal, 135deg. Per §4/§3: **there is no plain solid blue in this app
— every blue element uses this gradient.** It reads as one consistent
device rather than sprawl because it's confined to one hue (blue) and one
job (mark the thing that's bold or interactive), while green/red stay flat.

**Used on:**
- Hero numerals: dashboard/budgets "amount" display, the widget amount, the
  manual-entry big amount display (text, via `background-clip: text`)
- The circular progress ring (`stroke: url(#pop-grad)` — SVG strokes can't
  take a CSS `background-image`, so there's a matching `<linearGradient
  id="pop-grad">` def once in the page, with `.grad-a`/`.grad-b` `<stop>`
  classes reading the same `--accent` / `--grad-b-color` tokens so it stays
  theme-aware)
- The budget progress bar, *except* the over-budget state (that one stays
  solid `--warn` amber — a warning shouldn't be dressed up decoratively)
- The active category filter chip, the active nav-tab label
- The scan-confirmation "stamp" icon
- The wordmark's small icon mark, and the app icon on the home-screen widget
  mockup
- Every blue button: `.cta` (Add), `.tab.scan-btn`, `.lock-btn` (§4)

**Not used on:** `.cta.save` (green) or `.danger-link` (red) — the gradient
is blue's identity, not a treatment for other colors. Transaction/category/
budget *list* amounts stay plain `--ink` colored Unbounded text — only the
one "hero" number per screen gets the gradient, keeping it a per-screen
"bold moment" rather than every number gradiented. The two technical
exceptions in §4 (gallery caption tags, the active nav icon) stay solid for
rendering reasons, not as a style choice.

---

## 6. Layout conventions

- 8px-ish spacing grid throughout (8/12/14/16/18/20/22/24…)
- Card radius: 16–24px depending on card size; small chips/tags use 3px
  (deliberately sharper — ledger/paper feel, not soft app-default rounding)
- Phone mock frame: 300×624px, 42px outer radius, 12px bezel padding
- One card style per context: `.photo`-adjacent surfaces use `--surface` +
  `--line` borders + `--shadow`-based soft shadows, never hard/pure-black
  shadows

---

## 7. Logo mark — the torn stub + check

**Chosen, final.** Explored four directions in a separate concept pass
(`logo-concepts.html`, published as artifact "Stub Marks") — torn stub,
torn stub + check, perforated edge, and an abstract monogram. **Torn stub +
check** is the one to use everywhere: the app icon, the wordmark's small
mark, splash screens, favicons.

**Why**: it's a literal, honest match for the name (no explaining required,
unlike the monogram), and it ties the mark directly to the app's one
signature moment — the scan-confirmation checkmark from the scan screen —
rather than being a decorative shape unrelated to what the app does.

**Geometry** (defined once as CSS in the mockup, and again as a Flutter
`CustomPainter` — `lib/widgets/stub_logo.dart` — both must stay in sync if
either changes):
- Base shape: a square with a straight right/bottom/most-of-left edge, and a
  5-tooth jagged "torn" cut along the left edge. As a `clip-path` polygon on
  a 0–100% square: `100% 0, 100% 100%, 0 100%, 9.6% 83.3%, 0 66.6%, 9.6% 50%,
  0 33.3%, 9.6% 16.6%, 0 0`. Sharp corners on the other three sides — no
  border-radius (rounding fights the torn-paper read).
- Fill: `--grad-pop` (the one decorative gradient, §5) — this is one of the
  handful of places the gradient is intentionally allowed outside a hero
  numeral.
- Checkmark: a simple 3-point stroke inside the shape, `M30 50 L44 64 L70
  34` on a 96×96 reference box, stroke color `--on-accent`, stroke width
  ~8% of the box size, round caps/joins.

**Do not regenerate this shape from scratch in a new context** (a new
screen, an app-icon export, a marketing asset) — reuse `StubLogo` or copy
the exact polygon/path values above, so the mark stays pixel-consistent
everywhere it appears.

---

## 8. Icons — Tabler Icons

**Library: [Tabler Icons](https://tabler.io/icons)** (MIT licensed, free for
commercial use, works on every platform — web, React Native, and native iOS
via SVG). One of the largest free icon sets available (4,000+), stroke-based
style (2px stroke, round caps and joins, 24×24 grid) — same visual language
as the hand-drawn line icons used elsewhere in the app, no visual reset
needed. We evaluated Lucide first and switched to Tabler for the larger
library size at the same license/style tradeoffs.

Two things worth knowing when picking a different icon if one isn't in this
table:
- **Alternative if Tabler doesn't have what you need**: [Phosphor
  Icons](https://phosphoricons.com) — also free/MIT, offers multiple weights
  per icon (thin/light/regular/bold/fill/duotone), which Tabler's outline set
  doesn't (Tabler does have a separate filled icon set, `icons-tabler-filled`,
  worth checking before reaching for Phosphor). [Lucide](https://lucide.dev)
  remains a fine fallback too — nearly identical visual style, smaller set.
- **We explicitly do not use raw emoji as UI icons** (🧾💸🏦 were the
  original placeholder for the transaction-source badges — replaced with real
  icons). Emoji render inconsistently across platforms and read as
  unfinished/prototype, not shipped product.

| UI element | Tabler icon | Notes |
|---|---|---|
| App-lock padlock | `lock` | |
| Edit-field pencil affordance | `pencil` | |
| Close ("×") button | `x` | |
| Receipt-scan transaction source badge | `receipt-2` | |
| Payment-app-screenshot transaction source badge | `cash-banknote` | |
| Bank-screenshot transaction source badge | `building-bank` | |
| Bottom nav — Home/Board | `home` | |
| Bottom nav — scan/capture button | `camera` | icon only, no label, round button |
| Bottom nav — Insights/Budgets | `chart-bar` | |
| Bottom nav — Profile | `user-circle` | |

If a new screen needs an icon not listed here, pull it from Tabler first —
check `tabler.io/icons` for the exact icon name, then fetch the real SVG
(e.g. `https://unpkg.com/@tabler/icons@latest/icons/outline/<name>.svg`)
rather than hand-drawing an approximation, so it stays pixel-consistent with
the rest. Tabler's raw SVG includes an invisible `M0 0h24v24H0z` background
path used only as a click hit-area helper — drop it when inlining, it has no
visual effect and isn't needed here.

**Not used: SF Symbols.** Considered since this may end up a native iOS app —
SF Symbols would be the more "correct" native choice — but Apple doesn't
license SF Symbols for embedding in a browser-based mockup, so Tabler is what
the mockup actually uses. If the build ends up native iOS/SwiftUI, it's
reasonable to swap to SF Symbols equivalents at that point (most of the icons
above have a close SF Symbols match — `lock.fill`, `pencil`,
`building.columns`, etc.) — but that's a decision to make explicitly when the
platform is locked in, not something to assume.

---

## 9. Screens shipped so far

Scan (capture + confirm), Ledger/Dashboard, Edit entry, Budgets, Manual
entry, App lock, Home-screen widget. Any new screen should reuse existing
components (`.cta`, `.chip`, `.field-row`, `.bar-fill`, `.photo`/card
patterns) before inventing new ones.
