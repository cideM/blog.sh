# fbrs.io

`default.nix` builds the static assets for the blog and puts them in the Nix store. A symlink to the result is created locally, as `result`. Using Nix assures that GNU coreutils are used, regardless of platform. Otherwise certain commands, like `date`, will behave differently on Darwin (MacOS). Since Node is available in the Nix shell, `npx` can be used to e.g., deploy the site via the Netlify CLI tools (`npx netlify-cli deploy -d (readlink result)`).

## Quick Start

```sh
$ nix-shell
$ nix-build
$ npx netlify-cli deploy -d (readlink result)
```

Netlify is now part of the Nix shell so you can just 

```sh
$ nix-shell
$ netlify
```

Or with Lorri

```sh
$ netlify
```

:)
