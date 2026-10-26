# Colima Control Panel

A Mac app for [Colima](https://github.com/abiosoft/colima). Open a window or the menu bar to see your containers, watch their CPU and memory, read their logs, and start or stop the VM.

It talks to Colima's Docker socket. No server runs in the background, and nothing leaves your Mac.

This is an independent project. It has no affiliation with Colima or its maintainers.

## What you get

- **Containers**, grouped by Compose project. Each shows uptime, CPU and memory graphs, ports, mounts, networks, environment, and a live log. Environment values with names like `PASSWORD` or `TOKEN` stay hidden until you click.
- **Volumes, images, and networks** in sortable tables. Each row opens a panel that shows what uses it and how it is configured. Remove and prune sit behind a confirmation.
- **The VM**. Start, stop, and restart Colima with live output. When Colima is down, the window shows a Start button instead of an empty list.
- **A menu bar icon**. A small jellyfish whose core turns green, yellow, or red with the health of your running containers.
- **Quick actions**. Press `⌘K` for a command palette, `/` to filter, and the arrow keys to move through rows. Right-click the Dock icon for "Stop All Running Containers".
- **Setup on first launch**. The app checks that Colima is installed, shows the CPU, memory, and disk it uses (or suggests values for your Mac), and lets you keep or change them. Settings has the same controls.
- **An optional Dock badge** with the number of running containers. It is off by default.

## Requirements

- macOS 26 (Tahoe) or later
- [Colima](https://github.com/abiosoft/colima) and the Docker CLI: `brew install colima docker`

## Install

Build from source. You need Xcode 26 or later.

```sh
git clone https://github.com/mxttbennett/colima-ctrl-swift.git
cd colima-ctrl-swift
scripts/build-app.sh
open "build/Colima Control Panel.app"
```

Drag the app into `/Applications` to keep it. The build uses an ad hoc signature, so macOS may ask you to right-click the app and choose Open the first time.

## Use a different Colima profile

The app manages the `default` profile. To use another, launch it with `COLIMA_PROFILE=work`.

## How it works

- Containers, images, volumes, and networks come from the Docker API over `~/.colima/<profile>/docker.sock`.
- Start, stop, and restart run the `colima` command. Changing resources edits the `cpu`, `memory`, and `disk` lines in `colima.yaml`, leaves the rest alone, and saves a `.bak` copy first.
- Graphs refresh while the window or menu bar popover is on screen and pause otherwise. CPU comes from successive one-shot samples.
- At idle with the window open, the app uses about 0.6% CPU and 70 to 120 MB of memory.

## Develop

```sh
swift test
```

The tests include checks against a running Colima socket. They skip themselves when Colima is stopped. `scripts/render-icon.swift` regenerates the icon artwork. [docs/releasing.md](docs/releasing.md) covers packaging and Homebrew.

## License

[MIT](LICENSE)
