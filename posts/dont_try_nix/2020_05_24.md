---
title: Dear Future Me, Don't Try Nix Yet Again
date: 2020-05-10
publish: true
---

_**Update 2020-06-07**: Dear past self, I appreciate you looking out for me. But against your advice, I tried Nix and NixOS a second time. This time I'm not using Home Manager to manage things like my shell or my terminal on Arch. Instead, on any OS that's not NixOS I'm only using Nix to package projects. On NixOS proper I can take advantage of all its capabilities, and let it manage almost everything. To keep things simple for now I still manage things like Neovim plugins through `minpac`. There's just no point in rewriting my Neovim configuration so it uses Nix on NixOS but `minpac` on Arch and MacOS. It's a lot of work for little gain. I can revisit this once I have more time._

_Long story short, I'm using Nix in moderation and so far it has worked really, really well. It's too good a tool to not use it._

_Current Self_

[Nix](https://nixos.org/) is an amazing idea. When it works, it really feels like the future of packaging and OS design. But quite often, it does not work. Next time you want to install and try Nix, remember what happened last time:

* Using Alacritty through Home Manager resulted in cryptic [glX errors](https://github.com/NixOS/nixpkgs/issues/80702). There's a [long and informative Discourse post](https://discourse.nixos.org/t/libgl-undefined-symbol-glxgl-core-functions/512/6) about the whole thing. It's probably a result of mixing Arch and Nix and would go away if I just used NixOS directly, but I really like using Arch.
* There are more bugs when mixing Arch and Nix. `fontconfig` is a [constant source of pain](https://discourse.nixos.org/t/fonts-in-nix-installed-packages-on-a-non-nixos-system/5871), especially since some upgrade to `fontconfig` 2.13 results in a `etc/fonts/fonts.conf` that's backwards incompatible. Again, it comes down to the discrepancy between system files and what Nix installed packages expect.
* Some weird problem about `setlocale` which can be fixed by [setting `LOCALE_ARCHIVE`](https://github.com/nix-community/NUR/issues/48)

I'm sure there will be other issues both now, with our apps, and in the future. Switching to NixOS completely would probably fix many of these problems, but you like Arch. Listen to your past self and repeat after me: you like Arch, it's rock solid, there's no reason to constantly try new distros.

Even assuming that Nix and Home Manager work flawlessy, what problem is this solving? It's trivial to reinstall a set of Arch and AUR packages from a file. Same on your work laptop with Homebrew. Sure, you're not getting the same packages today as when I wrote this post (for you, thank me later), but for the most part that doesn't matter. In the rare cases where you need a specific version of something you can:

* Install that specific release manually
* Write a little Fish script (like your [yarn version manager](https://github.com/cideM/fish-yvm)) to automate this

Yes, I know, it's amazing that you can mix libraries and binaries from different ecosystems. Below is the `shell.nix` file you created for the Golang/Nix version of your blog. It installs two rust crates using the nightly toolchain, a node package, and sets up some other toolchains and programs, all declaratively.

```nix
let
  pkgs = import ./nixpkgs.nix {};

  mozillaOverlay = pkgs.fetchFromGitHub {
    owner = "mozilla";
    repo = "nixpkgs-mozilla";
    rev = "e912ed483e980dfb4666ae0ed17845c4220e5e7c";
    sha256 = "08fvzb8w80bkkabc1iyhzd15f4sm7ra10jn32kfch5klgl0gj3j3";
  };
  mozilla = pkgs.callPackage "${mozillaOverlay.out}/package-set.nix" {};
  rustNightly = (mozilla.rustChannelOf { channel = "nightly"; }).rust;
  rustPlatform = pkgs.makeRustPlatform { cargo = rustNightly; rustc = rustNightly; };

  miniserve = rustPlatform.buildRustPackage rec {
    pname = "miniserve";
    version = "0.6.0";

    src = pkgs.fetchFromGitHub {
      owner = "svenstaro";
      repo = pname;
      rev = "ced8583dad006ac1b6bbf3136546877a825542ed";
      sha256 = "106qg5cmcirgbacihx8g34gzd2hi1mb0m72y4d0k4h2d3kj5nr5k";
    };

    buildInputs = [ pkgs.openssl pkgs.pkgconfig ];

    cargoSha256 = "07mmqklqpvwrgsv5bh4b8bwhy522x2dq7d71ljvqvxs7r7ji2lpn";
  };

  netlify = (import ./netlify.nix { pkgs = pkgs; }).netlify-cli;

  watchexec = rustPlatform.buildRustPackage rec {
    pname = "watchexec";
    version = "1.12.0";

    src = pkgs.fetchFromGitHub {
      owner = "watchexec";
      repo = pname;
      rev = "f8f6c0ac5ab184e9153e8118635de758cbdae704";
      sha256 = "010rdkd7qz1i62iinqivzf4jz4dypwymjklpxlgl378nyvr3q2m8";
    };

    buildInputs = [ pkgs.openssl pkgs.pkgconfig ];

    cargoSha256 = "07whi9w51ddh8s7v06c3k6n5q9gfx74rdkhgfysi180y2rgnbanj";
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.go 
    pkgs.gotools 
    pkgs.nix-prefetch-git 
    miniserve 
    watchexec 
    pkgs.nodePackages.node2nix 
    netlify
  ];
}
```

But you know what? In many cases, you won't need to mix packages from different ecosystems. And if the project has exactly one user (you, or us), you could just as well install this globally. Or use Docker. Or try to simplify things so that you don't need to install anything. Deep down we're both fans of [things like the Pure Bash Bible](https://github.com/dylanaraps/pure-bash-bible). You try to make yourself like all of this functional programming stuff, and Haskell, but when you're really honest, you value simple and fast over correct. You don't like too much abstraction and overhead.

Also, do you remember how hard it was to piece together the various ways of building packages in different languages? Do you remember that you actually need to know quite a few things about each respective toolchain? Remember how you couldn't build the OCaml language server because you don't know anything about OCaml? Yes, it's going to be like that for every language. For example, there are several different ways of handling Haskell with Nix. Are you going to evaluate them all and then decide which one is right for you, before having written a single line of code?

And did you forget about all the little things required to make Nix and Home Manager work with Fish? The `fenv`, the function to source paths and completions, the `sessionVariables` file? What about MacOS? You only use it for work, but the whole [Catalina](https://github.com/NixOS/nix/issues/2925#issuecomment-604501661) thing isn't sorted out yet.

Look, at some point a post will appear on Hackernews talking about the virtues of Nix or something like it. And maybe some day you'll have enough time to throw yourself into a project like that. Or it'll be mature enough for it to Just Work. But until then, there are dozens of other things you _want to focus on_. Yes, you want to learn another language really well. Something you enjoy writing, rather than having to force yourself to write code in it (cough Haskell). Maybe that's Rust, or Nim, or Bash, or Fish, or C. The point is to focus on one or a handful of things. Become a UNIX expert, comfortable with distros like Arch and Nix, write minimal CLI tools, remove things from your setup rather than adding things. Learn Lua, write Neovim plugins.

You've gone down this road multiple times. Read a post, get excited, declare $LANGUAGE or $TOOL your new religion. Throw out your existing setup, waste a weekend scratching the surface of $NEW_THING, then abandon it once you realize that it actually takes months of consistent effort and that it would require you to abandon your current projects and endeavours. Do you want to keep doing this? If you were a teenager that'd be A OK. But you're not. You're not even in your 20s anymore. You can't afford constantly getting distracted.

So please, take this from your younger self (ha ha, sorry...). Nix is an amazing idea. It has a great community. I hope it has a great future. But it's not your project right now.
