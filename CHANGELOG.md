# Changelog -- Wick's Ledger

## 0.2.1 -- 2026-05-13

- Grey (Poor quality) items collapse into a single Junk row valued at vendor price. Count shown, no individual entries cluttering the list.
- Hard lock mode: session pauses on instance exit instead of stopping. Re-enter to resume where you left off, gold and loot intact. Toggle via `/wledger lock` or the Options panel.

## 0.2.0 -- 2026-05-13

### Session persistence + history

- Session state survives /reload mid-dungeon. Gold delta, loot, XP, and rep are written to SavedVariablesPerCharacter on every change and restored on login. Sessions older than 8 hours are discarded automatically.
- History tab in the panel shows the last 5 completed sessions (date, zone, total earned). Zero-value sessions are not saved.
- /hr projection now uses total earnings (raw gold + item value), rounded to whole gold.
- Item value shown per-line in the panel; /hr hidden from line items to reduce noise.

## 0.1.0 -- 2026-05-12

Initial release.

- Slim always-visible bar showing session earnings in real time
- Expandable itemized panel with icon, name, quantity, and per-item valuation
- AH price chain: TSM > Auctionator > Auctioneer > vendor sell price
- Raw gold delta tracking via PLAYER_MONEY
- Loot tracking via CHAT_MSG_LOOT with per-item accumulation
- Auto-start/stop on instance entry and exit
- Manual control via /wledger start, stop, reset
- Draggable minimap button
