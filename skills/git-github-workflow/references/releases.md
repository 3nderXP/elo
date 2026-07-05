# Versioning and releases

Use `vMAJOR.MINOR.PATCH`. PATCH fixes compatibility, MINOR adds compatible
features, and MAJOR introduces incompatibility. Document incompatibilities
explicitly during `0.x`.

Never tag feature, fix, release, or develop branches. After the release PR is
merged into `main`, create the tag and release through GitHub’s **Draft a new
release** flow. Use the same value for tag and title, such as `v0.1.0`.

Published tags are immutable. Fix a release with a new version. Install an
exact version by fetching `install.sh` from that tag and passing the same tag
through `--ref`.
