# iNiR

**A complete desktop shell for Niri, built on Quickshell.**

Not a theme. Not dotfiles. The entire desktop interface: bar, sidebars, dock, notifications, settings, theming, everything. One process, one runtime, no separate daemon.

Built on [Quickshell](https://quickshell.outfoxxed.me/) (QML shell framework) for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

---

## Quick navigation

<div class="grid cards" markdown>

- :material-download: **Getting Started**

  ---

  Install iNiR, run the setup wizard, get a shell on screen.

  [:octicons-arrow-right-24: Installation](INSTALL.md)

- :material-view-dashboard: **Panel Families**

  ---

  Material ii (5 styles) and Waffle (Windows 11). How they work, how to switch.

  [:octicons-arrow-right-24: Panel families](PANEL_FAMILIES.md)

- :material-palette: **Theming**

  ---

  Wallpaper-based colors, 44 presets, and the pipeline that themes your entire system.

  [:octicons-arrow-right-24: Theming architecture](THEMING_ARCHITECTURE.md)

- :material-console: **IPC Reference**

  ---

  All targets and functions you can call from keybinds, scripts, or terminal.

  [:octicons-arrow-right-24: IPC targets](IPC.md)

- :material-calendar-sync: **Calendar**

  ---

  Sync Google Calendar, Outlook, Nextcloud, or any ICS calendar.

  [:octicons-arrow-right-24: Calendar setup](CALENDAR.md)

- :material-wrench: **Architecture**

  ---

  How it all fits together. Entry point, services, config, panel loading.

  [:octicons-arrow-right-24: Architecture](ARCHITECTURE_OVERVIEW.md)

</div>

---

## What it looks like

Two panel families, switchable at runtime with `Super+Shift+W`:

|               | **Material ii**                      | **Waffle**                    |
| ------------- | ------------------------------------ | ----------------------------- |
| Design tokens | `Appearance.*`                       | `Looks.*`                     |
| Bar position  | Top (or vertical)                    | Bottom taskbar                |
| Launcher      | Overview (`Super+Space`)             | Start Menu                    |
| Right panel   | Sidebar (toggles, calendar, tools)   | Action Center + Notification Center |
| Styles        | material, cards, aurora, inir, angel | Fluent                        |

## Common commands

```bash
inir run            # start the shell
inir restart        # restart running instance
inir settings       # open settings UI
inir logs           # view runtime logs
inir doctor         # health checks and auto-fix
inir update         # pull + migrate + restart
```

## The stack

| Layer | What it does |
|-------|-------------|
| **QML runtime** | Quickshell + 760 QML files. Both the UI and system integration in one process. |
| **Bash control plane** | `scripts/inir` (2400+ lines). Launcher, service lifecycle, IPC routing, diagnostics. |
| **Python / Go tooling** | Color pipeline, Niri config generation, external app theme generators. |

Primary compositor: **Niri**. Secondary Hyprland support maintained from the fork origin.

---

## Key directories

| Path | What's in it |
|------|-------------|
| `shell.qml` | Entry point. Singleton init, panel family dispatch. |
| `services/` | [70+ singletons](SERVICES.md). Audio, network, Niri IPC, theming, everything. |
| `modules/` | [All UI](MODULES.md). 676 QML files across 30+ module directories. |
| `modules/common/` | Config, Appearance tokens, 130+ shared widgets. |
| `defaults/config.json` | Default configuration (~1100 lines, 51 sections). |
| `scripts/inir` | CLI launcher and IPC router. |
| `scripts/colors/` | Wallpaper-to-color pipeline. |

---

This documentation reflects the `main` branch. For the repo-level overview, see [ARCHITECTURE.md](https://github.com/snowarch/inir/blob/main/ARCHITECTURE.md).
