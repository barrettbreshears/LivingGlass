# AGENTS.md

> Guidelines for AI agents working in the LivingGlass codebase.

## Project Overview

LivingGlass is a macOS desktop wallpaper and screen saver that renders Conway's Game of Life as animated isometric 3D cubes using Metal GPU rendering at 60fps.

**Two build targets:**

- `LivingGlass.app` — Menu bar wallpaper app (runs behind all windows)
- `LivingGlass.saver` — macOS screen saver bundle

## Build Commands

```bash
# Build both app and screen saver (no Xcode project needed)
./build.sh

# Prerequisites (one-time)
xcode-select --install
xcodebuild -downloadComponent MetalToolchain
```

The build script:

1. Compiles Metal shaders via `xcrun metal` → `default.metallib`
2. Compiles Swift sources via `swiftc` with frameworks (AppKit, Metal, MetalKit)
3. Bundles into `build/LivingGlass.app` and `build/LivingGlass.saver`

**No Xcode project** — everything builds via command-line tools.

## Code Organization

```
Sources/
├── main.swift           # App entry point, sets activation policy
├── AppDelegate.swift    # Window management, menu bar, power state
├── GameOfLifeView.swift # Main view, animation loop, instance buffer
├── GameEngine.swift     # Game of Life logic, precomputation, patterns
├── MetalRenderer.swift  # Metal pipeline, vertex/instance buffers
└── Shaders.metal        # Vertex/fragment shaders for isometric cubes

ScreenSaver/
├── LivingGlassView.swift  # ScreenSaverView subclass
└── Info.plist             # Bundle config (NSPrincipalClass)
```

## Architecture

### Rendering Pipeline

1. **GameEngine** precomputes 1000 game states in background (`precompute(steps:)`)
2. **GameOfLifeView** consumes diffs every 120 frames (~2s at 60fps)
3. Animation states (`CellAnim`) track spawning/alive/dying per cell
4. **buildAndRender()** constructs `CubeInstance` array each frame
5. **MetalRenderer** uploads instances and draws via instanced rendering

### Key Patterns

- **Precomputed diffs**: CPU batch-computes game states on utility queue, main thread only handles animation
- **Instance buffer**: All cubes drawn in one draw call using Metal instancing
- **Depth sorting**: Grid position → normalized depth passed to shader via `leftColor.a`
- **Bundle injection**: `GameOfLifeView(frame:bundle:)` for screen saver to load Metal shaders from its own bundle

### Data Flow

```
GameEngine.precompute() → [GameDiff] queue
    ↓
GameOfLifeView.applyNextDiff() → updates anims[][]
    ↓
buildAndRender() → [CubeInstance] → MetalRenderer
    ↓
GPU: vertex_main() transforms per instance → fragment_main()
```

## Conventions

### Naming

- Swift: `camelCase` for properties/methods, `PascalCase` for types
- Metal: `snake_case` for shader functions
- Constants: inline in the file that uses them (e.g., `gameTickEvery = 120`)

### Structs Must Match Shader

These Swift structs must match Metal definitions exactly:

| Swift             | Metal        | Purpose                   |
| ----------------- | ------------ | ------------------------- |
| `Vertex`          | `VertexIn`   | Cube template vertices    |
| `CubeInstance`    | `InstanceIn` | Per-cube transform/colors |

### Color Handling

- **Palette**: 24 colors in `GameEngine.palette` (Charmtone by Christian Rocha)
- **Face shading**: Top brightened 1.3×, left dimmed 0.7×, right dimmed 0.45×
- **Color inheritance**: Newborns inherit dominant neighbor color with 8% mutation chance

## Configuration

Tunable constants in `Sources/GameOfLifeView.swift`:

| Constant          | Default | Effect                                 |
| ----------------- | ------- | -------------------------------------- |
| `targetTilesAcross` | 20    | Grid width in tiles (lower = bigger)   |
| `gameTickEvery`     | 120   | Frames between game steps (2s @ 60fps) |

## Screen Saver Notes

- **Principal class**: Must be `LivingGlass.LivingGlassView` (module-qualified)
- **Bundle loading**: Pass `Bundle(for: LivingGlassView.self)` to load `default.metallib`
- **Deferred setup**: Wait for valid bounds before creating Metal view

## Gotchas

1. **No Xcode project** — Don't look for `.xcodeproj`. Build via `./build.sh`
2. **Metal library location** — App: main bundle. Screen saver: `Bundle(for:)` required
3. **Shader struct alignment** — Swift structs must match Metal exactly (SIMD types)
4. **LSUIElement=true** — App has no dock icon, only menu bar (🧬)
5. **Desktop window level** — Uses `CGWindowLevelForKey(.desktopWindow)`, not `.desktop`
6. **Space-switch flash** — Wallpaper set to `caviar_bg.png` to match background color
7. **Low Power Mode** — Animation pauses automatically via `ProcessInfo.isLowPowerModeEnabled`

## Testing

No automated tests. Manual verification:

```bash
# Build and run app
./build.sh && open build/LivingGlass.app

# Install screen saver (opens System Settings)
open build/LivingGlass.saver

# Check for build errors
./build.sh 2>&1 | grep -i error
```

## CI/CD

Tagged releases (`v*`) trigger `.github/workflows/release.yml`:

1. Builds on `macos-14` runner
2. Creates ZIP archives for both `.app` and `.saver`
3. Publishes GitHub Release with auto-generated notes

```bash
# Create a release
git tag v1.0.0
git push origin v1.0.0
```

## Requirements

- macOS 14+ (Sonoma)
- Xcode Command Line Tools
- Metal-capable GPU
