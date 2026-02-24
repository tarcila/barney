mod cmake '~/_just/cmake'
mod dotfiles '~/_just/dotfiles'
mod repo '~/_just/repo'

import '~/_just/dirs/mod.just'

cfg := env("cfg", "RelWithDebInfo")
_source_dir := _ROOT_DIR
_root_dir := _ROOT_DIR
_build_dir := _root_dir / "_out/_cmake"
_install_dir := _root_dir / "_out"
_envrc_dir := _root_dir
_clangd_dir := _source_dir
_compile_commands_dir := _build_dir
_vscode_dir := _root_dir / ".vscode"
_emacs_desktop_dir := _root_dir / ".emacs.d"
_emacs_dape_dir := _root_dir

_compiler := if os() == "macos" { "clang++" } else { "g++" }

_default: build

# Some important aliases

[doc("Build the project (Release)")]
[metadata("task", "pm=$gcc")]
br: (build "Release")

[doc("Build the project (RelWithDebInfo)")]
[metadata("task", "pm=$gcc")]
brd: (build "RelWithDebInfo")

[doc("Build the project (Debug)")]
[metadata("task", "pm=$gcc")]
bd: (build "Debug")

# Repo recipes

alias new_workspace := repo::new_workspace
alias forget_workspace := repo::forget_workspace
alias submodule := repo::submodule

[doc("Create a new workspace and initialize submodules")]
[no-cd]
add_workspace where tracking: (repo::new_workspace where tracking)
    cd {{ where }} && just submodule

# Build recipes

[doc("Generate configure files")]
prepare: generate_envrc generate_clangd generate_vscode_tasks_json generate_vscode_launch_json generate_emacs_desktop generate_emacs_dape

[private]
_cmake_options := replace_regex('
    -DBARNEY_BACKEND_OPTIX=ON
', '\s*\n\s*', ' ')

[doc("Configure OptiX-only")]
configure_optix: (cmake::force_configure _source_dir _build_dir _install_dir _cmake_options)

[doc("Configure with MPI")]
configure_mpi: (cmake::force_configure _source_dir _build_dir _install_dir _cmake_options "-DBARNEY_MPI=ON")

[doc("Configure CPU-only (Embree")]
configure_all_backends: (cmake::force_configure _source_dir _build_dir _install_dir _cmake_options "-DBARNEY_BACKEND_CUDA=ON -DBARNEY_BACKEND_CPU=ON")

alias configure := configure_optix

[doc("Reconfigure")]
reconfigure: (cmake::configure _source_dir _build_dir _install_dir _cmake_options)

[doc("Build")]
[metadata("task", "pm=$gcc")]
build cfg=cfg: reconfigure (cmake::install cfg _build_dir)
    rm {{ _install_dir }}/lib/libanari_library_barney.so

[doc("Rebuild")]
[metadata("task", "pm=$gcc")]
rebuild cfg=cfg: clean (build cfg)

# Run recipes

[doc("Run a command with barney libs on LD_LIBRARY_PATH")]
[metadata("launch", "debug")]
[script('bash', '-eu', '-o', 'pipefail')]
run CMD *ARGS:
    cd "{{ _root_dir }}" && \
    LD_LIBRARY_PATH="{{ _install_dir }}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    {{ CMD }} {{ ARGS }}

[doc("Debug a command with gdb")]
[metadata("launch", "debug")]
[script('bash', '-eu', '-o', 'pipefail')]
gdb CMD *ARGS:
    cd "{{ _root_dir }}" && \
    LD_LIBRARY_PATH="{{ _install_dir }}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    gdb --args {{ CMD }} {{ ARGS }}

[doc("Run tsdViewer")]
[metadata("launch", "debug")]
tsdViewer *ARGS: (run "tsdViewer" "-v" "-e" ARGS)

[doc("Open a shell with workspace environment")]
shell:
    cd "{{ _root_dir }}" && \
    LD_LIBRARY_PATH="{{ _install_dir }}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
    $SHELL

# Auxiliary recipes

[doc("Generate .envrc file")]
generate_envrc: (dotfiles::generate_envrc _envrc_dir _install_dir)

[doc("Generate .clangd config file")]
generate_clangd: (dotfiles::generate_clangd _clangd_dir _compile_commands_dir _compiler)

[doc("Generate .vscode/tasks.json")]
generate_vscode_tasks_json: (dotfiles::generate_vscode_tasks_json _vscode_dir)

[doc("Generate .vscode/launch.json")]
generate_vscode_launch_json: (dotfiles::generate_vscode_launch_json _vscode_dir)

[doc("Generate .emacs.desktop file")]
generate_emacs_desktop: (dotfiles::generate_emacs_desktop _emacs_desktop_dir)

[doc("Generate .emacs.desktop file")]
generate_emacs_dape: (dotfiles::generate_emacs_dape _emacs_dape_dir)

[doc("Remove the installation dir")]
clean:
    rm -fr "{{ _install_dir }}"
