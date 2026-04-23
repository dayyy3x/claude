# App icon placeholder

iOS 18 asks for three 1024×1024 PNGs in one `AppIcon` set:

- `icon-1024.png`        — light / any appearance
- `icon-1024-dark.png`   — dark appearance (optional but looks better)
- `icon-1024-tinted.png` — tinted / monochrome (iOS 18 icon customization)

Drop the files into this folder, then update `Contents.json` so each image
entry has a `"filename"` key pointing at the file. Xcode 15+ will handle the
resizing for every device automatically.

Until you add them, the app builds with the default placeholder icon.
