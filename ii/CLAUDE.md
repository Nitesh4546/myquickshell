# CLAUDE.md — Architecture & Customization Reference for `ii` Quickshell

> **Config Name:** `ii` / `illogical-impulse` (end4-dots-hyprland)  
> **Entry Point:** [shell.qml](file:///home/nitesh/.config/quickshell/ii_clander/shell.qml)  
> **Shell Runtime:** [Quickshell](https://quickshell.outfoxxed.me/) (Qt 6 / QML with Wayland & Hyprland extensions)  
> **Target Environment:** Hyprland Wayland compositor on Linux (Arch Linux / Arch-based preferred)

---

## 1. Overview

This codebase is the graphical desktop shell component of the **`end4-dots-hyprland`** setup (often named `illogical-impulse` or `ii`). It replaces traditional lightweight status bars (Waybar, Eww) with a comprehensive, cohesive, Material You / Fluent styled environment written entirely in **QML / Quickshell**.

### Entry Point & Launching
- **Primary Shell Entry Point:** [shell.qml](file:///home/nitesh/.config/quickshell/ii_clander/shell.qml)  
  Launched via: `quickshell` (from directory) or `qs -c ii` / `qs -p /path/to/shell.qml`.
- **Standalone Auxiliary Windows:**
  - [settings.qml](file:///home/nitesh/.config/quickshell/ii_clander/settings.qml): Graphical multi-tab configuration center (`qs -p settings.qml` or `Super+I`).
  - [welcome.qml](file:///home/nitesh/.config/quickshell/ii_clander/welcome.qml): First-run onboarding wizard (`Super+Shift+Alt+/`).
  - [killDialog.qml](file:///home/nitesh/.config/quickshell/ii_clander/killDialog.qml): Conflicting program detection prompt (`kded6`, `dunst`, `mako`).
  - [ReloadPopup.qml](file:///home/nitesh/.config/quickshell/ii_clander/ReloadPopup.qml): On-screen notification of live Quickshell reload status and error diagnostics.

### QML & Quickshell Features Used
- **Pragmas:**
  - `//@ pragma UseQApplication`: Uses full `QApplication` instead of `QGuiApplication`, enabling desktop styling, complex controls, and system integration.
  - `//@ pragma Env QS_NO_RELOAD_POPUP=1`: Suppresses Quickshell's default internal reload popup in favor of custom [ReloadPopup.qml](file:///home/nitesh/.config/quickshell/ii_clander/ReloadPopup.qml).
  - `//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic`: Uses the lightweight Basic style for optimal performance and custom canvas rendering.
  - `//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000`: Tweaks smooth scrolling physics.
  - `pragma Singleton`: Declares reusable singleton services across QML scopes.
  - `pragma ComponentBehavior: Bound`: Enforces strict compile-time identifier binding.
- **Quickshell Modules:**
  - `Quickshell`: Core types (`ShellRoot`, `PanelWindow`, `LazyLoader`, `Variants`, `Region`, `Scope`).
  - `Quickshell.Wayland` / `Quickshell.Hyprland`: Native Wayland Layer Shell surface manipulation (`WlrLayershell.namespace`), Hyprland IPC events, toplevel window tracking (`ToplevelManager`), monitors, workspaces.
  - `Quickshell.Io`: Native async process execution (`Process`, `StdioCollector`, `SplitParser`), file watching and JSON synchronization (`FileView`, `JsonAdapter`).
  - `Quickshell.Services.Pipewire`, `Mpris`, `Notifications`, `SystemTray`, `UPower`: Native low-level desktop services integration.
  - `IpcHandler`: Declares IPC endpoints callable via `quickshell ipc call <target> <method>`.
  - `GlobalShortcut`: Binds to Hyprland's `global` dispatcher protocol (`hl.dsp.global("quickshell:<name>")`).

---

## 2. Full Directory Tree

```
.
├── .qmlformat.ini                                      # QML code formatting settings (indent: 4 spaces)
├── CLAUDE.md                                           # This AI reference file
├── GlobalStates.qml                                    # Central singleton holding UI visibility flags & Super key state
├── ReloadPopup.qml                                     # Floating popup showing Quickshell reload success/failure
├── killDialog.qml                                      # Dialog prompting user to terminate conflicting background daemons
├── settings.qml                                        # Standalone desktop settings app
├── shell.qml                                           # Main shell entry point (loads services, panel family, IPC)
├── welcome.qml                                         # Onboarding walkthrough wizard
│
├── assets/                                             # Static images and icons
│   ├── icons/                                          # Custom and system SVG icons (distro logos, AI brands, etc.)
│   │   ├── fluent/                                     # Windows 11 Fluent Design SVG iconography (used by Waffle)
│   │   ├── arch-symbolic.svg                           # Arch Linux distro icon
│   │   ├── cloudflare-dns-symbolic.svg                 # Cloudflare WARP indicator icon
│   │   ├── deepseek-symbolic.svg                       # DeepSeek AI brand icon
│   │   ├── google-gemini-symbolic.svg                  # Google Gemini brand icon
│   │   ├── openai-symbolic.svg                         # OpenAI brand icon
│   │   └── ...                                         # Other brand, tool, and distro symbolic SVGs
│   └── images/
│       └── default_wallpaper.png                       # Stock fallback wallpaper
│
├── defaults/                                           # Fallback data and template configs
│   └── ai/
│       ├── README.md                                   # Notes on prompt file format
│       └── prompts/                                    # Stock AI persona prompts (markdown)
│           ├── NoPrompt.md                             # Empty prompt template
│           ├── ii-Default.md                           # Default illogical-impulse assistant personality
│           ├── ii-Imouto.md                            # Anime-style persona prompt
│           ├── nyarch-Acchan.md                        # Nyarch anime persona prompt
│           ├── w-FourPointedSparkle.md                 # Waffle assistant prompt
│           └── w-OpenMechanicalFlower.md               # Alternative technical assistant prompt
│
├── modules/                                            # UI visual components & panel implementations
│   ├── common/                                         # Shared widgets, utilities, functions, and models
│   │   ├── Appearance.qml                              # Core theme singleton: colors, layer math, fonts, sizes, animation curves
│   │   ├── Config.qml                                  # Central config singleton: FileView watching config.json + JsonAdapter
│   │   ├── Directories.qml                             # Standard XDG paths and application runtime directory constants
│   │   ├── Icons.qml                                   # Icon mapper for battery, wifi, bluetooth, weather
│   │   ├── Images.qml                                  # Image format validator and thumbnail dimension calculators
│   │   ├── Persistent.qml                              # Persistent runtime state singleton (states.json: coordinates, pins)
│   │   ├── functions/                                  # JavaScript helper libraries wrapped as QML singletons
│   │   │   ├── ColorUtils.qml                          # Color mixing, transparency math, overlay solving
│   │   │   ├── DateUtils.qml                           # Calendar logic, day calculations
│   │   │   ├── FileUtils.qml                           # URI sanitization (trimming file://), path utilities
│   │   │   ├── Fuzzy.qml                               # Fuzzy search wrapper
│   │   │   ├── fuzzysort.js                            # Upstream fuzzysort library
│   │   │   ├── Levendist.qml                           # Levenshtein distance matching singleton
│   │   │   ├── levendist.js                            # Levenshtein distance algorithm
│   │   │   ├── NotificationUtils.qml                   # Notification parsing and app icon resolution
│   │   │   ├── NumberUtils.qml                         # Number formatting and zero-padding
│   │   │   ├── ObjectUtils.qml                         # Object cloning and deep assignment
│   │   │   ├── Session.qml                             # System session actions (lock, suspend, reboot, poweroff)
│   │   │   └── StringUtils.qml                          # Shell argument quoting and escaping helpers
│   │   ├── models/                                     # QML models and data structures
│   │   │   ├── AdaptedMaterialScheme.qml               # Scheme adapter for Material color tokens
│   │   │   ├── AnimatedTabIndexPair.qml                # Tab index animation tracker
│   │   │   ├── FolderListModelWithHistory.qml          # Folder browser model with navigation history
│   │   │   ├── IndexModel.qml                          # Sequential numeric indexing model
│   │   │   ├── LauncherSearchResult.qml                # Unified search result object wrapper
│   │   │   ├── NestableObject.qml                      # Tree-like object adapter
│   │   │   ├── WorkspaceModel.qml                      # Hyprland workspace listing model
│   │   │   ├── gCloud/                                 # Google Cloud Vision integration data models
│   │   │   ├── hyprland/                               # Hyprland config option data models
│   │   │   └── quickToggles/                           # State definitions for quick settings toggles (Bluetooth, Wifi, etc.)
│   │   ├── panels/                                     # Reusable fullscreen or shared panel bases
│   │   │   └── lock/                                   # Shared lock screen base with PAM / fprintd authentication
│   │   ├── utils/                                      # Asynchronous process utilities
│   │   │   ├── ImageDownloaderProcess.qml              # Background image fetcher via curl
│   │   │   ├── MultiTurnProcess.qml                    # Interactive CLI process runner
│   │   │   ├── ScreenshotAction.qml                    # Screenshot action coordinator
│   │   │   └── TempScreenshotProcess.qml               # Temporary screenshot capture helper via grim
│   │   └── widgets/                                    # Reusable UI controls and primitives (Material 3 style)
│   │       ├── AppIcon.qml                             # Desktop application icon resolver
│   │       ├── Box.qml / BoxLayout.qml                 # Flexible layout boxes
│   │       ├── ButtonGroup.qml / GroupButton.qml       # Segmented pill button groups
│   │       ├── CalendarView.qml                        # Monthly interactive calendar widget
│   │       ├── CircularProgress.qml                    # Canvas-drawn circular progress ring
│   │       ├── CliphistImage.qml                       # Clipboard thumbnail decoder and viewer
│   │       ├── ConfigRow.qml / ConfigSwitch.qml ...    # Form components for Settings and Welcome dialogs
│   │       ├── ContentPage.qml / ContentSection.qml    # Settings app layout scaffolding
│   │       ├── MaterialCookie.qml / SineCookie.qml     # Android 12+ style scalloped parametric cookie clock faces
│   │       ├── MaterialSymbol.qml                      # Google Material Symbols icon renderer
│   │       ├── NavigationRail.qml                      # Vertical tab rail navigation widget
│   │       ├── NotificationItem.qml / NotificationGroup.qml # Notification delegates
│   │       ├── Revealer.qml                            # Smooth expanding/collapsing container
│   │       ├── RippleButton.qml                        # Material 3 ripple effect button
│   │       ├── RoundCorner.qml                         # Reverse-curved corner decorator for panel edges
│   │       ├── StyledDropShadow.qml / StyledRectangularShadow.qml # Elevation drop shadows
│   │       ├── StyledSlider.qml / StyledSwitch.qml     # Custom-themed form inputs
│   │       ├── StyledText.qml                          # Font-token-aware text element
│   │       ├── shapes/                                 # Parametric squircle and Material polygon canvas algorithms
│   │       └── widgetCanvas/                           # Freeform draggable desktop overlay widget canvas
│   ├── ii/                                             # Main "Illogical Impulse" Material 3 Panel Family
│   │   ├── background/                                 # Desktop background layer with wallpaper & desktop clock
│   │   ├── bar/                                        # Horizontal top/bottom bar (workspaces, media, clock, tray)
│   │   ├── cheatsheet/                                 # Keyboard shortcut overlay & periodic table cheatsheet
│   │   ├── dock/                                       # macOS/KDE style auto-hiding dock
│   │   ├── lock/                                       # Lock screen surface and password input
│   │   ├── mediaControls/                              # Floating popup media player controls
│   │   ├── notificationPopup/                          # OSD toast notification popups
│   │   ├── onScreenDisplay/                            # Volume and brightness change indicators (OSD)
│   │   ├── onScreenKeyboard/                           # Virtual touch keyboard (OSK)
│   │   ├── overlay/                                    # Draggable desktop widgets overlay (crosshair, notes, performance)
│   │   ├── overview/                                   # Fullscreen workspace switcher & application search
│   │   ├── polkit/                                     # PolicyKit graphical authentication dialog
│   │   ├── regionSelector/                             # Screen snip, OCR, and color picker region overlay
│   │   ├── screenCorners/                              # Rounded faux display corners
│   │   ├── screenTranslator/                           # On-screen OCR and translation tool
│   │   ├── sessionScreen/                              # Power management menu (lock, logout, reboot, shutdown)
│   │   ├── sidebarLeft/                                # Left sidebar: AI chatbot, anime wallpaper booru, translator
│   │   ├── sidebarRight/                               # Right sidebar: quick toggles, sliders, calendar, todo, notifications
│   │   ├── verticalBar/                                # Alternative vertical status bar
│   │   └── wallpaperSelector/                          # Visual wallpaper gallery browser
│   ├── settings/                                       # Sub-pages embedded into settings.qml
│   │   ├── About.qml                                   # Version, credits, and link info
│   │   ├── AdvancedConfig.qml                          # Hacks, race delays, raw overrides
│   │   ├── BackgroundConfig.qml                        # Wallpaper and background widget settings
│   │   ├── BarConfig.qml                               # Status bar position, style, and module visibility
│   │   ├── GeneralConfig.qml                           # Distro policies, language, search prefixes
│   │   ├── InterfaceConfig.qml                         # Fonts, transparency, fake screen corners
│   │   ├── QuickConfig.qml                             # Rapid toggles for common customizations
│   │   └── ServicesConfig.qml                          # AI, audio protection, updates, weather settings
│   └── waffle/                                         # Alternative "Waffle" Windows 11 Fluent Design Panel Family
│       ├── README.md                                   # Notes on Waffle implementation and Fluent design
│       ├── actionCenter/                               # Win11 style Action Center (quick settings & media)
│       ├── background/                                 # Clean desktop wallpaper background
│       ├── bar/                                        # Centered Windows 11 taskbar with Start button & pinned apps
│       ├── lock/                                       # Windows 11 style lock screen
│       ├── looks/                                      # Acrylic, Mica, and Fluent UI controls (WButton, WPane, etc.)
│       ├── notificationCenter/                         # Calendar + notification history panel
│       ├── notificationPopup/                          # Fluent toast notification popups
│       ├── onScreenDisplay/                            # Windows-styled volume and brightness flyout
│       ├── polkit/                                     # Fluent style PolicyKit authentication prompt
│       ├── screenSnip/                                 # Windows "Snipping Tool" region selector
│       ├── sessionScreen/                              # Fullscreen power options overlay
│       ├── startMenu/                                  # Windows 11 Start Menu with search & pinned app grid
│       └── taskView/                                   # Task View window overview
│
├── panelFamilies/                                      # Family loading architecture
│   ├── IllogicalImpulseFamily.qml                      # PanelLoader bundle for "ii" panels
│   ├── PanelLoader.qml                                 # LazyLoader wrapper conditioned on Config.ready
│   └── WaffleFamily.qml                                # PanelLoader bundle for "waffle" panels
│
├── scripts/                                            # Shell, Python, and utility scripts invoked by QML
│   ├── ai/                                             # AI support scripts (wallpaper categorization, translation)
│   ├── cava/                                           # Audio visualizer cava configuration template
│   ├── colors/                                         # Dynamic Material You color generation scripts
│   │   ├── applycolor.sh                               # Applies colors to terminals (Kitty, TTY escape sequences)
│   │   ├── generate_colors_material.py                 # Core Material You HCT color generator using Pillow & materialyoucolor
│   │   ├── scheme_for_image.py                         # Detects optimal scheme type (vibrant, expressive, etc.) for image
│   │   ├── switchwall.sh                               # Central wallpaper switcher & color generation coordinator
│   │   ├── code/material-code-set-color.sh             # VS Code theme color updater
│   │   ├── random/                                     # Random online wallpaper fetchers (Konachan, osu!)
│   │   └── terminal/                                   # Terminal color scheme templates (kitty-theme.conf, sequences.txt)
│   ├── hyprland/hyprconfigurator.py                    # Script to programmatically inspect/modify Hyprland config
│   ├── images/                                         # Image processing scripts (least_busy_region.py, find_regions.py)
│   ├── keyring/                                        # Secret storage helpers (unlock.sh, is_unlocked.sh, try_lookup.sh)
│   ├── musicRecognition/recognize-music.sh             # Shazam-like music identifier using songrec
│   ├── thumbnails/                                     # Wallpaper thumbnail generator scripts (thumbgen.py)
│   └── videos/record.sh                                # Screen recording script using wf-recorder
│
├── services/                                           # Global singletons providing backend logic & system state
│   ├── Ai.qml                                          # LLM chat provider (Gemini, OpenAI, Mistral, Ollama) with tools
│   ├── AppSearch.qml                                   # Application scoring and search indexer
│   ├── Audio.qml                                       # Pipewire audio sink/source wrapper with volume protection
│   ├── Battery.qml                                     # UPower battery monitor and auto-suspend handler
│   ├── BluetoothStatus.qml                             # Bluetooth device and connection status via bluetoothctl
│   ├── Booru.qml                                       # Anime booru search engine (Yande.re, Konachan, Gelbooru, etc.)
│   ├── BooruResponseData.qml                           # Booru response data model
│   ├── Brightness.qml                                  # Monitor brightness controller (ddcutil + brightnessctl)
│   ├── CalendarService.qml                             # Calendar event store and date model
│   ├── Cliphist.qml                                    # Clipboard history reader and decoder (cliphist)
│   ├── ConflictKiller.qml                              # Background daemon conflict killer
│   ├── DateTime.qml                                    # Real-time clock and formatted date strings
│   ├── EasyEffects.qml                                 # EasyEffects preset controller
│   ├── Emojis.qml                                      # Emoji picker search and database
│   ├── FirstRunExperience.qml                          # Launches welcome wizard on initial startup
│   ├── GlobalFocusGrab.qml                             # Manages modal window focus grabbing
│   ├── GoogleCloud.qml                                 # Google Cloud service authentication
│   ├── HyprlandAntiFlashbangShader.qml                 # Toggles GLSL anti-flashbang screen shader
│   ├── HyprlandConfig.qml                              # Hyprland runtime configuration bridge
│   ├── HyprlandData.qml                                # Hyprland client/workspace/monitor cache (hyprctl)
│   ├── HyprlandKeybinds.qml                            # Hyprland keybinds parser (hyprctl binds -j)
│   ├── HyprlandXkb.qml                                 # Active keyboard layout tracker
│   ├── Hyprsunset.qml                                  # Hyprsunset night light / gamma controller
│   ├── Idle.qml                                        # Wayland idle inhibitor controller
│   ├── KeyringStorage.qml                              # Secure storage for API keys
│   ├── LatexRenderer.qml                               # LaTeX math formula to SVG renderer
│   ├── LauncherApps.qml                                # Desktop application (.desktop) scanner
│   ├── LauncherSearch.qml                              # Unified prefix-based search coordinator
│   ├── MaterialThemeLoader.qml                         # Watches generated colors.json and updates Appearance.m3colors
│   ├── MprisController.qml                             # Multi-player MPRIS media playback controller
│   ├── Network.qml                                     # NetworkManager Wi-Fi and Ethernet status via nmcli
│   ├── Notifications.qml                               # Notification server with persistence and popup queues
│   ├── PolkitService.qml                               # PolicyKit authentication agent bridge
│   ├── Privacy.qml                                     # Camera and microphone in-use privacy indicators
│   ├── RecentApps.qml                                  # Recently launched application tracking
│   ├── ResourceUsage.qml                               # CPU, RAM, and Swap poller (/proc/stat, /proc/meminfo)
│   ├── SessionWarnings.qml                             # System warning toasts (low battery, storage full)
│   ├── SongRec.qml                                     # Ambient song recognition service
│   ├── SystemInfo.qml                                  # Distro, username, and OS release parser
│   ├── TaskbarApps.qml                                 # Running window icons mapped to taskbar
│   ├── TimerService.qml                                # Pomodoro timer and stopwatch state engine
│   ├── Todo.qml                                        # To-do list manager persisted to JSON
│   ├── Translation.qml                                 # Localization string loader (Translation.tr)
│   ├── TrayService.qml                                 # StatusNotifierItem system tray manager
│   ├── Updates.qml                                     # Arch Linux / pacman package update checker
│   ├── Wallpapers.qml                                  # Wallpaper directory scanner and switcher
│   ├── Weather.qml                                     # Live weather reporter via wttr.in
│   ├── Ydotool.qml                                     # Synthetic keyboard and mouse input simulator
│   ├── ai/                                             # Sub-components for AI API format implementations
│   ├── gCloud/                                         # OAuth token extraction helper scripts
│   ├── hyprlandAntiFlashbangShader/                    # GLSL shader source files
│   └── network/                                        # Wi-Fi access point data wrapper
│
└── translations/                                       # Localization catalog files (JSON)
    ├── en_US.json / zh_CN.json / ru_RU.json ...        # Translated string dictionaries
    └── tools/                                          # Translation synchronization tools and docs
```

---

## 3. Architecture

### 3.1 Module Loading & Panel Families
The shell is divided into two distinct **Panel Families**:
1. **`ii` (`IllogicalImpulseFamily`)**: The flagship Material 3 / Android 14+ styled desktop shell.
2. **`waffle` (`WaffleFamily`)**: A pixel-faithful recreation of the Windows 11 desktop and taskbar.

In [shell.qml](file:///home/nitesh/.config/quickshell/ii_clander/shell.qml), panel families are toggled dynamically at runtime without restarting the process:
```qml
PanelFamilyLoader {
    identifier: "ii"
    component: IllogicalImpulseFamily {}
}
PanelFamilyLoader {
    identifier: "waffle"
    component: WaffleFamily {}
}
```
Each panel inside a family is wrapped in a `PanelLoader` (a specialized `LazyLoader`), which defers instantiation until `Config.ready` is `true`. Many panels also specify `extraCondition` (e.g. `!Config.options.bar.vertical` for horizontal bar, `Config.options.dock.enable` for the dock).

### 3.2 Registration & Loading Table

| Module / Panel | Family | Primary File | Controlled By / Trigger |
| :--- | :--- | :--- | :--- |
| **Bar (Horizontal)** | `ii` | `modules/ii/bar/Bar.qml` | `!Config.options.bar.vertical`, `GlobalStates.barOpen` |
| **Vertical Bar** | `ii` | `modules/ii/verticalBar/VerticalBar.qml` | `Config.options.bar.vertical`, `GlobalStates.barOpen` |
| **Background** | `ii` / `waffle` | `modules/ii/background/Background.qml` | Always loaded; hides when fullscreen if configured |
| **Cheatsheet** | Both | `modules/ii/cheatsheet/Cheatsheet.qml` | `GlobalShortcut: cheatsheetToggle`, IPC `cheatsheet` |
| **Dock** | `ii` | `modules/ii/dock/Dock.qml` | `Config.options.dock.enable`, auto-hide hover region |
| **Lock Screen** | Both | `modules/ii/lock/Lock.qml` | `GlobalStates.screenLocked`, IPC `lock`, `hypridle` |
| **Media Controls** | `ii` | `modules/ii/mediaControls/MediaControls.qml` | `GlobalStates.mediaControlsOpen`, IPC `mediaControls` |
| **Notification Popups**| Both | `modules/ii/notificationPopup/NotificationPopup.qml` | `Notifications.popupList.length > 0` |
| **OSD (Volume/Bright)** | `ii` | `modules/ii/onScreenDisplay/OnScreenDisplay.qml` | `GlobalStates.osdVolumeOpen` / `osdBrightnessOpen` |
| **On-Screen Keyboard** | Both | `modules/ii/onScreenKeyboard/OnScreenKeyboard.qml` | `GlobalStates.oskOpen`, IPC `osk` |
| **Overlay (Widgets)** | `ii` | `modules/ii/overlay/Overlay.qml` | `GlobalStates.overlayOpen`, IPC `overlay` |
| **Overview (Search)** | `ii` | `modules/ii/overview/Overview.qml` | `GlobalStates.overviewOpen`, IPC `search`, Super release |
| **Polkit Prompt** | Both | `modules/ii/polkit/Polkit.qml` | Active Polkit authentication session request |
| **Region Selector** | `ii` | `modules/ii/regionSelector/RegionSelector.qml` | `GlobalStates.regionSelectorOpen`, IPC `regionSelector` |
| **Screen Corners** | `ii` | `modules/ii/screenCorners/ScreenCorners.qml` | `Config.options.appearance.fakeScreenRounding > 0` |
| **Screen Translator** | Both | `modules/ii/screenTranslator/ScreenTranslator.qml` | `GlobalStates.screenTranslatorOpen`, IPC `screenTranslator` |
| **Session Screen** | `ii` | `modules/ii/sessionScreen/SessionScreen.qml` | `GlobalStates.sessionOpen`, IPC `session` |
| **Left Sidebar** | `ii` | `modules/ii/sidebarLeft/SidebarLeft.qml` | `GlobalStates.sidebarLeftOpen`, IPC `sidebarLeft` |
| **Right Sidebar** | `ii` | `modules/ii/sidebarRight/SidebarRight.qml` | `GlobalStates.sidebarRightOpen`, IPC `sidebarRight` |
| **Wallpaper Selector**| Both | `modules/ii/wallpaperSelector/WallpaperSelector.qml` | `GlobalStates.wallpaperSelectorOpen`, IPC `wallpaperSelector` |
| **Waffle Bar** | `waffle` | `modules/waffle/bar/WaffleBar.qml` | `Config.options.panelFamily === "waffle"` |
| **Waffle Start Menu** | `waffle` | `modules/waffle/startMenu/WaffleStartMenu.qml` | Windows key, IPC `waffleStartMenu` |
| **Waffle Action Center**| `waffle` | `modules/waffle/actionCenter/WaffleActionCenter.qml` | IPC `waffleActionCenter`, taskbar click |
| **Waffle Notif Center**| `waffle` | `modules/waffle/notificationCenter/WaffleNotificationCenter.qml` | IPC `waffleNotificationCenter`, clock click |
| **Waffle Task View** | `waffle` | `modules/waffle/taskView/WaffleTaskView.qml` | IPC `waffleTaskView`, task view button |
| **Waffle Screen Snip** | `waffle` | `modules/waffle/screenSnip/WScreenSnip.qml` | IPC `waffleScreenSnip` |

### 3.3 Core Singletons and Services

```
┌─────────────────────────────────────────────────────────────┐
│                          shell.qml                          │
├──────────────────────────────┬──────────────────────────────┤
│    MaterialThemeLoader       │       HyprlandData           │
│    (watches colors.json)     │    (hyprctl clients/layers)  │
├──────────────────────────────┼──────────────────────────────┤
│        Config.qml            │       Appearance.qml         │
│   (watches config.json)      │   (Material 3 design tokens) │
├──────────────────────────────┼──────────────────────────────┤
│      GlobalStates.qml        │       Persistent.qml         │
│   (UI visibility flags)      │     (widget coordinates)     │
└──────────────────────────────┴──────────────────────────────┘
```

- **[Config.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Config.qml):** Loads and hot-reloads `config.json`. Exposes `Config.options.<section>.<property>`. Provides `Config.setNestedValue(key, value)` with automatic type coercion.
- **[Appearance.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Appearance.qml):** Houses the active Material 3 color system (`Appearance.m3colors`), layer colors (`colLayer0` through `colLayer4`), fonts, sizes, and physics-based bezier animation curves.
- **[GlobalStates.qml](file:///home/nitesh/.config/quickshell/ii_clander/GlobalStates.qml):** Holds all boolean flags for whether panels are open (e.g. `barOpen`, `sidebarLeftOpen`, `sidebarRightOpen`, `overviewOpen`, `screenLocked`).
- **[Persistent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Persistent.qml):** Two-way JSON sync to `~/.local/state/quickshell/states.json` for persistent user state (overlay widget coordinates, pinned widgets, stopwatch/timer states, active AI model).
- **[Audio.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Audio.qml):** PipeWire abstraction. Volume tracking, device enumeration, sudden loud volume protection.
- **[Brightness.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Brightness.qml):** Dual-backend display brightness via `brightnessctl` (laptops) and `ddcutil` (external monitors), integrated with `Hyprsunset` for negative gamma dimming.
- **[Notifications.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Notifications.qml):** D-Bus notification server with history persistence (`notifications.json`), per-app grouping, and toast timeouts.
- **[HyprlandData.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/HyprlandData.qml):** In-memory cache of clients, workspaces, monitors, and layers updated reactively via `hyprctl` and Hyprland socket events.
- **[Ai.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Ai.qml):** Full multi-turn conversational AI engine supporting Gemini, OpenAI, Mistral, and local Ollama models with function/tool execution.

### 3.4 IPC Handlers Table
Any IPC target can be called from bash using:
```bash
qs -p /home/nitesh/.config/quickshell/ii_clander/shell.qml ipc call <target> <method> [args...]
# or if running under config name 'ii':
qs -c ii ipc call <target> <method> [args...]
```

| Target | Methods | Purpose |
| :--- | :--- | :--- |
| `panelFamily` | `cycle()` | Cycles between `"ii"` and `"waffle"` styles |
| `theme` | `toggleLightDark()` | Switches between dark and light themes |
| `bar` | `toggle()`, `open()`, `close()` | Controls main horizontal status bar |
| `verticalBar` | `toggle()`, `open()`, `close()` | Controls vertical status bar |
| `sidebarLeft` | `toggle()`, `open()`, `close()` | Controls left sidebar (AI/Booru/Translate) |
| `sidebarRight`| `toggle()`, `open()`, `close()` | Controls right sidebar (Control Center) |
| `search` | `toggle()`, `open()`, `close()`, `clipboardToggle()`, `workspacesToggle()`, `toggleReleaseInterrupt()` | Controls overview & app launcher |
| `cheatsheet` | `toggle()`, `open()`, `close()` | Controls shortcut cheatsheet overlay |
| `mediaControls` | `toggle()`, `open()`, `close()` | Controls floating media player widget |
| `overlay` | `toggle()` | Controls desktop widget overlay |
| `session` | `toggle()`, `open()`, `close()` | Controls power & session dialog |
| `lock` | `lock()`, `unlock()` | Triggers screen lock / unlock |
| `osk` | `toggle()`, `open()`, `close()` | Controls on-screen keyboard |
| `screenTranslator` | `toggle()` | Starts screen text capture & translation |
| `wallpaperSelector` | `toggle()`, `open()`, `close()` | Opens wallpaper picker dialog |
| `wallpapers` | `apply(string path)` | Applies a specific wallpaper image path |
| `regionSelector` | `snip()`, `snipEdit()`, `colorPicker()`, `ocr()`, `search()` | Launches region selection tool |
| `mpris` | `playPause()`, `previous()`, `next()`, `pauseAll()` | Media playback controls |
| `brightness` | `increment()`, `decrement()` | Adjusts monitor brightness |
| `osdVolume` | `trigger()`, `hide()`, `toggle()` | Triggers on-screen volume indicator |
| `cliphistService` | `update()` | Forces reload of clipboard history |
| `waffle*` | `toggle()`, `open()`, `close()` | Equivalent targets for the Waffle panel family |

### 3.5 Hyprland Keybind Integration
Quickshell registers native Wayland global shortcuts via `GlobalShortcut { name: "..." }`. Hyprland connects to them using its **`global` dispatcher** in `~/.config/hypr/hyprland/keybinds.lua`:
```lua
-- Example Hyprland keybind invoking Quickshell GlobalShortcut:
hl.bind("SUPER + N", hl.dsp.global("quickshell:sidebarRightToggle"))
hl.bind("SUPER + Tab", hl.dsp.global("quickshell:overviewWorkspacesToggle"))
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:searchToggleRelease"))
```
For external standalone windows, Hyprland binds direct execution:
```lua
hl.bind("SHIFT + SUPER + ALT + Slash", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/ii/welcome.qml"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("qs -p ~/.config/quickshell/ii/settings.qml"))
```

---

## 4. Config & Settings System

### 4.1 Storage & Sync Architecture
- **User Config File Path:** `~/.config/illogical-impulse/config.json`  
  (Defined as `Directories.shellConfigPath` in [Directories.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Directories.qml)).
- **Format:** Standard JSON.
- **Default Schema & Values:** [modules/common/Config.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Config.qml).
- **Read/Write Mechanics:**
  - [Config.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Config.qml) uses Quickshell's native `FileView` bound to a `JsonAdapter`.
  - `watchChanges: true`: Automatically reloads the adapter when `config.json` is edited externally (debounced by `readWriteDelay: 50ms`).
  - `onAdapterUpdated`: Automatically writes changes back to disk when any QML component mutates `Config.options.*`.
  - Missing file handling: If `config.json` does not exist on startup, `FileView` triggers `onLoadFailed` with `FileViewError.FileNotFound`, which immediately writes the full default configuration adapter to disk.
  - Programmatic updates: `Config.setNestedValue("bar.bottom", true)` parses nested dot paths and handles type conversion for strings, numbers, and booleans.

### 4.2 Complete Config Options Reference Table

| Path | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `panelFamily` | `string` | `"ii"` | Active panel family: `"ii"` or `"waffle"` |
| `policies.ai` | `int` | `1` | AI policy: `0` = Disabled, `1` = Enabled, `2` = Local only |
| `policies.weeb` | `int` | `1` | Anime features policy: `0` = No, `1` = Open, `2` = Closet |
| `ai.systemPrompt` | `string` | *(Multi-line markdown)* | System instructions provided to AI chat models |
| `ai.tool` | `string` | `"functions"` | Default tool capabilities: `"functions"`, `"search"`, or `"none"` |
| `ai.extraModels` | `list<var>` | `[{...}]` | Array of custom OpenAI/Gemini compatible API model definitions |
| `appearance.extraBackgroundTint` | `bool` | `true` | Blends a 1% accent tint into Layer 0 background color |
| `appearance.fakeScreenRounding` | `int` | `2` | Faux corner radius: `0` = None, `1` = Always, `2` = Not fullscreen |
| `appearance.fonts.main` | `string` | `"Google Sans Flex"` | Default UI font family |
| `appearance.fonts.numbers` | `string` | `"Google Sans Flex"` | Numerals and clock font family |
| `appearance.fonts.title` | `string` | `"Google Sans Flex"` | Window & section headings font family |
| `appearance.fonts.iconNerd` | `string` | `"JetBrains Mono NF"` | Nerd Font icons font family |
| `appearance.fonts.monospace` | `string` | `"JetBrains Mono NF"` | Code blocks and terminal font family |
| `appearance.fonts.reading` | `string` | `"Readex Pro"` | Prose and long-form reading font family |
| `appearance.fonts.expressive` | `string` | `"Space Grotesk"` | Stylized expressive font family |
| `appearance.transparency.enable` | `bool` | `false` | Master toggle for shell transparency |
| `appearance.transparency.automatic` | `bool` | `true` | Computes transparency dynamically from wallpaper vibrancy |
| `appearance.transparency.backgroundTransparency` | `real` | `0.11` | Manual background surface transparency (0.0 - 1.0) |
| `appearance.transparency.contentTransparency` | `real` | `0.57` | Manual content card transparency (0.0 - 1.0) |
| `appearance.wallpaperTheming.enableAppsAndShell` | `bool` | `true` | Master switch for Material You wallpaper color extraction |
| `appearance.wallpaperTheming.enableQtApps` | `bool` | `true` | Applies colors to KDE / Qt applications |
| `appearance.wallpaperTheming.enableTerminal` | `bool` | `true` | Generates and sends color sequences to terminals |
| `appearance.wallpaperTheming.terminalGenerationProps.harmony` | `real` | `0.6` | Hue shift factor towards accent (0.0 - 1.0) |
| `appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold` | `real` | `100` | Maximum degree angle for color hue shift (0 - 180) |
| `appearance.wallpaperTheming.terminalGenerationProps.termFgBoost` | `real` | `0.35` | Terminal foreground contrast boost factor |
| `appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode` | `bool` | `false` | Keeps terminal colors dark even when shell is in light mode |
| `appearance.palette.type` | `string` | `"auto"` | Scheme variant: `"auto"`, `"scheme-tonal-spot"`, `"scheme-expressive"`, etc. |
| `appearance.palette.accentColor` | `string` | `""` | Hex override (e.g. `"#ff7700"`); empty string generates from wallpaper |
| `audio.protection.enable` | `bool` | `false` | Protects ears from sudden loud volume jumps |
| `audio.protection.maxAllowedIncrease` | `real` | `10` | Maximum allowable single-step volume jump (%) |
| `audio.protection.maxAllowed` | `real` | `99` | Hard maximum volume cap (%) |
| `apps.bluetooth` | `string` | `"kcmshell6 kcm_bluetooth"` | Command to open Bluetooth settings |
| `apps.changePassword` | `string` | `"kitty -1 --hold=yes ... passwd"`| Command to launch password change prompt |
| `apps.network` | `string` | `"kcmshell6 kcm_networkmanagement"` | Command to open Network settings |
| `apps.manageUser` | `string` | `"kcmshell6 kcm_users"` | Command to open User management |
| `apps.networkEthernet` | `string` | `"kcmshell6 kcm_networkmanagement"` | Command to open Ethernet settings |
| `apps.taskManager` | `string` | `"plasma-systemmonitor ..."` | Command to open Task Manager |
| `apps.terminal` | `string` | `"kitty -1"` | Default terminal emulator used for shell actions |
| `apps.update` | `string` | `"kitty -1 ... pacman -Syu"` | Command executed to perform system update |
| `apps.volumeMixer` | `string` | `"... launch_first_available.sh pavucontrol-qt pavucontrol"` | Audio mixer command |
| `background.widgets.clock.enable` | `bool` | `true` | Shows clock widget on desktop wallpaper |
| `background.widgets.clock.showOnlyWhenLocked` | `bool` | `false` | Only renders clock when screen is locked |
| `background.widgets.clock.placementStrategy` | `string` | `"leastBusy"` | Placement: `"leastBusy"`, `"mostBusy"`, or `"free"` |
| `background.widgets.clock.x` / `y` | `real` | `100` / `100` | Coordinates when placementStrategy is `"free"` |
| `background.widgets.clock.style` | `string` | `"cookie"` | Clock style when unlocked: `"cookie"` or `"digital"` |
| `background.widgets.clock.styleLocked` | `string` | `"cookie"` | Clock style when screen is locked: `"cookie"` or `"digital"` |
| `background.widgets.clock.cookie.aiStyling` | `bool` | `false` | Uses Gemini to select cookie shape based on wallpaper |
| `background.widgets.clock.cookie.sides` | `int` | `14` | Number of scalloped lobes on the cookie shape |
| `background.widgets.clock.cookie.dialNumberStyle` | `string` | `"full"` | Dial numbers: `"dots"`, `"numbers"`, `"full"`, or `"none"` |
| `background.widgets.clock.cookie.hourHandStyle` | `string` | `"fill"` | Hour hand: `"classic"`, `"fill"`, `"hollow"`, or `"hide"` |
| `background.widgets.clock.cookie.minuteHandStyle` | `string` | `"medium"` | Minute hand: `"classic"`, `"thin"`, `"medium"`, `"bold"`, `"hide"` |
| `background.widgets.clock.cookie.secondHandStyle` | `string` | `"dot"` | Second hand: `"dot"`, `"line"`, `"classic"`, or `"hide"` |
| `background.widgets.clock.cookie.dateStyle` | `string` | `"bubble"` | Date display: `"border"`, `"rect"`, `"bubble"`, or `"hide"` |
| `background.widgets.clock.cookie.timeIndicators` | `bool` | `true` | Shows minute / hour tick indicators |
| `background.widgets.clock.cookie.hourMarks` | `bool` | `false` | Shows distinct hour pips |
| `background.widgets.clock.cookie.dateInClock` | `bool` | `true` | Places date badge inside the clock perimeter |
| `background.widgets.clock.cookie.constantlyRotate` | `bool` | `false` | Continuously rotates the cookie shape |
| `background.widgets.clock.cookie.useSineCookie` | `bool` | `false` | Renders trigonometric sine-wave scalloped boundary |
| `background.widgets.clock.digital.adaptiveAlignment` | `bool` | `true` | Automatically centers or aligns digital clock |
| `background.widgets.clock.digital.showDate` | `bool` | `true` | Shows date underneath digital clock |
| `background.widgets.clock.digital.animateChange` | `bool` | `true` | Animates digit transitions |
| `background.widgets.clock.digital.vertical` | `bool` | `false` | Stacks hours above minutes vertically |
| `background.widgets.clock.digital.font.family` | `string` | `"Google Sans Flex"` | Digital clock font family |
| `background.widgets.clock.digital.font.weight` | `real` | `350` | Variable font weight |
| `background.widgets.clock.digital.font.width` | `real` | `100` | Variable font width |
| `background.widgets.clock.digital.font.size` | `real` | `90` | Font size in pixels |
| `background.widgets.clock.digital.font.roundness` | `real` | `0` | Variable font roundness grade |
| `background.widgets.clock.quote.enable` | `bool` | `false` | Displays custom quote text beside clock |
| `background.widgets.clock.quote.text` | `string` | `""` | Quote string |
| `background.widgets.weather.enable` | `bool` | `false` | Shows desktop weather widget |
| `background.widgets.weather.placementStrategy` | `string` | `"free"` | Weather widget placement strategy |
| `background.widgets.weather.x` / `y` | `real` | `400` / `100` | Coordinates for free placement |
| `background.wallpaperPath` | `string` | `""` | Path to active wallpaper image or video |
| `background.thumbnailPath` | `string` | `""` | Path to extracted video thumbnail image |
| `background.hideWhenFullscreen` | `bool` | `true` | Hides background layer when a window is fullscreen |
| `background.parallax.vertical` | `bool` | `false` | Parallax moves vertically |
| `background.parallax.autoVertical` | `bool` | `false` | Automatically picks parallax direction |
| `background.parallax.enableWorkspace` | `bool` | `false` | Wallpaper pans when switching workspaces |
| `background.parallax.workspaceZoom` | `real` | `1.07` | Wallpaper scale factor to allow parallax margin |
| `background.parallax.enableSidebar` | `bool` | `false` | Wallpaper shifts when sidebars open |
| `background.parallax.widgetsFactor` | `real` | `1.2` | Parallax movement multiplier for desktop widgets |
| `bar.autoHide.enable` | `bool` | `false` | Automatically hides bar until hovered |
| `bar.autoHide.hoverRegionWidth` | `int` | `2` | Screen edge thickness in pixels to detect hover |
| `bar.autoHide.pushWindows` | `bool` | `false` | Whether unhiding pushes windows or layers over |
| `bar.autoHide.showWhenPressingSuper.enable` | `bool` | `true` | Unhides bar while Super key is held |
| `bar.autoHide.showWhenPressingSuper.delay` | `int` | `140` | Milliseconds delay before Super unhides bar |
| `bar.bottom` | `bool` | `false` | Places bar on bottom of screen instead of top |
| `bar.cornerStyle` | `int` | `0` | Style: `0` = Hug (flush with curves), `1` = Float, `2` = Rect |
| `bar.floatStyleShadow` | `bool` | `true` | Renders drop shadow when cornerStyle is Float (`1`) |
| `bar.borderless` | `bool` | `false` | Removes grouping pill containers around bar modules |
| `bar.topLeftIcon` | `string` | `"spark"` | Icon at top-left: `"distro"` or SVG name from `assets/icons` |
| `bar.showBackground` | `bool` | `true` | Renders tinted background layer behind bar |
| `bar.verbose` | `bool` | `true` | Shows detailed date & utility buttons on bar |
| `bar.vertical` | `bool` | `false` | Switches to vertical bar mode |
| `bar.resources.alwaysShowSwap` | `bool` | `true` | Always shows Swap in resource monitor module |
| `bar.resources.alwaysShowCpu` | `bool` | `true` | Always shows CPU in resource monitor module |
| `bar.resources.memoryWarningThreshold` | `int` | `95` | RAM % triggering warning alert |
| `bar.resources.swapWarningThreshold` | `int` | `85` | Swap % triggering warning alert |
| `bar.resources.cpuWarningThreshold` | `int` | `90` | CPU % triggering warning alert |
| `bar.screenList` | `list<string>` | `[]` | Limit bar to specific monitors (e.g. `["eDP-1"]`); empty = all |
| `bar.utilButtons.showScreenSnip` | `bool` | `true` | Shows screen snip button on bar |
| `bar.utilButtons.showColorPicker` | `bool` | `false` | Shows color picker button on bar |
| `bar.utilButtons.showMicToggle` | `bool` | `false` | Shows mic mute button on bar |
| `bar.utilButtons.showKeyboardToggle` | `bool` | `true` | Shows OSK toggle button on bar |
| `bar.utilButtons.showDarkModeToggle` | `bool` | `true` | Shows dark/light theme toggle button on bar |
| `bar.utilButtons.showPerformanceProfileToggle` | `bool`| `false` | Shows power-profiles-daemon button on bar |
| `bar.utilButtons.showScreenRecord` | `bool` | `false` | Shows screen recording toggle button on bar |
| `bar.workspaces.monochromeIcons` | `bool` | `true` | Forces workspace app icons to monochrome tint |
| `bar.workspaces.shown` | `int` | `10` | Number of workspace slots shown in pager |
| `bar.workspaces.showAppIcons` | `bool` | `true` | Displays icons of running apps inside workspace pips |
| `bar.workspaces.alwaysShowNumbers` | `bool` | `false` | Always displays workspace numbers instead of icons |
| `bar.workspaces.showNumberDelay` | `int` | `300` | Delay before showing numbers on Super hold (ms) |
| `bar.workspaces.numberMap` | `list<string>` | `["1", "2"]`| Custom characters replacing workspace digits |
| `bar.workspaces.useNerdFont` | `bool` | `false` | Uses Nerd Font symbols for workspace numbers |
| `bar.weather.enable` | `bool` | `false` | Shows weather temperature on status bar |
| `bar.weather.enableGPS` | `bool` | `true` | Fetches location via QtPositioning GPS |
| `bar.weather.city` | `string` | `""` | Manual city fallback if GPS disabled |
| `bar.weather.useUSCS` | `bool` | `false` | Uses Fahrenheit/miles instead of Celsius/km |
| `bar.weather.fetchInterval` | `int` | `10` | Weather refresh interval in minutes |
| `bar.indicators.notifications.showUnreadCount`| `bool` | `false` | Shows numerical unread count badge on bell |
| `bar.tooltips.clickToShow` | `bool` | `false` | Tooltips require click rather than hover |
| `battery.low` | `int` | `20` | Battery percentage for low warning |
| `battery.critical` | `int` | `5` | Battery percentage for critical warning |
| `battery.full` | `int` | `101` | Battery percentage considered fully charged |
| `battery.automaticSuspend` | `bool` | `true` | Automatically suspends PC on critical battery |
| `battery.suspend` | `int` | `3` | Battery percentage triggering automatic suspend |
| `calendar.locale` | `string` | `"en-GB"` | Locale code for calendar formatting |
| `cheatsheet.superKey` | `string` | `""` | Icon character representing Super key |
| `cheatsheet.useMacSymbol` | `bool` | `false` | Uses ⌘/⌥ symbols instead of Super/Alt |
| `cheatsheet.splitButtons` | `bool` | `false` | Renders keys as separated badges |
| `cheatsheet.useMouseSymbol` | `bool` | `false` | Uses mouse icons |
| `cheatsheet.useFnSymbol` | `bool` | `false` | Uses Fn key icon |
| `conflictKiller.autoKillNotificationDaemons` | `bool` | `false` | Automatically kills `mako`/`dunst` without prompt |
| `conflictKiller.autoKillTrays` | `bool` | `false` | Automatically kills `kded6` tray without prompt |
| `crosshair.code` | `string` | `"0;P;d;1;0l;10;0o;2;1b;0"` | Valorant-format crosshair string |
| `dock.enable` | `bool` | `false` | Master toggle for the floating dock |
| `dock.monochromeIcons` | `bool` | `true` | Renders dock icons in monochrome tint |
| `dock.height` | `real` | `60` | Height of the dock in pixels |
| `dock.hoverRegionHeight` | `real` | `2` | Edge hover detection height in pixels |
| `dock.pinnedOnStartup` | `bool` | `false` | Pins dock open on boot |
| `dock.hoverToReveal` | `bool` | `true` | Reveals dock on hover (false = only on empty desktop)|
| `dock.pinnedApps` | `list<string>` | `["org.kde.dolphin", "kitty"]` | Array of pinned desktop application IDs |
| `dock.ignoredAppRegexes` | `list<string>` | `[]` | Regex patterns of window classes excluded from dock |
| `interactions.scrolling.fasterTouchpadScroll` | `bool` | `false` | Accelerates touchpad scrolling |
| `interactions.scrolling.mouseScrollDeltaThreshold` | `int` | `120` | Threshold distinguishing mouse wheel from touchpad |
| `interactions.deadPixelWorkaround.enable` | `bool` | `false` | Compensates for Hyprland 1px edge gap |
| `language.ui` | `string` | `"auto"` | Shell UI language (`"auto"`, `"en_US"`, `"zh_CN"`, etc.) |
| `language.translator.engine` | `string` | `"auto"` | `trans` engine (`"auto"` uses Google Translate) |
| `language.translator.targetLanguage` | `string` | `"auto"` | Target language for translation |
| `language.translator.sourceLanguage` | `string` | `"auto"` | Source language for translation |
| `launcher.pinnedApps` | `list<string>` | `["org.kde.dolphin", "kitty", "cmake-gui"]` | Pinned applications in overview search |
| `light.night.automatic` | `bool` | `true` | Schedules night light automatically by time |
| `light.night.from` / `to` | `string` | `"19:00"` / `"06:30"` | Night light active time window |
| `light.night.colorTemperature` | `int` | `5000` | Night light temperature in Kelvin |
| `light.antiFlashbang.enable` | `bool` | `false` | Enables Hyprland anti-flashbang GLSL shader |
| `lock.useHyprlock` | `bool` | `false` | Delegates locking to external `hyprlock` |
| `lock.enableMedia` | `bool` | `true` | Shows media playback controls on lock screen |
| `lock.blur.enable` | `bool` | `true` | Blurs wallpaper on lock screen |
| `lock.blur.radius` | `real` | `100` | Blur radius in pixels |
| `lock.blur.extraZoom` | `real` | `1.1` | Zoom factor applied to wallpaper under blur |
| `lock.centerClock` | `bool` | `true` | Centers lock screen clock |
| `lock.security.unlockKeyring` | `bool` | `true` | Automatically unlocks GNOME keyring on PAM success |
| `lock.materialShapeChars` | `bool` | `true` | Renders password dots as animating Material shapes |
| `media.filterDuplicatePlayers` | `bool` | `true` | Filters duplicate playerctld & browser D-Bus instances |
| `notifications.timeout` | `int` | `7000` | Toast notification timeout in milliseconds |
| `notifications.monitor.enable` | `bool` | `false` | Pins notifications to a specific monitor |
| `notifications.monitor.name` | `string` | `""` | Monitor name for notifications (e.g. `"DP-1"`) |
| `osd.timeout` | `int` | `1000` | OSD flyout display duration in milliseconds |
| `osk.layout` | `string` | `"qwerty_full"` | Virtual keyboard layout |
| `overlay.openingZoomAnimation` | `bool` | `true` | Enables zoom animation when opening desktop overlay |
| `overlay.darkenScreen` | `bool` | `true` | Darkens desktop background behind active overlay |
| `overlay.clickthroughOpacity` | `real` | `0.8` | Opacity of widgets when clickthrough is enabled |
| `overview.enable` | `bool` | `true` | Master switch for fullscreen overview & launcher |
| `overview.scale` | `real` | `0.18` | Thumbnail scale relative to screen size |
| `overview.rows` / `columns` | `real` | `2` / `5` | Workspace grid dimension layout |
| `regionSelector.targetRegions.windows` | `bool` | `true` | Auto-detects and snaps to Hyprland window boundaries |
| `regionSelector.annotation.useSatty` | `bool` | `false` | Opens screenshot in `satty` for annotation |
| `search.engineBaseUrl` | `string` | `"https://www.google.com/search?q="` | Default web search URL prefix |
| `search.prefix.action` | `string` | `"/"` | Prefix character for shell actions (e.g. `/dark`) |
| `search.prefix.app` | `string` | `">"` | Prefix for explicit app searches |
| `search.prefix.clipboard` | `string` | `";"` | Prefix for clipboard history search |
| `search.prefix.emojis` | `string` | `":"` | Prefix for emoji search |
| `search.prefix.math` | `string` | `"="` | Prefix for calculator / math evaluation |
| `search.prefix.shellCommand` | `string` | `"$" ` | Prefix to execute bash command directly |
| `search.prefix.webSearch` | `string` | `"?"` | Prefix for external web search |
| `sidebar.keepRightSidebarLoaded` | `bool` | `true` | Keeps right sidebar in memory for instant opening |
| `sidebar.quickToggles.style` | `string` | `"android"` | Quick settings style: `"android"` or `"classic"` |
| `sidebar.quickToggles.android.columns`| `int` | `5` | Column grid count for Android-style toggles |
| `time.format` | `string` | `"hh:mm"` | Clock format string (Qt QTime format) |
| `time.dateFormat` | `string` | `"ddd, dd/MM"` | Status bar date format string |
| `updates.enableCheck` | `bool` | `true` | Checks for Arch package updates in background |
| `updates.checkInterval` | `int` | `120` | Update check interval in minutes |
| `waffles.tweaks.smootherMenuAnimations` | `bool`| `true` | Enables smooth animations on Waffle start menu |
| `waffles.bar.bottom` | `bool` | `true` | Keeps Waffle taskbar pinned to the bottom |
| `waffles.bar.leftAlignApps` | `bool` | `false` | Aligns taskbar app icons to left instead of center |

---

## 5. Theming System

### 5.1 Color Generation Pipeline (Material You)
Colors are generated dynamically from the desktop wallpaper using **Matugen** and Google's **Material Color Utilities** (`materialyoucolor` Python library):

```
Wallpaper Image (.jpg/.png) or Video (.mp4)
                     │
                     ▼
  scripts/colors/switchwall.sh
         ├──▶ matugen (extracts palette & renders templates)
         │       └── Output: ~/.local/state/quickshell/user/generated/colors.json
         ├──▶ python3 scripts/colors/generate_colors_material.py
         │       └── Output: ~/.local/state/quickshell/user/generated/material_colors.scss
         └──▶ scripts/colors/applycolor.sh
                 ├── Output: ~/.local/state/quickshell/user/generated/terminal/kitty-theme.conf
                 └── Writes escape sequences directly to /dev/pts/*
```

1. **Wallpaper Switch:** [scripts/colors/switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh) is triggered. If a video is chosen, `ffmpeg` extracts the first frame to create a thumbnail.
2. **Matugen Execution:** Matugen runs with template `~/.config/matugen/templates/colors.json`, writing to `~/.local/state/quickshell/user/generated/colors.json`.
3. **Material SCSS & Terminal:** `generate_colors_material.py` calculates HCT harmonized terminal tones and exports `material_colors.scss`. Then `applycolor.sh` applies colors to Kitty and open TTY terminals.
4. **QML Loading:** [MaterialThemeLoader.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/MaterialThemeLoader.qml) watches `colors.json` via `FileView`. Upon changes, it converts snake_case keys (e.g. `surface_container_low`) to `m3${camelCase}` (e.g. `m3surfaceContainerLow`) and injects them directly into `Appearance.m3colors`.

### 5.2 Appearance Tokens (`Appearance.qml`)
[Appearance.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Appearance.qml) provides the central design tokens consumed by every widget:

- **Semantic Color Layers:**
  - `colLayer0Base` / `colLayer0`: Base background layer (`m3background` tinted with `m3primary`).
  - `colLayer1Base` / `colLayer1`: Lowest container layer (`m3surfaceContainerLow`).
  - `colLayer2Base` / `colLayer2`: Standard container card (`m3surfaceContainer`).
  - `colLayer3Base` / `colLayer3`: High elevation container (`m3surfaceContainerHigh`).
  - `colLayer4Base` / `colLayer4`: Highest container layer (`m3surfaceContainerHighest`).
  - Hover / Active variants: `colLayer1Hover`, `colLayer1Active`, `colLayer2Hover`, etc., computed using `ColorUtils.mix()` and `ColorUtils.solveOverlayColor()`.
- **Accent Tokens:**
  - `colPrimary`, `colOnPrimary`, `colPrimaryContainer`, `colOnPrimaryContainer`
  - `colSecondary`, `colOnSecondary`, `colSecondaryContainer`, `colOnSecondaryContainer`
  - `colTertiary`, `colError`, `colOutline`, `colShadow`, `colScrim`
- **Dynamic Transparency:**
  When `Config.options.appearance.transparency.enable` is `true`, `Appearance.qml` quantizes the wallpaper image to extract vibrancy:
  $$\text{autoBackgroundTransparency} = \max(0, \min(0.22, 0.5768x^2 - 0.759x + 0.2896)) - (0.12 \times \text{lightmode})$$
  This automatically adapts window translucency so text remains readable over any wallpaper.
- **Rounding Tokens (`Appearance.rounding`):**
  - `unsharpen: 2`, `unsharpenmore: 6`, `verysmall: 8`, `small: 12`, `normal: 17`, `large: 23`, `verylarge: 30`, `full: 9999`
  - `screenRounding: large (23)`, `windowRounding: 18`
- **Font Tokens (`Appearance.font`):**
  - Families: `main`, `numbers`, `title`, `iconMaterial` ("Material Symbols Rounded"), `iconNerd`, `monospace`, `reading`, `expressive`.
  - Variable Axes: `main: {"wght": 450, "wdth": 100}`, `title: {"wght": 550}`.
  - Sizes: `smallest: 10`, `smaller: 12`, `smallie: 13`, `small: 15`, `normal: 16`, `large: 17`, `larger: 19`, `huge: 22`, `hugeass: 23`, `title: 22`.
- **Animation Tokens (`Appearance.animation` & `animationCurves`):**
  - Physics-based Bezier splines:
    - `expressiveFastSpatial` `[0.42, 1.67, 0.21, 0.90, 1, 1]` (350ms)
    - `expressiveDefaultSpatial` `[0.38, 1.21, 0.22, 1.00, 1, 1]` (500ms)
    - `expressiveEffects` `[0.34, 0.80, 0.34, 1.00, 1, 1]` (200ms)
    - `emphasized` `[0.05, 0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1, 1, 1]`
  - Standard elements: `elementMove`, `elementMoveSmall`, `elementMoveEnter`, `elementMoveExit`, `elementMoveFast`, `elementResize`, `clickBounce`.

---

## 6. Reusable Components (`modules/common/widgets`)

All shared widgets reside in [modules/common/widgets/](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/widgets/). Common widgets include:

| Component | Key Properties | Purpose & Usage |
| :--- | :--- | :--- |
| **`StyledText`** | `font.pixelSize`, `font.family`, `color` | Standard text element adhering to `Appearance.font` and theme colors |
| **`MaterialSymbol`** | `text` (glyph name), `iconSize`, `color` | Google Material Symbols Rounded icon glyph renderer |
| **`CustomIcon`** | `icon`, `iconSize`, `color` | Intelligently renders Material Symbol, Nerd Font, or SVG icon |
| **`RippleButton`** | `buttonRadius`, `colBackground`, `colRipple`, `toggled`, `onClicked` | Material 3 clickable button with animated pointer ripple feedback |
| **`RippleButtonWithIcon`**| `materialIcon`, `nerdIcon`, `mainText`, `onClicked` | Pre-styled button containing an icon and label |
| **`StyledSwitch`** | `checked`, `scale`, `onCheckedChanged` | Material 3 smooth sliding toggle switch |
| **`StyledSlider`** | `value`, `from`, `to`, `stepSize`, `onMoved` | Continuous audio/brightness progress slider |
| **`Revealer`** | `reveal: bool`, `animationDuration` | Smoothly animates width/height to reveal or conceal child content |
| **`RoundCorner`** | `corner` (`CornerEnum.TopLeft/TopRight...`), `color` | Inverted curved corner drawing smooth transitions to screen edges |
| **`StyledDropShadow`** | `radius`, `samples`, `color`, `source` | Drop shadow effect wrapper around Qt GraphicalEffects |
| **`StyledRectangularShadow`**| `target: Item` | High-performance fast rectangular shadow behind panels |
| **`FadeLoader`** | `active: bool`, `sourceComponent` | Loader with cross-fade opacity transitions |
| **`MaterialCookie`** | `sides`, `rotation`, `color`, `strokeWidth` | Parametric cookie shape generator using Android 12+ squircle math |
| **`ConfigSwitch`** | `text`, `configPath`, `checked` | Form switch bound to `Config.options` |
| **`ConfigSelectionArray`** | `options: list<{displayName, value}>`, `currentValue` | Segmented option selector used in Settings |
| **`NavigationRail`** | `expanded: bool` | Vertical navigation bar used in Settings window |

---

## 7. Per-Module Breakdown

### 7.1 Status Bar (`modules/ii/bar` & `modules/ii/verticalBar`)
- **Files:** [Bar.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/Bar.qml), [BarContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/BarContent.qml), [Workspaces.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/Workspaces.qml), [Media.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/Media.qml), [ClockWidget.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/ClockWidget.qml), [SysTray.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/SysTray.qml), [Resources.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/Resources.qml).
- **Structure:**
  - **Left Section:** Left sidebar toggle button with scroll gesture for monitor brightness (`FocusedScrollMouseArea` -> `Brightness.increaseBrightness()`), active window title (`ActiveWindow.qml`).
  - **Center Section:** Grouped pill modules: System resource stats (`Resources.qml`), currently playing media title (`Media.qml`), interactive workspace pager (`Workspaces.qml`), clock/date with calendar popup (`ClockWidget.qml`), utility buttons (`UtilButtons.qml`).
  - **Right Section:** Status indicators (mic mute, volume mute, keyboard layout, Cloudflare WARP, Wi-Fi, battery, notifications), system tray icons (`SysTray.qml`), right sidebar toggle button with scroll gesture for PipeWire volume.
- **Modification Point:** Edit [BarContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/BarContent.qml) to change module order, spacing, or add new widgets.

### 7.2 Left Sidebar (`modules/ii/sidebarLeft`)
- **Files:** [SidebarLeft.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/SidebarLeft.qml), [SidebarLeftContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/SidebarLeftContent.qml), [AiChat.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/AiChat.qml), [Anime.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/Anime.qml), [Translator.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/Translator.qml).
- **Structure:**
  - Tab 0: **AI Assistant (`AiChat.qml`)**: Multi-turn chat interface with Markdown, code block copy, thinking tokens block, tool execution logs, model selector, API key input.
  - Tab 1: **Anime Wallpaper Booru (`Anime.qml`)**: Visual gallery search across Yande.re, Konachan, Danbooru, Gelbooru, and Zerochan with tag search and direct download/wallpaper setting.
  - Tab 2: **Translator (`Translator.qml`)**: Two-way language translator powered by `trans` CLI.
- **Modification Point:** Tabs are switched using `ToolbarTabBar` in [SidebarLeftContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/SidebarLeftContent.qml).

### 7.3 Right Sidebar (`modules/ii/sidebarRight`)
- **Files:** [SidebarRight.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarRight/SidebarRight.qml), [SidebarRightContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarRight/SidebarRightContent.qml), `quickToggles/`, `pomodoro/`, `calendar/`, `todo/`, `volumeMixer/`.
- **Structure:**
  - **Quick Toggles:** Android-style or classic grid of toggle tiles (`AndroidQuickPanel.qml` / `ClassicQuickPanel.qml`): Wi-Fi, Bluetooth, Audio Sink, Night Light, Idle Inhibitor, Mic, Cloudflare WARP, Game Mode, Anti-Flashbang.
  - **Quick Sliders:** Continuous sliders for Volume and Brightness.
  - **Notification Center:** Chronological list of incoming notifications grouped by application with dismiss and action buttons (`NotificationList.qml`).
  - **Bottom Tab Group:** Switcher between Monthly Calendar (`CalendarWidget.qml`), To-Do Checklist (`TodoWidget.qml`), and Pomodoro Timer / Stopwatch (`PomodoroWidget.qml`).
- **Modification Point:** Customize quick toggle layouts in [AndroidQuickPanel.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml) or toggle arrays in `Config.options.sidebar.quickToggles`.

### 7.4 Overview & Search (`modules/ii/overview`)
- **Files:** [Overview.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overview/Overview.qml), [OverviewWidget.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overview/OverviewWidget.qml), [OverviewWindow.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overview/OverviewWindow.qml), [SearchBar.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overview/SearchBar.qml), [SearchWidget.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overview/SearchWidget.qml).
- **Structure:**
  - Displays a live interactive grid of Hyprland workspaces with miniaturized live window representations (`OverviewWindow.qml`).
  - Centered unified search bar powered by [LauncherSearch.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/LauncherSearch.qml).
  - Prefix routing: `>` (applications), `/` (shell actions like `/dark`, `/wallpaper`), `;` (clipboard history), `:` (emojis), `=` (math calculations), `$` (bash commands), `?` (Google search).

### 7.5 Desktop Overlay (`modules/ii/overlay`)
- **Files:** [Overlay.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overlay/Overlay.qml), [OverlayContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overlay/OverlayContent.qml), [OverlayTaskbar.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overlay/OverlayTaskbar.qml), [StyledOverlayWidget.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/overlay/StyledOverlayWidget.qml).
- **Structure:**
  - Transparent desktop overlay activated via `Super+G` or IPC `overlay toggle`.
  - Hosts draggable, resizable desktop widgets: Gaming Crosshair, Scratchpad Notes, Performance Graphs, Floating Video/Image, Audio Volume Mixer.
  - Widget coordinates and pinned states are persisted automatically to `~/.local/state/quickshell/states.json` by [Persistent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Persistent.qml).

### 7.6 Lock Screen (`modules/ii/lock` & `modules/common/panels/lock`)
- **Files:** [Lock.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/lock/Lock.qml), [LockScreen.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/panels/lock/LockScreen.qml), [LockContext.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/panels/lock/LockContext.qml).
- **Structure:**
  - High-security Wayland Layer Shell surface locking input grab.
  - Multi-method authentication: Linux PAM password entry + `fprintd` fingerprint reader.
  - Media player controls, animated Material shape password character indicator, and optional wallpaper blur.
  - Option to delegate lock surface to external `hyprlock` (`Config.options.lock.useHyprlock`).

### 7.7 Wallpaper Selector (`modules/ii/wallpaperSelector`)
- **Files:** [WallpaperSelector.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/wallpaperSelector/WallpaperSelector.qml), [WallpaperSelectorContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/wallpaperSelector/WallpaperSelectorContent.qml).
- **Structure:**
  - Scans `~/Pictures/Wallpapers` using [Wallpapers.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Wallpapers.qml).
  - Background thumbnail generation with caching via `thumbgen.py` or ImageMagick.
  - Clicking any wallpaper applies it immediately via [switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh).

### 7.8 Region Selector (`modules/ii/regionSelector`)
- **Files:** [RegionSelector.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/regionSelector/RegionSelector.qml), [RegionSelection.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/regionSelector/RegionSelection.qml), [TargetRegion.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/regionSelector/TargetRegion.qml).
- **Structure:**
  - Interactive fullscreen overlay for cropping regions of the display using `grim` and `slurp`.
  - Automatically queries [HyprlandData.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/HyprlandData.qml) to highlight and magnetic-snap to active window borders.
  - Actions: Screen Snip (save/clipboard), Edit in Satty, Magnifier Color Picker (`hyprpicker`), OCR text extraction (`tesseract`), Google Lens image search.

---

## 8. External Dependencies

### 8.1 System Binaries & Commands Called

| Binary / Command | Purpose | Where Used |
| :--- | :--- | :--- |
| `matugen` | Generates Material You palette from wallpaper | [scripts/colors/switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh) |
| `hyprctl` | Queries monitors, windows, workspaces, keybinds, reload events | `HyprlandData.qml`, `HyprlandKeybinds.qml`, `switchwall.sh` |
| `grim` / `slurp` | Captures display screenshots and region geometry | `ScreenshotAction.qml`, `TempScreenshotProcess.qml` |
| `hyprpicker` | Screen pixel color picker | `RegionSelector.qml`, `ColorPickerToggle.qml` |
| `cliphist` / `wl-copy` | Clipboard history indexing and retrieval | `Cliphist.qml`, `CliphistImage.qml` |
| `songrec` | Shazam-compatible audio fingerprinting and music recognition | [scripts/musicRecognition/recognize-music.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/musicRecognition/recognize-music.sh) |
| `wf-recorder` | Wayland screen video recording | [scripts/videos/record.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/videos/record.sh) |
| `ffmpeg` / `mpvpaper` | Animated video wallpaper playback & thumbnail extraction | `switchwall.sh` |
| `trans` (translate-shell) | Command line multi-engine translation | `Translator.qml`, `ScreenTranslator.qml` |
| `tesseract` | Optical character recognition (OCR) | `RegionSelector.qml`, `ScreenTranslator.qml` |
| `fprintd` | Fingerprint authentication list and verify | `LockContext.qml` |
| `secret-tool` / `keyring`| GNOME Keyring credential lookup for AI API keys | [scripts/keyring/try_lookup.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/keyring/try_lookup.sh) |
| `hyprsunset` | Blue light filter / color temperature adjustment daemon | [services/Hyprsunset.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Hyprsunset.qml) |
| `ddcutil` / `brightnessctl` | Monitor hardware brightness controls | [services/Brightness.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Brightness.qml) |
| `warp-cli` | Cloudflare WARP VPN connection state and toggling | `CloudflareWarpToggle.qml` |
| `easyeffects` | Audio equalizer and effects daemon | `EasyEffects.qml` |
| `nmcli` | NetworkManager Wi-Fi scanning and connection control | [services/Network.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Network.qml) |
| `bluetoothctl` | Bluetooth adapter and device pairing state | [services/BluetoothStatus.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/BluetoothStatus.qml) |
| `satty` | Screenshot annotation editor | `RegionSelector.qml` |
| `checkupdates` / `pacman` / `yay` | Package update checking and running updates in terminal | [services/Updates.qml](file:///home/nitesh/.config/quickshell/ii_clander/services/Updates.qml) |
| `systemctl` / `loginctl` | Suspend, hibernate, reboot, and poweroff session commands | [modules/common/functions/Session.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/functions/Session.qml) |
| `curl` / `wget` | Fetching weather (`wttr.in`), favicons, web booru images | `Weather.qml`, `Favicon.qml`, `Booru.qml` |

### 8.2 Internal Scripts Overview (`scripts/`)
- **[scripts/colors/switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh):** The master wallpaper change script. Accepts `--image <path>`, `--mode <dark|light>`, `--type <scheme>`, or `--noswitch`. Runs matugen, python color generation, and terminal color propagation.
- **[scripts/colors/generate_colors_material.py](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/generate_colors_material.py):** Python script requiring `materialyoucolor` and `Pillow`. Generates extended Material dynamic colors and harmonized terminal ANSI colors.
- **[scripts/colors/applycolor.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/applycolor.sh):** Replaces color hex placeholders in Kitty config and outputs ANSI escape codes to all `/dev/pts/*` virtual terminals.
- **[scripts/images/least_busy_region.py](file:///home/nitesh/.config/quickshell/ii_clander/scripts/images/least_busy_region.py):** Edge-detection algorithm (Sobel filter / OpenCV / Pillow) analyzing a wallpaper to compute the least visually busy area for desktop clock placement.
- **[scripts/thumbnails/thumbgen.py](file:///home/nitesh/.config/quickshell/ii_clander/scripts/thumbnails/thumbgen.py):** Generates freedesktop standard thumbnail caches for images in `~/Pictures/Wallpapers`.
- **[scripts/ai/gemini-categorize-wallpaper.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/ai/gemini-categorize-wallpaper.sh):** Calls Gemini Vision API to classify wallpaper style and select clock cookie shapes.
- **[scripts/ai/gemini-translate.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/ai/gemini-translate.sh):** Translates shell localization catalogs (`translations/en_US.json` -> target locale) via Gemini API.

---

## 9. Conventions

### 9.1 Coding Style & Imports
- **Imports:** Common modules are imported using `qs.modules.common`, `qs.modules.common.widgets`, and `qs.services`. Function singletons are imported as namespaces, e.g. `import qs.modules.common.functions as CF`.
- **Pragmas:** Singletons must start with:
  ```qml
  pragma Singleton
  pragma ComponentBehavior: Bound
  ```
- **Names:**
  - Singletons and components are `PascalCase` (`Appearance.qml`, `RippleButton.qml`).
  - Waffle family components use a `W` prefix (`WButton.qml`, `WaffleBar.qml`).
  - Signal handlers use Qt 6 method syntax: `onClicked: (mouse) => { ... }`.
  - String translations must always be wrapped in `Translation.tr("Text")`.

### 9.2 Recipe: Adding a New Config Toggle
1. **Define Schema:** Open [modules/common/Config.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Config.qml). Locate the appropriate `JsonObject` inside `configOptionsJsonAdapter` (e.g. `bar`):
   ```qml
   property JsonObject bar: JsonObject {
       ...
       property bool showCustomBadge: true
   }
   ```
2. **Access in QML:** Reference reactively anywhere via:
   ```qml
   visible: Config.options.bar.showCustomBadge
   ```
3. **Add to Settings UI:** Open the corresponding settings page (e.g. [modules/settings/BarConfig.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/settings/BarConfig.qml)) and insert a toggle row:
   ```qml
   ConfigSwitch {
       text: Translation.tr("Show custom badge")
       checked: Config.options.bar.showCustomBadge
       onCheckedChanged: Config.options.bar.showCustomBadge = checked
   }
   ```

### 9.3 Recipe: Adding a New Service
1. Create `services/MyService.qml` with `pragma Singleton`.
2. Wrap state in properties and controls in functions:
   ```qml
   pragma Singleton
   pragma ComponentBehavior: Bound
   import QtQuick
   import Quickshell
   import Quickshell.Io
   import qs.modules.common

   Singleton {
       id: root
       property string status: "idle"
       function refresh() { /* ... */ }
   }
   ```
3. Access anywhere as `MyService.status` without manual instantiation.

---

## 10. Common Customization Recipes

| Task | Target File & Location | Guidance |
| :--- | :--- | :--- |
| **Change Status Bar Layout** | [modules/ii/bar/BarContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/BarContent.qml) | Rearrange children inside `leftSectionRowLayout` (L83), `middleSection` (L104), or `rightSectionRowLayout` (L223). |
| **Add Widget to Status Bar** | [modules/ii/bar/BarContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/bar/BarContent.qml) | Place widget inside `BarGroup` in `middleSection` or as a `RippleButton` in `rightSectionRowLayout`. |
| **Change Left Sidebar Contents**| [modules/ii/sidebarLeft/SidebarLeftContent.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/SidebarLeftContent.qml) | Modify tab array, or edit [AiChat.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/AiChat.qml) / [Anime.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarLeft/Anime.qml) directly. |
| **Change Right Sidebar Toggles**| [modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml) | Add or reorder toggle delegates in the `Repeater` model, or modify default toggles list in [Config.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Config.qml) (`sidebar.quickToggles.android.toggles`). |
| **Change Fonts** | `~/.config/illogical-impulse/config.json` | Edit `appearance.fonts.main`, `numbers`, or `title`. Mapped in [Appearance.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Appearance.qml) L214. |
| **Change UI Element Sizes** | [modules/common/Appearance.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Appearance.qml) | Edit properties under `sizes: QtObject { ... }` (L387), such as `baseBarHeight`, `sidebarWidth`, or `mediaControlsWidth`. |
| **Tweak Animations & Curves** | [modules/common/Appearance.qml](file:///home/nitesh/.config/quickshell/ii_clander/modules/common/Appearance.qml) | Adjust Bezier control points under `animationCurves` (L251) or durations under `animation` (L270). |
| **Change Global Keybind Actions**| `~/.config/hypr/hyprland/keybinds.lua` | Update Hyprland dispatchers calling `hl.dsp.global("quickshell:<shortcutName>")` matching `GlobalShortcut { name: "<shortcutName>" }`. |
| **Add New IPC Trigger** | In the target panel file (e.g. `Bar.qml`) | Add a function inside `IpcHandler { target: "mytarget"; function myAction(): void { ... } }`. Call with `qs -c ii ipc call mytarget myAction`. |

---

## 11. Open Questions

1. **Virtual Environment Environment Variable (`$ILLOGICAL_IMPULSE_VIRTUAL_ENV`):**  
   Several Python scripts ([generate_colors_material.py](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/generate_colors_material.py), [least-busy-region-venv.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/images/least-busy-region-venv.sh), [thumbgen-venv.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/thumbnails/thumbgen-venv.sh)) rely on `source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate"`. It is UNCLEAR whether this environment variable is globally defined on non-standard setups. If it is undefined, Python helper scripts requiring `materialyoucolor`, `PIL`, or `cv2` will fail unless packages exist in the system-level Python environment.
2. **Directory Name Divergence (`ii_clander` vs `ii`):**  
   The active workspace folder is named `ii_clander`, but hardcoded references in bash scripts ([switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh) L3, [applycolor.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/applycolor.sh) L3) define `QUICKSHELL_CONFIG_NAME="ii"`. If Quickshell is invoked with `qs -c ii_clander`, scripts defaulting to `~/.config/quickshell/ii` may look in the wrong directory unless a symlink exists.
3. **External Helper Scripts:**  
   Options such as `Config.options.apps.volumeMixer` reference `~/.config/hypr/hyprland/scripts/launch_first_available.sh` and [switchwall.sh](file:///home/nitesh/.config/quickshell/ii_clander/scripts/colors/switchwall.sh) references `~/.config/matugen/templates/kde/kde-material-you-colors-wrapper.sh`. These reside outside this Quickshell folder in the broader `end4-dots-hyprland` tree. Their exact fallback behavior if missing is UNCLEAR.
