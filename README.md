# fbrs.io

`default.nix` builds the static assets for the blog and puts them in the Nix store. A symlink to the result is created locally, as `result`. Using Nix assures that GNU coreutils are used, regardless of platform. Otherwise certain commands, like `date`, will behave differently on Darwin (MacOS). Since Node is available in the Nix shell, `npx` can be used to e.g., deploy the site via the Netlify CLI tools.

## Quick Start

```sh
$ nix-shell
$ nix-build
$ npx netlify deploy (readlink result)
```
