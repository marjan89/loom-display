# Display Plugin

Manage macOS display configurations through syntropy.

## Features

- **Switch resolutions** - Change display resolution and refresh rate
- **Display arrangement** - Toggle mirroring, extended desktop, and primary display
- **Display info** - View detailed display configuration

## Requirements

```bash
brew install jakehilborn/jakehilborn/displayplacer
```

## Installation

Add to your `~/.config/syntropy/plugins.toml`:

```toml
[plugins.syntropy-display]
git = "https://github.com/marjan89/display.git"
tag = "v1.0.0"
```

## Tasks

- `resolution` - Switch display resolution and refresh rate
- `arrangement` - Configure mirroring, extended desktop, and primary display
- `info` - Show current display configuration details

## Usage

```bash
# Launch display plugin
syntropy --plugin display

# Switch resolution
syntropy execute --plugin display --task resolution --items "DELL S3221QS - 3840x2160 @ 60Hz"

# Mirror displays
syntropy execute --plugin display --task arrangement --items "󰍺 Switch to Mirrored Displays"

# View display info
syntropy execute --plugin display --task info
```

## Icons

- ◍ - Current/Active (default)
- ○ - Available (default)

Icons can be customized - see `config_example.lua` for details.

## License

MIT - See [LICENSE](LICENSE) for details.
