# dmgbuild settings for Welp's DMG window; scripts/build-dmg.sh passes `app` and
# `background`. The background (660x400, with @2x) is exported from the Welp Figma file;
# the icon centres line up with its arrow.
import os.path

app = defines["app"]
appname = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [appname]

background = defines["background"]
# The window is taller than the background: Finder adds the title bar (32pt) and a status
# bar it now always shows (28pt).
window_rect = ((200, 160), (660, 460))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
icon_locations = {appname: (180, 200), "Applications": (480, 200)}
