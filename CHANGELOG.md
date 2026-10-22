# Changelog

## v2.5.1 (125-5d29538-release)

## v2.5.0 (125-5d29538-release)
- chore(deps): bump webui from `28c71d7` to `1708288` (#16)
- build: update git submodule
- build: include the WebUI Monet initialization fix
  - Update the WebUI submodule to 5692d42 so restored switch state uses
  - strict booleans and invalid preferences remain disabled.
- build: include optional Monet themes in WebUI
  - Update the WebUI submodule to 4839189, which adds a persisted opt-in
  - Monet switch and generated light and dark color palettes.
- build: pin WebUI builds with a Git submodule
  - Build the WebUI revision tracked at webui/ in CI and local builds.
  - Check for submodule updates daily with Dependabot targeting dev.
- chore(docs): 添加赞助方式

## v2.4.0 (119-8bef714-release)
- fix: stabilize http-meta VPN bypass
- fix: keep action results visible
- fix: bypass auto_redirect with connmark
- fix: use connmark for transparent proxy bypass
- feat: apply optional http-meta extra fwmark
- feat: add optional http-meta extra fwmark
- docs: document http-meta VPN bypass
- fix: tolerate missing IPv6 iptables
- feat: bypass Android VPN for http-meta
- feat: add http-meta VPN bypass option

## v2.3.1 (109-357d66b-release)

### Full Changelog
- [Commit history](https://github.com/lanyi233/Sub-Store-Module/commits/main/)

