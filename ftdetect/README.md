Filetype detections was originally intended to be contributed upstream. However,
as it turns out, and as others have learned before, Neovim does not manage
filetype detection directly. Instead, such contributions must be made to Vim
itself, which remains the canonical source for filetype definitions. Neovim then
periodically imports them wholesale from Vim, as part of a broader
synchronization strategy.

While this indirection is well-meaning in theory (centralizing logic, reducing
divergence), in practice it creates a high-friction contribution path. What
could be a simple, scoped improvement quickly balloon into a multi-step process
involving two separate projects, each with its own review standards and
contributor expectations.

I'm not opposed in principle to contributing upstream, indeed, I prefer to
when the cost is reasonable and the path clear, but in this case, the practical
cost of doing things "the right way" far exceeds the scope of the underlying
change. This is not a criticism of either project per se, but rather an honest
accounting of the time and context-switching required to navigate their
respective ecosystems.

For that reason, I take a more pragmatic approach here. Instead of pursuing
upstream integration, I simply handle detection of the relevant extensions
locally via `ftdetect/`. This sidesteps the need to coordinate across two
loosely-coupled repositories just to recognize a few additional file extensions.

Should upstream situation improve, or should broader consensus emerge around
consolidating filetype detection in a more contributor-friendly way, I'll
happily revisit, but until then, local detection is the simpler and frankly more
sustainable option.
