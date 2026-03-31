# Sonex - 4-5 Week Development Sprint Technical Plan

## Week 1 -  Foundations & Data Layer
***Goal:*** App runs, auth works, solid data layer, dock navigation

 - Xcode setup, targets, packages, shared models
 - Supabase setup: - 7 tables, RLS, Realtime on messages
 - Supabase manager: Auth, basic CRUD for vinyl_entries and crates
 - Discogs manager: SearchAlbums() and fetchRelease withing with real API responses
 - Custom SonexDock + ZStac-based table router with all 5 tabs stubbed (placeholder view)
 - Auth flow: login/signup screens, session persistance via keychain
 - @observalble ViewModels wires to supabase for Collection tab (fetch crates + entries)
***End of week deliverable*** You can log in, you can see your crates list poulated from supabase, and switch tabs with no rerenders
   

## Week 2 - NFC + Registration Flow + Collection View
***Goal*** The core cataloging loop works end to end
 - NFC Manager: tag UID extraction -> SHA-256 hash -> supabase lookup (registered vs new)
 - CrateSceneView: SCNView milk crate wall, tap → sheet, UIViewRepresentable bridge
 - Record flip animation inside crate detail sheet (rotation3DEffect)
 - Full registration flow: AlbumSearchView (Discogs search, debounced) → GradingPickerView → ValuationView (pricing from DiscogsManager.fetchPricing) → ConfirmView → write to Supabase
 - Cover art fetched from Discogs, uploaded to Supabase Storage, URL stored in vinyl_entries
 - Collections search bar: live Discogs search, tapping result highlights the containing crate

***End of week deliverable*** Tap and NFC tag -> register a record -> it appears in your crate. Search for an album -> crate highlights if in collection

## Week 3 - Discover map + Exchange + Messages
***Goal*** Social and transactional features working
 - DiscoverMapView: MapKit pins for all 4 categories, filter bar, PostGIS geo query via Supabase RPC
 - Activity log sheet: Supabase realtime subscription to discover_posts, renders feed, tap-to-focus pin
 - Add Posting FAB: EventDetailsForm and CollectionListingFlow (full multi-step flow), writes to discover_posts
 - ExchangeView: cart management, QR session generation, SellSessionView (QR display), BuyerReviewView, transferOwnership Supabase transaction
 - MessagesView + ThreadView: fetch threads, Realtime subscription for live messages, offer CTA bar
 - Quick-reply chips, offer amount input, accept/decline offer status updates
***End of the week deliverable*** You can post an event on the map, message another user about a record, and complete peer to peer exchange with QR confirmaiton

### Week 4 - Wishlist, Profile, Polish + App Clip
***Goal*** Remaining screens complete; App Clip working for unregistered tags
 - WishlistView: want list (Discogs search to add), price alerts (BGAppRefreshTask for background refresh), saved sellers
 - ProfileView: user stats, crate summary, friends list, settings (location, notification prefs)
 - FriendshipView: friend requests, friend discovery via nearby collectors on map
 - App Clip (TapTracksClip): ClipEntryView — tag detected → registered record → ClipRecordDetailView (read-only) or → prompt to download for registration
 - Push notifications: Supabase Edge Function triggers on new message, offer status change, price alert
 - Amber/charcoal design system consistency pass across all screens — typography, spacing, iconography
***End of the week deliverable*** Full app is feature-complete. App Clip works on physical NFC tap. Notifications fire on key events.

### Week 5 - Hardening, Testfight, Iteration, Appstore Assets
***Goal*** Shippable build; iterate on weak spots identified in internal testing
 - TestFlight build: distribute to 5–10 real collectors from your network
 - Real-world NFC testing: NTAG215 write-lock flow, tag re-read reliability
 - Discogs API rate limiting: implement request queue + exponential backoff in DiscogsManager
 - Supabase RLS audit: verify no data leakage across user boundaries
 - Performance: SceneKit crate rendering with 50+ records (LOD switching, texture atlasing)
 - Crash triage from TestFlight, top 3 UX friction points from tester feedback → fix
 - Prepare App Store assets: screenshots (use your existing HTML mockups as reference), privacy manifest, NFC usage description copy

***End of the week deliverable*** Testflight 1.0 with real collector feedback. Prioritized v0.2 backlog ready.
