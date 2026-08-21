# App icon

Drop two PNGs here, then run one command. Nothing else needs editing — every
Android density and every iOS size is generated from these.

## The two files

**`alomforce.png`** — 1024×1024, no transparency.
The whole icon: mark on its background. This is what iOS ships, and iOS
rejects any alpha channel, so give it a solid background.

**`alomforce_foreground.png`** — 1024×1024, transparent background.
The mark *alone*. Android 8 and later mask the icon to whatever shape the
launcher uses — circle, squircle, teardrop — and paints `#12202E` behind it.

Keep the mark inside the middle **66%** of `alomforce_foreground.png`, roughly
a 675×675 box centred in the 1024. Everything outside that can be cropped away
by the mask on some launchers. This is the single most common way a good icon
ends up looking clipped on a phone.

## Generating

```bash
cd alomforce_phone
dart run flutter_launcher_icons
```

Then rebuild the app. Check the result on a real home screen, not only in the
simulator: icons are judged at about 60 px, and detail that reads on a monitor
disappears at that size.

## If you change the background colour

`adaptive_icon_background` in `pubspec.yaml` is `#12202E`, matching the app's
sidebar. Change it in both places or the adaptive icon and the app will
disagree.
