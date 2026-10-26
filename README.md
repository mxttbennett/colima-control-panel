# Colima Ctrl (native)

A native macOS app for [Colima](https://github.com/abiosoft/colima): a Liquid Glass window and a menu bar item. It talks to the Docker socket directly, so there is no server and no browser tab.

A browser version of the same dashboard lives in [colima-ctrl](https://github.com/mxttbennett/colima-ctrl).

- Containers grouped by Compose project, with live uptime, CPU and memory graphs, ports, mounts, networks, environment (secrets hidden until clicked) and streaming logs
- Volumes, images and networks with sortable tables, remove and prune, and a detail panel for each row (mountpoint and labels, digest and environment, subnet and connected containers), with the containers that use it one click away
- Start, stop and restart Colima, with live output, and a Start screen when the VM is down
- Menu bar status dot (green, yellow, red) and a quick list of running containers
- Command palette (`⌘K`), filter, arrow-key navigation
- Dock badge with the running container count, off by default (Settings, `⌘,`), and a "Stop All Running Containers" item in the Dock menu
- First-run setup that checks Colima is installed, shows its current resources (or suggests defaults for your Mac) to keep or change, and a Settings window with installation status, version, and the same resource controls

## Build

Needs macOS 26 and Xcode 26 or later, and a running [Colima](https://github.com/abiosoft/colima) (`brew install colima docker`).

```sh
scripts/build-app.sh
open "build/Colima Ctrl.app"
```

The script builds a release binary, compiles the layered icon with `actool`, and ad-hoc signs the bundle. The icon artwork is rendered from a SceneKit scene; regenerate it with `swift scripts/render-icon.swift Resources/AppIcon.icon/Assets/art.png`.

## Performance

- Stats are sampled only while the window or menu bar popover is showing, using one-shot requests whose CPU is computed locally from successive samples.
- Docker events drive refreshes; bursts are coalesced into one refresh.
- Each container's graph data is its own observable object, so a stats tick redraws only the rows that changed.
- Log lines are demuxed off the main thread and applied in 80 ms batches.
- Glass is used for controls and navigation; content cards are flat fills.
- The container detail panel overlays the list rather than resizing it, slides in over 80 ms (none with Reduce Motion), and stays mounted for a few seconds after closing. Selection redraws only the two rows involved.

## Test

```sh
swift test
```

The core tests include a live check against your Colima socket when one is running.

## Configuration

`COLIMA_PROFILE` selects a Colima profile (default `default`).

## License

[MIT](LICENSE)
