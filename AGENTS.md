# Barney Project Guide

Barney is a multi-GPU/multi-node ANARI rendering library. It provides ray tracing via OptiX, native CUDA, or Embree (CPU) backends, exposed through the Khronos ANARI standard.

## Workspace Model

This repository root contains workspace configuration files (Justfile, flake.nix, .envrc, AGENTS.md). The actual barney source lives in **jj workspaces** inside this root — each workspace is a full, independent checkout of the barney project. The default workspace is `main/`.

All paths in this document are relative to a workspace root (e.g., `main/`), unless noted otherwise.

## Version Control: Jujutsu

This project uses **Jujutsu (jj)** for version control instead of Git.

### Key Concepts

- Working copy is automatically tracked (no staging area)
- Changes are immutable once created — use `jj new` to start fresh work
- Use `jj describe` to set commit messages
- Use `jj log` to view history (more informative than git log)

### Workspace Workflow

Workspaces are created inside the repo root. Each workspace is an independent checkout at a different revision:

```bash
# List all workspaces
jj workspace list

# Create a new workspace for a specific feature/task
jj workspace add feature-name -r main

# Switch focus between workspaces (just cd)
cd ../feature-name
```

**Workspace naming convention**: Use short, descriptive names:
- `main` — default workspace tracking upstream
- `fix-volume-normals` — specific bug fix
- `mpi-support` — feature branch

Each workspace can be at a different revision, allowing parallel development of different features or bug fixes. Each has its own build directory.

### Common Jujutsu Commands

```bash
jj status          # Show working copy status
jj diff            # Show uncommitted changes
jj log             # View commit history (graphical)
jj new             # Create new change on top of current
jj edit @-         # Edit parent commit
jj squash          # Squash current change into parent
jj rebase -d main  # Rebase onto main
jj abandon         # Discard current change
jj duplicate       # Copy a change
```

### Working with Multiple Workspaces

```bash
# See what revision each workspace is at
jj workspace list

# Update another workspace to latest
cd ../other-workspace && jj rebase -d main

# Merge changes from another workspace
jj new feature-change main  # Create merge commit
```

### Feature Development Workflow

When working on a feature, follow this iterative workflow:

1. **Build after each change** — Validate every change by running `just build`
2. **Commit with terse messages** — Use `jj commit -m "message"` with a brief description
3. **Amend existing commits** — When iterating on a change, update the original commit instead of creating new ones:

```bash
# Make a change and commit it
just build                      # Validate the change builds
jj commit -m "Add foo support"  # Commit with terse message

# Later, need to fix something in that commit
jj edit <revision>              # Working copy IS that revision now
# Make fixes...
just build                      # Validate fixes build
jj new <tip-revision>           # Return to the tip of the branch
```

This keeps the commit history clean with each commit representing a complete, working change.

## Project Architecture

### Three Major Components

#### 1. rtcore (`rtcore/`) — Ray Tracing Backend Abstraction

Low-level ray tracing core with pluggable backends.

- **Language**: C++20 + CUDA
- **Key subdirectories**:
  - `common/` — Shared ray tracing types and interfaces
  - `optix/` — OptiX backend (default when CUDA available)
  - `cuda/` — Native CUDA backend (experimental)
  - `cudaCommon/` — Shared CUDA utilities for optix/cuda backends
  - `embree/` — Embree CPU backend (default when no CUDA)
- **Key interfaces**: `AppInterface.h`, `ComputeInterface.h`, `TraceInterface.h`
- **Backend selection**: Compile-time via `BARNEY_BACKEND_OPTIX`, `BARNEY_BACKEND_CUDA`, `BARNEY_BACKEND_EMBREE`

#### 2. barney (`barney/`) — Core Rendering Library

Main rendering engine built on top of rtcore.

- **Language**: C++20 + CUDA
- **Key subdirectories**:
  - `api/` — C API implementation
  - `common/` — Common utilities, `barney-common.h` (defines `BARNEY_NS` macro)
  - `geometry/` — Geometry types (Triangles, Spheres, Cylinders, etc.)
  - `volume/` — Volume rendering
  - `umesh/` — Unstructured mesh support
  - `amr/` — Adaptive Mesh Refinement
  - `material/` — Material implementations
  - `light/` — Light types
  - `kernels/` — CUDA rendering kernels
  - `render/` — Rendering core
  - `fb/` — Frame buffers (LocalFB, TiledFB, DistFB for MPI)
  - `globalTrace/` — Global ray tracing
  - `packedBSDF/` — BSDF implementations
  - `include/` — Public C API headers (`barney.h`, `barney_mpi.h`)
- **Libraries produced**: `barney` (shared), `barney_static`, `barney_mpi`, `barney_mpi_static`

#### 3. anari (`anari/`) — ANARI Device Wrapper

ANARI standard device implementation wrapping the barney library.

- **Namespace**: `barney_device`
- **Language**: C++17
- **Key subdirectories**:
  - `light/` — ANARI light type mappings
  - `test/` — Device tests
  - `generated/` — Auto-generated ANARI device queries
- **Base class**: Derives from `helium::BaseDevice` (ANARI-SDK Helium library)
- **Library produced**: `anari_library_barney`

### Supporting Directories

- `3rdParty/` — Bundled dependencies (GLM, NanoVDB)
- `submodules/` — Git submodules (OWL, cuBQL, Embree, optix-dev)
- `samples/` — Sample applications
- `unitTests/` — Unit tests
- `scripts/` — Build/utility scripts
- `doc/` — Documentation

### Domain Model / Ubiquitous Language

`CONTEXT-MAP.md` (workspace root) maps the bounded contexts and their glossaries:

- `anari/CONTEXT.md` — banari (ANARI device layer) vocabulary
- `barney/CONTEXT.md` — barney core vocabulary
- `rtcore/CONTEXT.md` — backend abstraction vocabulary
- `submodules/owl/CONTEXT.md` — OWL, treated as a standalone project
- `submodules/cuBQL/CONTEXT.md` — cuBQL, treated as a standalone project

Words like **Device**, **Group**, **World**, **Context**, and **Sampler** mean different things per context — check the map's "Shared-word traps" section before assuming.

## Build System

### Using Just (Preferred)

The Justfile lives in the **repo root** (not inside workspaces). It uses modular includes (`mod cmake`, `mod dotfiles`, `mod repo`) from `$JUST_HELPERS`, which the Nix dev shell sets to the store path of the `just-helpers` flake input (pinned in `flake.lock`). Run `just` from inside the dev shell (direnv); outside it `JUST_HELPERS` is unset and the Justfile fails to parse. The default source directory is `main/`.

```bash
# Setup and configure
just prepare             # Generate .clangd, VS Code, Emacs configs
just configure           # Configure CMake (OptiX auto-detected)
just configure_mpi       # Configure with MPI support
just configure_embree    # Configure CPU-only (Embree, no CUDA)

# Build
just build               # Build RelWithDebInfo (default)
just br                  # Build Release
just brd                 # Build RelWithDebInfo (explicit)
just bd                  # Build Debug
just rebuild             # Clean and rebuild

# Run (executables come from Nix shell PATH)
just run vsrViewer -v -e # Run any command with barney libs
just vsrViewer           # Shorthand for vsrViewer -v -e
just gdb vsrViewer -v -e # Debug with gdb
just shell               # Shell with barney libs on LD_LIBRARY_PATH

# Workspaces
just new_workspace NAME TRACKING  # Create workspace tracking a branch

# Cleanup
just clean               # Remove _out/ directory
```

### Build Output

- Build directory: `_out/_cmake/`
- Install directory: `_out/`
- Libraries: `_out/lib/`

### CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `BARNEY_MPI` | OFF | Enable MPI support |
| `BARNEY_BACKEND_OPTIX` | ON (if CUDA) | OptiX backend |
| `BARNEY_BACKEND_CUDA` | OFF | Native CUDA backend |
| `BARNEY_BACKEND_EMBREE` | OFF (if CUDA), ON (otherwise) | Embree CPU backend |
| `BARNEY_DISABLE_CUDA` | OFF | Force-disable CUDA detection |
| `BARNEY_DISABLE_DENOISING` | OFF | Disable all denoising |
| `BARNEY_DISABLE_OIDN` | OFF | Disable OIDN even if found |
| `BARNEY_HAVE_NANOVDB` | ON | NanoVDB volume support |
| `BARNEY_USE_EXTERNAL_CUBQL` | OFF | Use external cuBQL directory |
| `BARNEY_CUBQL_BVH_WIDTH` | 4 | cuBQL BVH tree width |

### CMake Patterns

#### Backend-dependent compilation via `BARNEY_NS`

The `BARNEY_NS` macro (defined in `barney/common/barney-common.h`) resolves to a backend-specific namespace (`barney_optix`, `barney_embree`, or `barney_cuda`) at compile time based on `BARNEY_RTC_OPTIX`, `BARNEY_RTC_EMBREE`, or `BARNEY_RTC_CUDA`. This allows the same source to be compiled once per backend into separate object files without symbol collisions.

#### Device programs (`.dev.cu`)

Files ending in `.dev.cu` are compiled to PTX via OWL's `embed_ptx()` and embedded as blobs into the library. Regular `.cu` files are compiled as host code by the CUDA compiler.

#### Symbol visibility

Hidden by default (`CXX_VISIBILITY_PRESET hidden`, `CUDA_VISIBILITY_PRESET hidden`). Public API exported via `BARNEY_INTERFACE` macro.

### Direct CMake (Alternative)

```bash
cmake -B _out/_cmake \
  -G "Ninja Multi-Config" \
  -DBARNEY_HAVE_NANOVDB=ON \
  -DCMAKE_INSTALL_PREFIX=_out
cmake --build _out/_cmake --config RelWithDebInfo
cmake --install _out/_cmake --config RelWithDebInfo
```

## Environment Setup

Uses Nix flakes (`flake.nix`) for dependency management. The flake lives in the **repo root**.

```bash
# Enter development shell (via direnv)
direnv allow

# Or manually
nix develop
```

Key environment variables:
- `ANARI_LIBRARY` — Default ANARI device (set to `barney` via `.envrc`)
- `vsr_ANARI_LIBRARIES` — Comma-separated ANARI devices for vsrViewer (e.g., `barney,visrtx,helide,ospray,visionaray`)
- `LD_LIBRARY_PATH` — Includes barney's install libs and comparison ANARI devices

The Nix shell provides:
- **barney** and **anari-barney** build dependencies (via `inputsFrom`)
- **vsr** package — provides `vsrViewer`, `vsrRender`, and other vsr tools
- Comparison ANARI devices: visrtx, helide, ospray, visionaray, visgl

Barney is a library — it has no executables of its own. Viewers and tools come from the `vsr` Nix package (PATH).

## Coding Guidelines

### Philosophy

Code should be self-documenting through clear naming and logical structure. Prefer free utility functions over deep class hierarchies. Keep inheritance shallow. Use `using namespace owl::common;` for math types.

### Comments

Keep comments to a minimum — only explain *why*, not *what*. Never restate what the code already says. Use `//`-style line comments.

### Naming

- `PascalCase` for classes, structs, and type names
- `camelCase` for functions, methods, and local variables
- `m_` prefix for class member variables
- `UPPER_CASE` for enum values and constants
- CMake variables: `UPPER_CASE` with `BARNEY_` prefix

### Formatting

`.clang-format` lives in `anari/` only. Key rules: 2-space indentation, 80-column limit, custom brace wrapping (Allman for functions/classes/structs, attached for control statements), right-aligned pointers.

Headers use `#pragma once` and the **`.h`** extension. Implementation files use `.cpp`. CUDA files use `.cu`, device programs use `.dev.cu`. Every file starts with a 2-line SPDX Apache-2.0 copyright header:

```cpp
// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
// SPDX-License-Identifier: Apache-2.0
```

### Language Standards

- **barney** and **rtcore**: C++20
- **anari**: C++17 (for Helium compatibility)

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| `Justfile` | Repo root | Build recipes |
| `flake.nix` | Repo root | Nix dependencies |
| `.envrc` | Repo root | direnv configuration |
| `CMakeLists.txt` | Workspace root | Root build configuration |
| `barney/common/barney-common.h` | Workspace | `BARNEY_NS` macro, common types |
| `barney/include/barney.h` | Workspace | Public C API |
| `rtcore/AppInterface.h` | Workspace | Backend abstraction interface |
| `anari/.clang-format` | Workspace | Code formatting rules |
| `.gitmodules` | Workspace | Submodule definitions |

## Dependencies

- **OWL** — OptiX Wrapper Library (submodule: `submodules/owl`)
- **cuBQL** — CUDA BVH/spatial indexing (submodule: `submodules/cuBQL`)
- **Embree** — CPU ray tracing (submodule: `submodules/embree`)
- **optix-dev** — OptiX headers (submodule: `submodules/optix`)
- **CUDA 12+** — GPU compute (optional, auto-detected)
- **ANARI-SDK 0.15.0+** — Khronos rendering standard
- **Helium** — ANARI helper library (from ANARI-SDK)
- **GLM** — Linear algebra (bundled in `3rdParty/glm/`)
- **NanoVDB** — Sparse volume data (bundled in `3rdParty/nanovdb/`)
- **OpenImageDenoise (OIDN)** — Denoising (optional, auto-detected)
- **MPI** — Distributed rendering (optional, via `BARNEY_MPI`)

## External References

### Barney & Dependencies

| Resource | URL |
|----------|-----|
| Barney Repository | https://github.com/ingowald/barney |
| OWL (OptiX Wrapper Library) | https://github.com/NVIDIA/owl |
| cuBQL | https://github.com/NVIDIA/cuBQL |
| Embree | https://github.com/embree/embree |
| OpenImageDenoise | https://github.com/RenderKit/oidn |

### ANARI Standard

| Resource | URL |
|----------|-----|
| ANARI 1.2 Specification | https://registry.khronos.org/ANARI/specs/1.2-draft/ANARI-1.2.html |
| ANARI Registry | https://registry.khronos.org/ANARI/ |
| ANARI-SDK (GitHub) | https://github.com/KhronosGroup/ANARI-SDK |
| Khronos ANARI Overview | https://www.khronos.org/anari/ |

### NVIDIA Technologies

| Resource | URL |
|----------|-----|
| OptiX 9.1 Programming Guide | https://raytracing-docs.nvidia.com/optix9/guide/index.html |
| CUDA Programming Guide | https://docs.nvidia.com/cuda/cuda-programming-guide/index.html |

### Supporting Libraries

| Resource | URL |
|----------|-----|
| GLM (OpenGL Mathematics) | https://github.com/g-truc/glm |
| NanoVDB | https://academysoftwarefoundation.github.io/openvdb/NanoVDB_MainPage.html |
