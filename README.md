# fbrs.io

`default.nix` builds the static assets for the blog and puts them in the Nix store. A symlink to the result is created locally, as `result`. Using Nix assures that GNU coreutils are used, regardless of platform. Otherwise certain commands, like `date`, will behave differently on Darwin (MacOS).

`shell.nix` is used to deploy the site. Make sure to first store your deploy token in `.envrc`. With `lorri` and `direnv` things should then work automatically.

## Quick Start

```sh
$ nix-shell
these derivations will be built:
  /nix/store/d7c21i28v2s6ijfikldyp0aqrzr2jdxc-fbrs-blog-latest.drv
  building '/nix/store/d7c21i28v2s6ijfikldyp0aqrzr2jdxc-fbrs-blog-latest.drv'...
  unpacking sources
  unpacking source archive /nix/store/djy79yb5s5c7346f7nggdqvby4b3046p-blog_simple
  source root is blog_simple
  patching sources
  configuring
  no configure script, doing nothing
  building
  Building...
  Done
  installing
  post-installation fixup
  shrinking RPATHs of ELF executables and libraries in /nix/store/gjm461c47ip3pmdf63wdr7qbdzzzy8kf-fbrs-blog-latest
  strip is /nix/store/h4v5qdxlmnh7xfpl7pwzrs8js7220bz2-binutils-2.31.1/bin/strip
  patching script interpreter paths in /nix/store/gjm461c47ip3pmdf63wdr7qbdzzzy8kf-fbrs-blog-latest
  checking for references to /build/ in /nix/store/gjm461c47ip3pmdf63wdr7qbdzzzy8kf-fbrs-blog-latest...
$ ./deploy $blog/*
  adding: applicative_compose.html (deflated 80%)
  adding: fish_opts.html (deflated 60%)
  adding: hooks.html (deflated 75%)
  adding: index.html (deflated 59%)
  adding: styles.css (deflated 57%)
  adding: trying_dhall.html (deflated 68%)
  adding: unliftio.html (deflated 76%)
  ...
```
