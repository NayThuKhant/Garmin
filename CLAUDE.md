# Garmin watch faces (Connect IQ, Monkey C)

## Goal
Turn the mockups in `mockups/` (previewed in `faces.html`) into Connect IQ watch faces, one project per face,
designed on Vivoactive 6 (390x390 round AMOLED) and shipped to every round AMOLED watch with
API 5.0+ (list in `tools/devices.txt`). Later: Connect IQ Store.

## Always (every change the user asks for)
Any UI change to a face (e.g. "remove the white battery block on H") must be applied in all three places,
in the same turn, without being asked:
1. the watch face code in `faces/<Name>Face/` (rebuild with `tools/build.sh <Name>Face`),
2. the mockups `mockups/<Name>.dc.html` and, if affected, `mockups/<Name>AOD.dc.html`,
3. `faces.html` — regenerate with `python3 tools/build_gallery.py` and commit it. It must ALWAYS match the
   code: it reads each face's settings straight from `faces/<Dir>/resources/properties/properties.xml`
   (+ strings, + the native editor's `watchface.xml`), shows every configurable setting in a Settings
   popup (card button "Settings (N)"), and turns color settings (AccentColor/SecondaryColor; Meridian's Theme) into swatches that
   recolor the mockup. It also has a search box (names + settings), a watch filter (faces per device, from face.json) and Download links to the latest
   GitHub release (repo URL read from `git remote`). So any settings change in code shows up after regenerating. CI fails the build
   if the committed `faces.html` is stale, and the Pages workflow republishes a freshly generated one.
   Every face has at least an AccentColor setting. New face with settings: name the color properties AccentColor/SecondaryColor and give the mockup
   matching `accent`/`secondary` props so the swatches work.
The local `mockups/` + `faces.html` are the only design source; there is no online canvas to keep in sync.

## Layout of this folder
- `faces/` — all face projects live here, one folder per face. Never create a face at the repo root.
- `faces/SplitFace/` — face **I · Split**, the first working project. Use it as the template
  for new faces (manifest, jungle, properties/settings, app + view structure).
  `source/Data.mc` (guarded data getters + formatters) and `source/Gfx.mc` (390-unit drawing,
  vector fonts, icons, AOD shift) are shared: copy them unchanged into each new face; put
  face-specific helpers in the view or a `<Name>Extra.mc`.
- `faces/<Name>Face/` — one project per face (e.g. `RingFace`, `DialFace`), classes `<Name>App`/`<Name>View`.
- `faces/<Dir>/face.json` — the faces <-> devices map: `{"devices": [ids]}` = the watches that face ships to.
  It is the source of truth: `tools/set_products.sh` writes it into manifest.xml (CI fails if they differ,
  `set_products.sh --check`), `build_devices.sh` builds exactly those devices, `build.sh`/`run.sh` only offer
  (and only build) those devices, and faces.html's "All watches" filter + Download device list read it.
  To drop a face from a watch, remove the id from its face.json and run `tools/set_products.sh <Dir>`.
- `tools/devices.json` — supported device ids + display names for faces.html; regenerate after editing
  `tools/devices.txt`: `. tools/ciq_env.sh && ciq_devices` (see git history for the one-liner).
- `tools/` — `build.sh` (vivoactive6 sim build), `build_devices.sh` (build + fit check for every
  device in face.json), `set_products.sh` (writes face.json devices into manifests), `icon.py`
  (54x54 launcher icon from a JSON shape list, `faces/<Dir>/icon.json`). Scripts take face
  names with or without the `faces/` prefix. `render_mockup.py` renders a mockup to PNG with headless
  Chrome (use it to compare a mockup against a reference photo before saying it matches).
  `gen_meridian_mockup.py mockups` regenerates the Meridian mockups; `check_meridian.py` verifies its
  symmetry numerically (all arcs/circles/gaps identical) — run it after any Meridian geometry change.
- `mockups/` — HTML mockups of all 24 faces (A–X). Each face has two files:
  `<Name>.dc.html` (active) and `<Name>AOD.dc.html` (always-on). Inline CSS/SVG gives
  exact positions, sizes and colors at 390x390. `{{accent}}` = the accent color
  (default in the file's `data-props`). Sample data values are placeholders.
  `canvas.json` is the local index (order + titles) that `build_gallery.py` reads; add new boards there.
- `faces.html` — all faces (active + always-on) on one page; open it in a browser. Published to
  https://naythukhant.github.io/Garmin/ by `.github/workflows/pages.yml` on every push that changes it;
  `docs/preview.png` (README image: ALL faces' active designs) — regenerate with
  `tools/.venv/bin/python tools/render_preview.py` after `build_gallery.py` whenever a face changes or is added. Generated from
  `mockups/` by `python3 tools/build_gallery.py`; rerun after changing or adding a mockup.
- `developer_key` — signing key. Never regenerate or commit it.

## Face index
A Ring (Main) · B DataGrid · C Dial · D Bands · E Analog · F Trend · G Gauges ·
H Terminal · I Split · J Sun · K Timeline · L Bold · M Orbit · N Contour · O Tide ·
P Pulse · Q Kinetic · R Guilloche · S Bauhaus · T Radar · U Neon · V NightSky ·
W SplitFlap · X DotMatrix · Y Eclipse · Z Polar · AA Words · AB Segment · AC Bento · AD Bezel
· AE Meridian (customizable: 8 data slots, 37 data options, colors, 4 time fonts; settings XML, strings and the on-watch Customize menu data (`source/MeridianMenuData.mc`) are all generated by `tools/gen_meridian_settings.py faces/MeridianFace` — edit options there, not by hand)

## Build & run
- SDK: Connect IQ 9.2 at
  `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-*/`
- Build: `java -jar <sdk>/bin/monkeybrains.jar -o bin/<App>.prg -f monkey.jungle -y ../../developer_key -d vivoactive6_sim -w` (run inside `faces/<Dir>`)
  or `tools/build.sh [-d device] [Dir...]`: in a terminal it asks for the face (Enter = all) and the
  device (Enter = vivoactive6) from numbered lists; with no terminal (CI) it builds all faces for
  vivoactive6 without asking. Pass `-d`/faces to skip the prompts in scripts.
- All devices: `tools/set_products.sh` then `tools/build_devices.sh [<Dir>...]` (devices from each face.json). A device only
  builds if its files are installed in `~/Library/Application Support/Garmin/ConnectIQ/Devices/`
  (SDK Manager → Devices; otherwise "Invalid device id"). Missing devices are reported as MISSING.
  The "Invalid device id found in the application manifest" warnings mean the same thing.
- Simulator: `tools/run.sh [Dir] [device]` (asks for whatever is left out; builds, starts the simulator, installs the settings file so
  File > Edit Persistent Storage > App Settings Editor works, runs the face).
- CI: `.github/workflows/build.yml` (GitHub Actions) downloads SDK 9.2 + all devices with
  lindell/connect-iq-sdk-manager-cli (secrets GARMIN_USERNAME, GARMIN_PASSWORD, DEVELOPER_KEY_B64; repo
  variable CIQ_AGREEMENT_HASH), caches them, then builds every face for every device and uploads the
  `.iq` + a vivoactive6 `.prg` per face as artifacts. Pushing a `v*` tag also creates a GitHub Release with
  one `<Face>.zip` per face (folder `<Face>/` with `<Face>.iq`,
  `vivoactive6.prg`, `vivoactive5.prg`) + `AllFaces.zip` and keeps only the 3 newest releases. Every run builds all faces (public repo,
  unlimited minutes).
  Never tag a commit whose message has `[skip ci]`: GitHub skips the tag's run too (no release). Scripts read `CIQ_SDK` / `CIQ_DEVICES` (tools/ciq_env.sh).
- Sideload: build with `-d vivoactive6 -r` (not `_sim`), copy the `.prg` to `GARMIN/APPS/` with OpenMTP
  (watch USB Mode must be MTP), quit OpenMTP, unplug. Sideloaded faces get NO phone settings.
- Store / private beta: `tools/export.sh <Dir>` -> `dist/<Dir>.iq`, upload at apps.garmin.com/developer
  ("Beta App" = only you). Store installs get the phone settings (properties.xml) in the Connect IQ app.
- On-watch settings: `getSettingsView` is NOT supported on vivoactive6 / Venu 4 / fenix 8 class watches;
  they use the native editor (`WatchFaceConfig`, resources/configs/watchface.xml) — see the SDK sample
  `samples/ConfigurableWatchFace` and faces/MeridianFace.
- Each new project needs its own UUID app id in manifest.xml.

## Rules learned so far
- `getFontAscent` is `Graphics.getFontAscent(font)`, NOT a `Dc` method.
- Launcher icon for vivoactive6 is 54x54; other watches want 38–70 px. `tools/make_icons.sh [Face]` writes a
  sharp icon per device (`resources-<device>/drawables`) from `icon.json` — run it after changing an icon.
- Lay out in 390-px design units and multiply by `dc.getWidth() / 390.0` so other
  round screens (454, 416) scale.
- Guard every data source: `has` checks + null checks, show `--` when missing
  (SensorHistory body battery/stress, Weather, SpO2, etc.). Needs `SensorHistory` permission.
- Always-on (onEnterSleep/onExitSleep): grey only, thin strokes, no seconds. On real AMOLED watches
  the firmware enforces burn-in rules (<~10% pixels lit, no pixel lit >~3 min); if a face breaks them
  the watch silently shows Garmin's own always-on screen instead. The simulator does NOT enforce this.
  Every face must call `Gfx.aodShift()` after `Gfx.setup(dc)` and `Gfx.aodMask(dc)` as the LAST draw
  call while sleeping (also before any early `return`): the mask blacks out alternating pixel rows,
  swapping each minute. Check lit area by rendering the AOD mockup (all are <=5.3% with the mask).
- Fonts: faces use the mockup's own fonts as bitmap fonts. `faces/<Dir>/fonts.json` →
  `tools/.venv/bin/python tools/mkfont.py <Dir>` writes BMFonts for 360/390/416/454/466 into
  `resources[-round-NxN]/fonts`. TTFs (Google Fonts, OFL) are in `tools/fonts/`. Recreate the venv with
  `python3 -m venv tools/.venv && tools/.venv/bin/pip install Pillow fonttools`.
  Load once in initialize() (`WatchUi.loadResource(Rez.Fonts.X)`), draw with one `Gfx.text` call:
  letter-spacing (`ls`) and hollow numerals (`outline`) are baked into the font; never draw
  bitmap fonts char by char (uneven gaps). The CIQ font compiler drops a glyph's edge column
  (mkfont pads glyphs) and renders small text heavier (mkfont thins edges via `gamma`).
  `dc.drawRadialText` needs a vector font (`Gfx.font`). Reference face: `faces/TideFace`.
- Icons: don't hand-draw icons with polygons. Put SVG artwork in `tools/icons/<set>.json` (24-unit
  viewBox, white) and add `{"id": "Icons", "icons": "<set>"}` to fonts.json: mkfont renders it with
  headless Chrome into an icon font (any color via setColor). Mockups read the same JSON so watch and
  mockup icons match. Preview a set: `tools/.venv/bin/python tools/iconfont.py <set> out.png`.
- Graphs/arcs: use `dc.drawArc`, `fillPolygon`, `setPenWidth`.
- `Gregorian` FORMAT_LONG returns abbreviated weekdays on vivoactive6 ("WED"); use `Data.weekday()`.
- When the user gives a reference image, measure it (crop to the real screen edge, pixel-scan) and
  overlay a render of the mockup on it before reporting; never eyeball proportions.
- The simulator window scales the 390 px screen non-integer, so edges look jagged in screenshots;
  judge sharpness at 1:1. Colors: sample screenshot pixels before "fixing" them (16-bit display).
- Vivoactive 6 has no barometer: no floors climbed.
- Target screens are 360, 390, 416, 454 and 466 px; never hard-code device px, go through
  `Gfx.s/sx/sy`. Watch-face memory limit is 128 KB on vivoactive6, so keep geometry procedural.
- vivoactive6 has vector fonts (`Graphics.getVectorFont`, faces RobotoCondensedBold/Regular,
  RobotoRegular); `Gfx.font` falls back to system fonts where they're missing.
- Text: `Gfx.text` centers capitals/digits at y; for a CSS box (top T, line-height L) use T + L/2.
- The simulator window can't be screenshotted from the agent (no screen-recording permission),
  so check visuals manually in the simulator.
- Sleep score / respiration come from `Toybox.Complications` and need the `ComplicationSubscriber`
  permission (Timeline, Radar, Trend, Gauges, Terminal); show `--` when unavailable.
- venu2/venu2plus/venu2s/d2airx10 (API 5.0) have no vector fonts: faces fall back to system
  fonts there, so text sizes differ from the mockups — check these in the simulator.
