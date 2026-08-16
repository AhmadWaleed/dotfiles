# Ghostty config

## Overridden keybindings

| Keybind | Action | Mimics (iTerm2/Mac) |
|---|---|---|
| `performable:ctrl+c` | `copy_to_clipboard` | - |
| `ctrl+v` | `paste_from_clipboard` | - |
| `global:ctrl+grave` | `toggle_quick_terminal` | - |
| `ctrl+alt+t` | `new_tab` | Cmd+T |
| `ctrl+alt+w` | `close_surface` | Cmd+W |
| `ctrl+alt+shift+w` | `close_window` | Cmd+Shift+W |
| `ctrl+alt+shift+[` | `previous_tab` | Cmd+Shift+[ |
| `ctrl+alt+shift+]` | `next_tab` | Cmd+Shift+] |
| `ctrl+alt+1` .. `ctrl+alt+8` | `goto_tab:1` .. `goto_tab:8` | Cmd+1 .. Cmd+8 |
| `ctrl+alt+9` | `last_tab` | Cmd+9 |
| `ctrl+alt+d` | `new_split:right` | Cmd+D |
| `ctrl+alt+shift+d` | `new_split:down` | Cmd+Shift+D |
| `ctrl+alt+[` | `goto_split:previous` | Cmd+[ |
| `ctrl+alt+]` | `goto_split:next` | Cmd+] |
| `ctrl+alt+shift+arrow_up/down/left/right` | `resize_split:...,10` | Cmd+Ctrl+Arrows |
| `ctrl+alt+shift+=` | `equalize_splits` | Cmd+Ctrl+= |
| `ctrl+alt+=` / `ctrl+alt++` | `increase_font_size:1` | Cmd+= |
| `ctrl+alt+-` | `decrease_font_size:1` | Cmd+- |
| `ctrl+alt+0` | `reset_font_size` | Cmd+0 |
| `ctrl+alt+c` | `copy_to_clipboard` | Cmd+C |
| `ctrl+alt+v` | `paste_from_clipboard` | Cmd+V |
| `ctrl+alt+f` | `start_search` | Cmd+F |
| `ctrl+alt+k` | `clear_screen` | Cmd+K |
| `ctrl+alt+a` | `select_all` | Cmd+A |
| `ctrl+alt+n` | `new_window` | Cmd+N |
| `ctrl+alt+enter` | `toggle_fullscreen` | Cmd+Enter |
| `ctrl+alt+shift+q` | `close_all_windows` | Cmd+Shift+Option+W |
| `ctrl+alt+shift+enter` | `toggle_split_zoom` | Cmd+Shift+Enter |
| `ctrl+alt+,` | `open_config` | Cmd+, |
| `ctrl+alt+shift+,` | `reload_config` | Cmd+Shift+, |
| `ctrl+alt+i` | `inspector:toggle` | Cmd+Option+I |
| `ctrl+alt+home` | `scroll_to_top` | Cmd+Home |
| `ctrl+alt+end` | `scroll_to_bottom` | Cmd+End |
| `ctrl+alt+page_up` | `scroll_page_up` | Cmd+PageUp |
| `ctrl+alt+page_down` | `scroll_page_down` | Cmd+PageDown |

Full definitions live in [`config.ghostty`](./config.ghostty).
