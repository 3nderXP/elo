# Elo branding assets

- `banner-frame.png`: compact primary repository banner; preserves the framed
  logo, chest, and Tux without relying on a wide background crop.
- `banner.png`: full promotional hero for release posts and social previews.
- `logo.png`: standalone wordmark for compact placements, avatars, and future
  graphical surfaces where the full frame would be too dense.
- `elo.asc`: terminal wordmark installed with Elo and rendered by Gum on the
  main interactive menu when the terminal has enough space.

Keep runtime code independent of PNG rendering. Terminal presentation must use
the ASCII asset and the centralized Gum theme colors.
