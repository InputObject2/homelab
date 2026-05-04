# Changelog

## [0.2.0](https://github.com/InputObject2/homelab/compare/v0.1.0...v0.2.0) (2026-05-04)


### Features

* add asterisk install script ([2cf2e90](https://github.com/InputObject2/homelab/commit/2cf2e90bda520de4e6fec35017dafa501ea612f5))
* add build time scripts to report on vm creation ([80ee162](https://github.com/InputObject2/homelab/commit/80ee162ca5b4ea991d7c307f42c8fcdcd74a8403))
* add cloud-init runner script for diagnostics collection and S3 upload ([208a92d](https://github.com/InputObject2/homelab/commit/208a92d4bd596ff2ecca3cd877df5f1b75d32796))


### Bug Fixes

* correct collector names to match actual script filenames ([64b8d9b](https://github.com/InputObject2/homelab/commit/64b8d9b98c4c2856856d2555fdf67bbc4f7c8026))
* disable set -e around FreePBX install to handle non-zero exit ([e7ef006](https://github.com/InputObject2/homelab/commit/e7ef006a4b8355f4ad97351d9e08cf97afdf2425))
* remove get_addon_source.sh call removed in Asterisk 21+ ([61a4b6a](https://github.com/InputObject2/homelab/commit/61a4b6a2cd06cc57b8e32306cff83bc8483f7517))
* source lib/common.sh relative to SCRIPT_DIR not REPO_ROOT ([8ef424a](https://github.com/InputObject2/homelab/commit/8ef424a8a8dc9160b73979856c6f8ed731d0da87))
* update Asterisk version to 22.9.0 (22.8.2 does not exist) ([cbee343](https://github.com/InputObject2/homelab/commit/cbee343ca3c5d96f870dff6811dd7e17fbbf6dcb))
