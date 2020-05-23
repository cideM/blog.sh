---
title: Building a Blog with Nix
date: 2020-05-10
publish: false
---

After [checking out the Dhall configuration language](https://fbrs.io/exploring_the_dhall_configuration_language.html) and finding it extremely useful and straightforward to learn, I wanted to also look at [Nix](https://nixos.org/), a purely functional package manager. Until recently I was using Gatsby for my personal blog, but it's quite ridiculous to download tons of dependencies only to generate a few lines of HTML. So I figured that my blog would be a nice playground for Nix. The goal was to have a single command which would build my blog. Ideally this would happen automatically, in the cloud, on pushing to the repository, but manually running `netlify deploy` is also fine.

To summarize my experiences: If your programming language of choice is supported by the Nix community, it feels like the future. Seriously, it's so amazing that I'd encourage everyone to spend at least one weekend to check out Nix and get an impression of what kind of workflows are possible.
If there's not enough support though, be prepared to dive into the details of how dependency management and packaging work for your language and then create a lot of infrastructure all by yourself. In other words, don't expect to be productive any time soon.

## Nix the Amazing Parts

My blog is just a couple of markdown files converted to HTML, nothing fancy. I've written several versions of that blog in different languages, but this time I wanted to use Golang. Luckily, the Go infrastructure in Nix is [quite nice](https://www.reddit.com/r/NixOS/comments/b2eq5n/announcing_the_new_golang_infrastructure/)! If you are using Golang modules (which you should), then you get to enjoy the simplicity of just calling `buildGoModule` with a name, version, sha and source folder, and it will compile your program and return a link to the binary. That's what the code snippet below demonstrates. Only the `modSha256` is a bit whacky. On first run, you need to set this to a fake sha, which will trigger an error since `buildGoModule` will figure out the correct sha and then complain that they don't match (if there's a better way, let me know, yuuki@protonmail.com). At that point you can update the `modSha256` which will now be unique to all _inputs_ to your derivation. In other words, a derivation is uniquely identified by its inputs/dependencies, not its content. Note that changing your own Golang source files doesn't require computing a new `modSha256`, but changing the dependencies does (as it should).

```nix
{ pkgs ? (import ./nixpkgs.nix {}) }:

let
  blog-go = pkgs.buildGoModule rec {
    pname = "fbrs-blog-go";
    version = "latest";

    modSha256 = "14l74yjhwhzg1a3kkqjv95qgliqwmi3wqwcslrs435wlqnmlkgal";

    src = builtins.path {
      name = "go-src-blog";
      path = ./.;
    };
  };
in blog-go
```

The next step is then to use the compiled Golang program to generate my blog.

```nix
// blog-go ellided
  blog = pkgs.stdenv.mkDerivation {
    pname = "fbrs-blog";
    version = "latest";
    src = builtins.path { path = ./.; name = "src-blog"; };
    buildInputs = [ blog-go ];

    buildPhase = ''
      mkdir out
      blog -contentdir=./content/ -outdir=./out -templatedir=./go_templates
    '';

    installPhase = ''
      mkdir -p $out/public
      cp out/* $out/public/
      cp styles.css $out/public/
    '';
  };
```

This file is not complete, since I ellided the `blog-go` code from the first snippet. This time I'm using `mkDerivation` directly. Notice that its arguments are quite similar to `buildGoModule`: name, version and source, but this time I'm also specifying the dependencies of my blog, which is the aforementioned Golang program. With a few lines of bash I can then configure the _builder_ used to create this derivation. Here, I'm running the go program (`blog -contentdir...`) and then I just copy the files into the `public/` folder, including a static `.css` file which isn't processed in any way.

I can then build my blog -- or build the _derivation_ I get from calling `pkgs.stdenv.mkDerivation` -- with `nix-build blog.nix`:

```text
these derivations will be built:
  /nix/store/g5yakln1m5i4iglf8lafbgngcli77r2y-fbrs-blog-go-latest.drv
  /nix/store/f43i4bks0dlf79f3cvy2abhh77ncfnl3-fbrs-blog-latest.drv
...
go: downloading github.com/pkg/errors v0.9.1
go: downloading gopkg.in/yaml.v2 v2.2.8
go: downloading github.com/russross/blackfriday/v2 v2.0.1
go: downloading github.com/shurcooL/sanitized_anchor_name v1.0.0
github.com/pkg/errors
github.com/shurcooL/sanitized_anchor_name
github.com/russross/blackfriday/v2
...
/nix/store/yrmvs430l5xl75vnhl2jx0kzhvnd8478-fbrs-blog-latest
```

I've ellided some details, but as you can see it's downloading my Go dependencies and in the end it returns a string, which is the path of the build output (the _derivation_ that was built). It also adds a `result` folder in my source folder, which is a symlink to that derivation.

```text
 p/blog-nix $ readlink result
/nix/store/yrmvs430l5xl75vnhl2jx0kzhvnd8478-fbrs-blog-latest
 p/blog-nix $ tree result/
result/
└── public
    ├── building_a_blog_with_nix.html
    ├── exploring_the_dhall_configuration_language.html
    ├── index.html
    ├── react_hooks_are_tricky.html
    ├── styles.css
    ├── the_compose_newtype_and_its_applicative_instance.html
    └── understanding_unliftio.html

1 directory, 7 files
```

This is much faster and leaner than Docker and there was plenty of documentation and examples on how to use `buildGoModule` (there's also `buildGoPackage` for projects that don't use go modules).

But what about the development environment? This is where things get even more exciting.

There's an incredibly cool tool called [lorri](https://github.com/target/lorri), which integrates with [direnv](https://direnv.net/), to automate switching development environments. And when I say automate I really mean that, once set up correctly, it requires **no actions on your part whatsoever**. That's the "feels like the future" part of Nix. Just drop a few lines of nix code in a file called `shell.nix` and make sure that the `lorri` daemon is running (`$ lorri daemon`).

```nix
let
  pkgs = import <nixpkgs> {};
in
pkgs.mkShell {
  buildInputs = [
    pkgs.go pkgs.gotools
  ];
}
```

Additionally, there should be a `.envrc` file in the same folder, which is autogenerated by running `lorri init`.

```text
eval "$(lorri direnv)"
```

**Whenever I now `cd` into the project directory, `lorri` will do a bit of nix and symlink magic, so that all the tools I've specified in `shell.nix` are available on my \$PATH**.

```shell
 p/blog-nix $ which go
/nix/store/w5nhvkf5c8l5s6id8w655gyh74rida79-go-1.14.1/bin/go
```

Here I'm using `watchexec` for running certain commands whenever a file changes, `netlify` (from `npm`) is used to deploy my blog, and `miniserve` to serve the `.html` files locally. You don't need Rust nor `nodejs` to use these dependencies! Thanks to the Nix instructions, **everything will be downloaded and built automatically**.

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
    pkgs.go pkgs.gotools pkgs.nix-prefetch-git miniserve watchexec pkgs.nodePackages.node2nix netlify
  ];
}
```

At this point in my Nix journey I was ready to remove all programming languages, switch to NixOS, buy Nix merchandise and preach the Nix gospel to all my coworkers.

## Nix the Slightly Rough Edges

As you can imagine, something as radical and niche as Nix (and NixOS) isn't always smooth sailing. For Rust, Golang and Haskell, Nix support is really good. The experience wasn't as nice when it came to setting up netlify in my dev env though.

You might have noticed that `netlify` is imported from a file called `netlify.nix`. This is an autogenerated file, which in turn imports a `node-packages.nix` file. This file is way too big to paste though. It's essentially all dependencies required to build the `netlify-cli` tool. If you know anything about modern JS you'll know that the list of dependencies is of biblical proportions.

Now on the one hand there is a [`node2nix`](https://github.com/svanderburg/node2nix#deploying-a-nodejs-development-project) tool which automates this to some degree. On the other hand it requires some manual steps. I'm sort of sure that you could write a wrapper around `node2nix` which would work like `buildGoModule` but as it stands right now, such a tool doesn't exist.

There are also some [instructions](https://nixos.org/nixpkgs/manual/#node.js) on how to import packages from the NodeJS ecosystem into your projects with minimum effort, but this only applies to a tiny fraction of the available `npm` packages. None of this is bad, or a dealbreaker, but it's not as simple as `npm install`.

I also wanted to try writing Clojure with Nix. After all, since both are part of the functional programming landscape, I expected there to be a vibrant Clojure fraction among the Nix userbase. Unfortunately, that's not the case. There's a 1 1/2 years old [post on Discourse](https://discourse.nixos.org/t/maintained-usable-tooling-for-building-clojure-projects-in-nix/1556) asking about the state of Clojure. I asked the same question [again](https://discourse.nixos.org/t/nix-and-clojure/7104), hoping that I had somehow overlooked the extensive Clojure tooling in Nix, but it just doesn't exist. Sad panda. And this brings me to my biggest issue with Nix: the rest of the world.

Okay that doesn't make much sense so let me explain. Nix itself doesn't do any magic. In fact, once you've spent maybe 20 hours reading documentation and checking out the source code for [nixpkgs](https://github.com/NixOS/nixpkgs) a lot of the user facing functionality seems far less magical and intimidating. What Nix does is mostly downloading source files from various locations, including build tooling, which is then passed on to a builder. The builder is usually bash code which f. ex. uses your languages' build tooling to compile a program and store the output in the Nix store. This means that you can't throw out your NPMs and your Mavens, you still need them for at least some of the work involved.

And that brings me to my personal decision matrix for estimating how viable using Nix is for me:

| Language Knowledge | Nix Support | Viable |
| ------------------ | ----------- | ------ |
| Bad                | Good        | Yes    |
| Good               | Good        | Yes    |
| Good               | Bad         | Yes    |
| Bad                | Bad         | No     |

Experimenting with new languages with bad support in Nix is a bit frustrating. I don't know how Clojure code is built. I don't know Maven, I have no idea what a classpath is and I don't know anything about the JVM. I can try copy & pasting snippets around but I have zero confidence in any build output.

Contrast this with Docker, where you can usually follow the official instructions for that language, since you're installing the normal tooling, just in a container rather than on your host system. Of course using Docker containers for development is a story of its own and not something I do (especially not on MacOS).

## Conclusion

I wish functional programming had "won" over object oriented programming back in the day. Maybe we'd all be running various flavors of NixOS then. Unfortunately that's not the world we live in. Nix is an amazing concept that is definitely worth checking out. But relying on it for all your packaging and dev env needs will probably be frustrating.

At the end of the day it's worth asking what you've actually gained. I've been running Arch for a few years now and I never had any issues with it. It's just been rock solid. Part of that is because I'm not an Arch power user, I just enjoy getting bleeding edge programs from AUR but I don't tweak the OS internals in any meaningful way. If I need to use a specific NodeJS version I use `nvm` (that's Fish shell `nvm`) and for Haskell this is handled by `stack`. If a project at work requires `7z` then I'll just install it. Anything production facing lives in a Docker container anyway. In other words, Nix is just a nice to have thing for me. It doesn't solve any problem I have.
