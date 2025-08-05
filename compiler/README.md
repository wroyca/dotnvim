https://github.com/neovim/neovim/issues/1496

Historically, invoking `:make` (or any bang command such as `:!make`) would
launch the process with stdout and stderr connected directly to Neovim's TTY.
This allowed full ANSI support and programs behaving as if run from a regular
shell.

Starting with recent Neovim versions, this is no longer the case. Bang commands
now execute through a pipe interface rather than inheriting the terminal's TTY.
This design was introduced to unify behavior across UIs (including GUI
frontends and remote clients), but it comes at a cost: broken ANSI escapes and
suppressed interactive behavior.

The direct consequence is that compiler output may now appear unstyled or
garbled, and tools that rely on TTY detection (such as compilers for color
diagnostics) will no longer behave correctly when invoked via `:make`.

Suggested workarounds from upstream involve running commands through Neovim's
terminal emulator, but this breaks established workflows, especially those that
rely on errorformat-based clickable errors in the quickfix list.

Regardless, we set up buffer-local compiler(s) directly to populate the
quickfix list. For full terminal output fidelity, each should be run manually
inside an actual terminal split instead.
