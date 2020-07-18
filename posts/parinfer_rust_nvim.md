---
title: Installing parinfer-rust for Neovim on NixOS
date: 2020-07-18
publish: true
---

There's a very nice Rust library, [`parinfer-rust`](https://github.com/eraserhd/parinfer-rust), which implements the pretty well known Parinfer editing mode for Lisp languages, but in Rust. The library also comes with a (Neo)Vim plugin, which I wanted to install with `buildVimPluginFrom2Nix`.

At first I tried installing the plugin like any other:

```nix
  (pkgs.vimUtils.buildVimPluginFrom2Nix rec {
    pname = "parinfer";
    version = "latest";
    src = sources.parinfer;
  })
```

`sources` comes from [`niv`](https://github.com/nmattia/niv) and points at the GitHub repository of the Rust library. This will install the plugin just fine, but it will crash upon opening a Clojure file. The problem is that the Neovim plugin can't find the shared `.so` file.

```text
dlerror = "/nix/store/jp6y6fma2lvdr73q37jji7yp53hyqi42-vimplugin-parinfer-latest/share/vim-plugins/parinfer-latest/target/release/libparinfer_rust.so: cannot open shared object file: No such file or directory"
```

The installation instructions in the README do mention running `cargo build` as some sort of post installation hook. But since this is NixOS I definitely **do not** want to run an imperative command everytime I install this plugin. After all, `parinfer-rust` itself is already in Nixpkgs and therefore has a working derivation. I should be able to make the Neovim plugin aware of the build output of that derivation so that they share the `.so` file.

Luckily the [derivation for `parinfer-rust`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/parinfer-rust/default.nix) contains about 90% of an answer already. In its post install hook it replaces some strings inside the Neovim plugin. And it uses [placeholder](https://nixos.org/nix/manual/#ssec-builtins) for that, which I had never heard of (I'm not a Nix expert, in case you didn't notice). But even without looking at the documentation, it's somewhat intuitive that this is doing exactly what I needed to do as well: rewrite a path inside the vimscript plugin code so it points at the Nix store. Specifically, at the `parinfer-rust` build output.

Armed with this knowledge it was pretty easy to port this hook to my Neovim configuration. I'm doing exactly the same thing except I don't need the `placeholder` anymore. I can just refer to the stringified derivation (~ output path in Nix store) directly. This also has the advantage that the version of the plugin and of the shared library should be the same. Both come from the same `pkgs` package set after all.

```nix
  (pkgs.vimUtils.buildVimPluginFrom2Nix rec {
    pname = "parinfer";
    version = "latest";
    postInstall = ''
      rtpPath=$out/share/vim-plugins/${pname}-${version}
      mkdir -p $rtpPath/plugin
      sed "s,let s:libdir = .*,let s:libdir = '${pkgs.parinfer-rust}/lib'," \
        plugin/parinfer.vim >$rtpPath/plugin/parinfer.vim
    '';
    src = sources.parinfer;
  })
```

This might sound a bit ridiculous to someone more experienced in all things Nix, but this made me feel super accomplished for some reason 🚀

