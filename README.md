# Sonex

**A native iOS app that turns a vinyl collection into a tappable, tradeable, livable archive — built for USC's 2026 Integrated Design, Business & Technology capstone, in partnership with GotVinylNYC.**

Sonex pairs an NFC-tagged "Spin Tag" sticker with every record in a collector's crate. Tap the tag and the record's full identity — pressing, condition grade, market value, ownership history — comes up instantly, on or off the app. Underneath that single gesture sits a full cataloging, valuation, and discovery system built for the people who actually live in record stores: collectors, curators, and consignors.

The product was stress-tested live at a Record Store Day activation with GotVinylNYC, run by a three-person team: Ricardo Payares (Technical Lead), Calvin (Product/Design Lead), and Jasmine Louie (Marketing Lead).

---

## What it does

**Catalog a record three ways.** Tap a blank NFC Spin Tag to start a new entry, snap a photo of the sleeve and let on-device Vision OCR plus a Gemini-powered suggestion engine identify the artist and album, or search Discogs directly. Whichever path you start from, the record resolves to the same registration flow — search results, Goldmine-standard grading (separate scores for media and sleeve, each with its own valuation multiplier), and a Discogs-sourced market price you can adjust before it's written into your crate.

**Browse your crates like you'd flip through a milk crate.** Each crate renders as a swipeable card stack with drag-to-flip physics, a tap-through to full album detail, and a grid mode for batch-selecting records to move between crates. Cover art is cached locally so the stack stays smooth scrolling through fifty-plus records.

**Discover what's happening nearby.** A MapKit-based Discover tab plots collection listings and community events as pins, filterable by post type, with RSVP support and a posting flow for sharing what's in your crate or what's coming up at your shop.

**See your collection as a profile.** Stats, crate summaries, a following system (request → accept/block, not just mutual friends), and discover-post history live in a dedicated profile tab.

**Work offline, sync later.** A dedicated offline cache manager persists crates, vinyl entries, user profile data, and cover art locally, queues pending writes while offline, and reconciles them once connectivity returns — not a bolt-on, but a parallel data path alongside the live Supabase queries.

Exchange — peer-to-peer trading with QR-confirmed handoff — is scaffolded as the fifth tab and is the next major build target; see Implementation Status below.

---

## Screenshots

<img width="201" height="437" alt="1" src="https://github.com/user-attachments/assets/4b5c7bf8-5cf7-4364-a46c-4ca78628ba24" />
<img width="201" height="437" alt="2" src="https://github.com/user-attachments/assets/9faea51e-a29b-4812-a940-f066e16366fd" />
<img width="201" height="437" alt="3" src="https://github.com/user-attachments/assets/5e942c27-754c-4e5f-9c4e-aa3d777a8e5a" />
<img width="201" height="437" alt="4" src="https://github.com/user-attachments/assets/5f7b914c-21bb-4d20-bdd8-30383a4ec606" />

---

## Product details

### Cataloging & identification
- **NFC registration** via CoreNFC: tag UID is hashed (SHA-256) and checked against Supabase to distinguish a blank tag from one already bound to a record, with a write-and-lock flow for NTAG215-class tags.
- **Camera-to-metadata pipeline**: a sleeve photo runs through Apple's Vision framework for on-device text recognition, the extracted words are sent to a rate-limited Gemini API client which proposes an artist/album pair, and the result routes into Discogs search to confirm and pull canonical metadata. MusicBrainz is wired in as a secondary lookup source.
- **Goldmine grading**: Mint through Poor, scored independently for media and sleeve, each carrying its own condition multiplier feeding into the suggested valuation.
- **Discogs OAuth 1.0a integration**: full request-token/access-token flow, authenticated search, release detail and batch release fetching, wantlist read/write, and price-suggestion lookups, with built-in rate-limit backoff and OAuth debugging utilities.

### Collection & crates
- Card-stack crate view with drag-to-flip animation, a grid selection mode for multi-record moves between crates, and protected system crates (Unsorted, For Sale, Wishlist) that can't be deleted.
- Crate and vinyl-entry data, plus cover art, are cached locally through a dedicated offline manager with a pending-operations queue, so the collection stays browsable without a connection and syncs once one is available.

### Discover
- MapKit map of nearby posts across collection listings and events, with a category filter bar, radius indicator, and a Supabase Realtime-backed activity feed.
- Multi-step posting flow for both event details and collection listings, plus an RSVP system for events.

### Profile & social
- User stats, crate summary, and discover-post history.
- A following system (not mutual-only friendship) with pending, accepted, and blocked states, plus nearby-collector discovery.

### Data layer
- Supabase backend: Postgres tables for users, vinyl entries, crates (with a many-to-many crate membership join), discover posts, event RSVPs, friendships, exchanges, and messages, secured with row-level security.
- A single `SonexDBManager` (the largest file in the codebase, ~5,000 lines) owns authentication/session handling, all CRUD across these tables, image caching, and the offline cache and sync queue described above.
- `SonexShared`, a local Swift package, holds the data models, enums (vinyl grade, format, exchange/offer/friendship/RSVP status, discover post type), and the shared `SonexTab` definition so the app target and the in-progress App Clip target can consume the same types.

### Design system
- Dark-mode-only amber-on-charcoal palette, Space Mono and DM Sans typography, applied consistently across the dock navigation, crate views, and forms.

---

## Implementation status

This reflects what's actually built in the codebase as of the current commit, not the original 5-week plan (kept below for reference).

| Area | Status |
|---|---|
| Auth, session persistence, Supabase data layer | Built |
| Dock navigation (5 tabs: Crates, Tap, Discover, Exchange, Profile) | Built |
| NFC tag scan + hash lookup | Built |
| Camera capture → Vision OCR → Gemini suggestion → Discogs/MusicBrainz resolution | Built |
| Discogs OAuth, search, pricing, wantlist | Built |
| Goldmine grading + valuation | Built |
| Crate card-stack view, grid multi-select, crate moves | Built |
| Offline cache + pending-operation sync queue | Built |
| Discover map, posting flow, RSVP | Built |
| Profile, stats, following system | Built |
| Exchange (cart, QR handoff, offer negotiation) | Scaffolded — placeholder tab, not yet implemented |
| Messages / threaded chat | Not yet started |
| App Clip (tap an unregistered tag without the app installed) | Scaffolded — target shell and entry view exist, registration logic not yet wired in |
| Push notifications | Not yet started |
| TestFlight distribution | Not yet started |

---

## Stack

Swift, SwiftUI, CoreNFC, Vision (on-device OCR), Gemini API, Discogs API (OAuth 1.0a), MusicBrainz API, Supabase (Postgres, Auth, Realtime, Storage, Edge Functions), MapKit.
