# Releasing

How to ship a new version and publish it on Homebrew.

## Package a release

```sh
git tag v0.1.0 && git push origin v0.1.0
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notary" \
scripts/package.sh
```

`scripts/package.sh` builds the app, signs it, submits it to Apple's notary service, staples the ticket, zips it, and prints the SHA-256. Without `CODESIGN_IDENTITY` it produces an ad-hoc signed zip, which macOS quarantines on download. Without `NOTARY_PROFILE` it skips notarization.

Create the notary profile once:

```sh
xcrun notarytool store-credentials notary --apple-id you@example.com --team-id TEAMID
```

Upload the zip to a GitHub release for the tag.

## Publish to Homebrew

Create a tap, a public repository named `homebrew-tap`, and add `Casks/colima-control-panel.rb`:

```ruby
cask "colima-control-panel" do
  version "0.1.0"
  sha256 "PASTE_THE_SHA256_HERE"

  url "https://github.com/mxttbennett/colima-control-panel/releases/download/v#{version}/ColimaControlPanel-#{version}.zip"
  name "Colima Control Panel"
  desc "Dashboard and menu bar companion for Colima"
  homepage "https://github.com/mxttbennett/colima-control-panel"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :tahoe"
  depends_on formula: "colima"

  app "Colima Control Panel.app"

  zap trash: "~/Library/Preferences/dev.mxttbennett.colima-ctrl.plist"
end
```

People install it with:

```sh
brew tap mxttbennett/tap
brew trust mxttbennett/tap
brew install --cask colima-control-panel
```

For each new version, update `version` and `sha256` in the cask and push.

## The official cask repository

`homebrew/cask` accepts an app after it has public traction: 30 forks, 30 watchers, or 75 stars, or 90, 90, or 225 for a submission by the repository owner. The repository must be public and at least 30 days old, and the app must be signed and notarized. Start with your own tap and submit later.
