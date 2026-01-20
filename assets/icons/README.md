# App Icons & Splash Screen

## Required Files

### App Icon
1. `app_icon.png` - Main app icon (1024x1024 px)
2. `app_icon_foreground.png` - Android adaptive icon foreground (1024x1024 px with padding)

### Splash Screen
3. `splash_logo.png` - Splash screen logo (512x512 px recommended)
4. `splash_branding.png` - Optional branding text/logo at bottom (200x50 px)

### Design Guidelines

**AfterClose App Icon Design:**
- Background: Gradient from #6C63FF (purple) to #4C46B6 (darker purple)
- Foreground: White/Light colored stock chart icon
- Shape: Rounded square (following iOS/Android guidelines)

**Visual Elements:**
- A simplified candlestick or line chart
- Arrow pointing upward (representing growth/analysis)
- "AC" monogram optional

**Color Palette:**
- Primary: #6C63FF (Purple)
- Secondary: #00D9FF (Cyan accent)
- Background Dark: #1E1E2E
- Up Color: #FF4757 (Red for Taiwan market)
- Down Color: #2ED573 (Green)

### Generation Steps

1. Create your icon design in 1024x1024 px PNG format
2. Place the files in this directory
3. Run: `flutter pub run flutter_launcher_icons`

### Alternative: Generate from SVG

If you have ImageMagick installed:
```bash
# Convert SVG to PNG
convert -background none -resize 1024x1024 icon.svg app_icon.png
```

### Android Adaptive Icon Notes
- The foreground image should have ~20% padding around the edges
- The icon may be masked to different shapes (circle, rounded square, etc.)
- Background color is set in pubspec.yaml as #6C63FF

## Splash Screen

### Generation Steps
1. Create splash_logo.png (512x512 px, transparent background)
2. Optionally create splash_branding.png for bottom branding
3. Run: `flutter pub run flutter_native_splash:create`

### Splash Screen Configuration
The splash screen is configured in pubspec.yaml:
- Light mode background: #1E1E2E (dark surface)
- Dark mode background: #121212 (pure dark)
- Android 12+ icon background: #6C63FF (primary color)

### Removing Splash Screen
To remove the splash screen:
```bash
flutter pub run flutter_native_splash:remove
```
