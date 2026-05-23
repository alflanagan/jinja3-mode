# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Project Overview

This is a fork of [jinja2-mode](https://github.com/paradoxxxzero/jinja2-mode),
a single-file Emacs major mode for editing Jinja2 templates. The entire
implementation lives in `jinja2-mode.el`. Goals for this fork: update for
Emacs 32 compatibility and add a test suite.

The mode derives from `html-mode` (which derives from `sgml-mode`) and
overlays Jinja2 tag/filter/keyword highlighting and indentation on top of
SGML's HTML support.

## Development Commands

Load the mode interactively for manual testing:

```
emacs -Q -L . -l jinja2-mode.el some-template.j2
```

Byte-compile to check for warnings:

```
emacs -Q -batch -L . -f batch-byte-compile jinja2-mode.el
```

The `.gitignore` excludes `*.elc`, so compiled files are never committed.

## Architecture

Everything is in `jinja2-mode.el`. Key design points:

**Keyword lists** — `jinja2-closing-keywords`, `jinja2-indenting-keywords`,
`jinja2-builtin-keywords`, `jinja2-functions-keywords` are plain functions
returning lists. `jinja2-user-keywords` and `jinja2-user-functions` are
`defcustom` lists that get prepended, giving users an extension point
without patching the mode.

**Font-lock** — Three keyword sets (`jinja2-font-lock-keywords-{1,2,3}`)
built by appending to `sgml-font-lock-keywords-{1,2}`. Level 3 is where
all Jinja2-specific faces live (variables, filters, delimiters, keywords,
builtins). The active level is selected via `font-lock-defaults` in the
mode definition. `rx` / `rx-to-string` macros build all regexps; the
keyword-list functions are called at load time when the constants are
defined, so adding runtime-dynamic keywords requires care.

**Indentation** — `jinja2-indent-line` calls `jinja2-calculate-indent`,
which dispatches on whether the current line starts a close/else/elif
tag (dedent) or an SGML close tag (delegate to `sgml-calculate-indent`)
or anything else (call `jinja2-calculate-indent-backward` to walk
backwards). `sgml-basic-offset` is the indent width throughout. The
optional `jinja2-enable-indent-on-save` variable wires `jinja2-indent-buffer`
into `after-save-hook` per-buffer.

**Tag closing** — `jinja2-find-open-tag` does a recursive backward search
to find the nearest unclosed block tag. `jinja2-close-tag` uses this to
insert the matching `{% end... %}` form; `block` tags get their name echoed
(`{% endblock myblock %}`), others do not.

**Mode definition** — `define-derived-mode jinja2-mode html-mode` sets
comment syntax, font-lock defaults, and `indent-line-function`. Auto-mode
entries for `.jinja2` and `.j2` are registered with `;;;###autoload`.

## Emacs 32 Compatibility Notes

`font-lock-syntactic-keywords` was deprecated and removed in recent Emacs
versions. The `font-lock-defaults` form in `jinja2-mode` still passes it
via the alist slot — this will need updating. Check whether `sgml-mode`'s
own `font-lock-syntactic-keywords` reference still exists in Emacs 32 and
adapt accordingly.

## Testing

Tests use [buttercup](https://github.com/jorgenschaefer/emacs-buttercup)
and live in `test/jinja2-mode-test.el`. Buttercup is declared as a
development dependency in the `Cask` file, so [Cask](https://cask.readthedocs.io/)
provides the sandboxed environment.

Install the test dependencies once:

```
cask install
```

Run the suite:

```
cask exec buttercup -L .
```

`cask exec buttercup -L .` discovers the `test/` directory automatically
and runs every spec in it. Cask installs packages under `.cask/`, which
the `.gitignore` excludes.

The suite covers the keyword-list functions, font-lock highlighting,
indentation, tag closing/insertion, and mode setup. Buttercup specs use
`describe`/`it`/`expect`; helper macros at the top of the test file
(`jinja2-test--in-buffer`, `jinja2-test--reindent`, `jinja2-test--face-of`)
set up `jinja2-mode` buffers for the assertions.
