# 10shots — App Store Screenshots (final set)

5 screenshots, iPhone 6.9″ (1320×2868, RGB, no alpha). Dark/black, real app UI.

## Source & processing
- Design masters: `~/Pictures/10ShotsScreenshots/*.png` at 3960×8604 (3× the 6.9″ canvas, with alpha).
- Repo set: `Docs/launch/screenshots/` — downscaled to **1320×2868** (LANCZOS, identical aspect ratio, no crop) and **flattened onto black** to remove the alpha channel (Apple rejects alpha).
- To reprocess after a new master drop: resize to 1320×2868 + composite on `#000` (Pillow).

## ASO note
Screenshots are not keyword-indexed (that's the App Store name/subtitle/keyword
field — see `APP_STORE_COPY.md`). These optimise tap-through; slides 1–3 show in
search results, so the concept ("disposable camera") lands on slide 1.

## The set

| # | Name | Headline | Sub |
|---|------|----------|-----|
| 1 | Cover | **10Shots** (wordmark) | *Your shared disposable camera.* — footer: 10 SHOTS · NO RETAKES · REVEALED TOGETHER |
| 2 | Lobby | **Everyone gets 10 shots.** | Tap in. Watch the dots fill. |
| 3 | Camera | **No previews. No retakes.** | Point. Shoot. Trust the moment. |
| 4 | Reveal | **The whole roll. Together.** | Develops overnight. Reveals when everyone's done. |
| 5 | Create | **Start a roll for any night.** | Name it. Share a code. Go. |

## Narrative arc
Concept hook (1) → the core mechanic (2) → the differentiator/pain (3) →
the emotional payoff (4) → the low-friction CTA (5). One idea per slide,
3–5 word headlines, readable in a second.
