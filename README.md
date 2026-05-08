# DocBook — Mobile Reader

A native Android reader for the **DocBook** Markdown book repository format. Point it at any GitHub repo with an `index.json` at the root, and it renders books, parts, and chapters with modern typography, paginated chapter swiping, and an in-memory chapter cache for smooth navigation.

> **Companion docs repo:** [DiyRex/DocBook](https://github.com/DiyRex/DocBook) — also see [AUTHORING.md](https://github.com/DiyRex/DocBook/blob/main/AUTHORING.md) for the book authoring + registration format the app reads.

---

## Install

The fastest path is the prebuilt APK from Releases:

1. Open the [Releases page](https://github.com/DiyRex/DocBook-Mobile-App/releases) and download the latest `docbook-vX.Y.Z.apk`.
2. On Android, tap the APK in your file manager / browser.
3. Allow installs from this source if prompted.
4. Open **DocBook**, enter a repo (e.g. `your-org/your-book` or a full GitHub URL), tap **Connect**.

---

## Features

- **Library view** — book cards with cover gradient (per-book accent color), full title, subtitle, tag chips, chapter & read-time stats.
- **Book detail** — large parallax cover, description, parts/chapters/time stats, sectioned chapter list grouped by part.
- **Reader** — `PageView` chapter pagination (swipe horizontally between chapters, scroll vertically within), beautiful typography, font-size slider (85% – 150%), reading-progress bar, GitHub-style code blocks, accent-colored blockquotes.
- **Chapter jump sheet** — quick navigation across all chapters of the current book.
- **Smart cache** — LRU-evicted in-memory cache (10 MB cap) with auto-prefetch of neighbor chapters; RAM-only, never touches disk.
- **Repo settings** — change the repo any time without re-installing; clear cache on demand.
- **Material 3 dark/light theme** — follows your system theme.

---

## Repo Format

The app reads any GitHub repo that has this layout:

```
<repo-root>/
├── index.json                <- TOC the app reads
└── books/
    └── <book-slug>/
        ├── README.md         <- (optional, for GitHub readers)
        ├── preface.md        <- (optional frontmatter)
        └── part-XX-<slug>/
            └── NN-<chapter-slug>.md
```

`index.json` describes books → parts → chapters with paths and read-time estimates. See [AUTHORING.md](https://github.com/DiyRex/DocBook/blob/main/AUTHORING.md) in the docs repo for the full schema.

---

## Build From Source

```bash
git clone https://github.com/DiyRex/DocBook-Mobile-App.git
cd DocBook-Mobile-App
flutter pub get
flutter run -d <your-device-id>           # debug install
# OR
flutter build apk --release               # produces build/app/outputs/flutter-apk/app-release.apk
```

### Requirements

- Flutter ≥ 3.41 (Dart ≥ 3.11)
- Android SDK with API 21+
- An Android device (USB debugging) or emulator

### Project layout

```
lib/
├── main.dart                  <- root MaterialApp + bootstrap
├── repo.dart                  <- repo URL parsing + raw-fetch logic
├── storage.dart               <- SharedPreferences for repo settings
├── models/
│   └── book_index.dart        <- typed model of index.json
├── services/
│   ├── index_service.dart     <- fetch+cache index.json + chapter bodies
│   └── markdown_cache.dart    <- LRU byte-capped cache
├── screens/
│   ├── setup_screen.dart      <- first-run repo connect
│   ├── home_screen.dart       <- library (book grid)
│   ├── book_screen.dart       <- book detail (cover + chapter TOC)
│   ├── chapter_screen.dart    <- reader (PageView + Markdown)
│   └── settings_screen.dart   <- repo + cache controls
└── widgets/
    ├── book_card.dart
    └── chapter_tile.dart
```

---

## Releases

Releases are produced automatically by GitHub Actions when a tag matching `v*` is pushed. The workflow builds an Android release APK and attaches it to a GitHub Release.

To cut a new release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The Action's progress is visible under the **Actions** tab. When it finishes, the new APK appears on the [Releases page](https://github.com/DiyRex/DocBook-Mobile-App/releases).

> The shipped APK is signed with the Flutter debug keystore — sufficient for sideloading on any Android device. To upgrade to a proper release keystore, see *Signing for Play Store* below.

### Signing for Play Store *(optional, future)*

If you want to publish to the Play Store, swap the debug signing for a release keystore:

1. Generate a keystore: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Base64-encode and add to GitHub Secrets as `ANDROID_KEYSTORE`, plus secrets for `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
3. Update `android/app/build.gradle.kts` to read these signing configs from environment variables.
4. The CI workflow already has the hooks (`if: ${{ secrets.ANDROID_KEYSTORE != '' }}`) — set the secrets and the next release will be properly signed.

---

## Why no iOS?

iOS unsigned distribution requires either a paid Apple Developer account ($99/yr) or per-user resigning via Xcode (`flutter build ios --release --no-codesign` produces an unsigned `.app` bundle, but it can't be installed on a real iPhone without resigning). For now this is **Android-only**. Adding iOS is straightforward once an Apple Developer account is in place — the Flutter code is iOS-ready.

---

## License

MIT — see [LICENSE](LICENSE).
