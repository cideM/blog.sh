---
title: Dotfiles Management with GNU Stow
date: 2020-06-07
publish: true
---

**Update Jun 09:** I've since refined my dotfiles setup a bit more, after briefly playing around with just using a Makefile instead of stow. The link for "my dotfiles" below now links to a specific commit so that the post still makes since. But I'd recommend that people take a look at my current dotfiles repo. There's a `src` folder, where each folder represents one application's dotfiles. The only exception from this rule is Alacritty, since I build that with Dhall. These folders have a structure which let's you easily `stow` them, meaning most of them look like this: `app_name/.config/app_name/configrc`. Then there's a `hosts` folder, which is like the `machines` folder in the older commit. This contains code that is highly specific to a single host. This includes systemd files for Arch, or special fish files which are automatically sourced upon load, and placed in `fish/.config/fish/conf.d` (worth a look to see how I avoid cluttering my configs with if/else!). The POSIX shell scripts tie all of this together. They're pretty minimal, although I added some eye candy with tabs and some unicode symbols. Check out the platform specific setup scripts, like `scripts/arch.sh`

**Original Post**: Developers customize the tools they work with. For some, this just means adding their favorite Git shortcuts to `.gitconfig`, for others it means customizing their entire OS, down to the border color of the notification windows. Either way, you'll end up with a whole bunch of files where these customizations are stored. On UNIX systems, they're typically stored in [`XDG_CONFIG_HOME`](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html), which defaults to `~/.config`. And these files and directories [starting with a dot](https://en.wikipedia.org/wiki/Hidden_file_and_hidden_directory#Unix_and_Unix-like_environments) are called dotfiles, the management of which is the topic of this post.

I've been using [GNU Stow](https://www.gnu.org/software/stow/) to manage [my dotfiles](https://github.com/cideM/dotfiles/tree/4c528c8c1a11b312e3e3a4db257ba2a231e5cfd4) for quite a while now[^1] . `stow` is essentially a symlink manager. There are [plenty](https://writingco.de/blog/how-i-manage-my-dotfiles-using-gnu-stow/) [of](https://alexpearce.me/2016/02/managing-dotfiles-with-stow/) [articles](https://medium.com/@waterkip/managing-my-dotfiles-with-gnu-stow-262d2540a866) [about](https://bastian.rieck.me/blog/posts/2019/dotfiles_stow/) `stow` already, so I won't repeat the basics here. Instead I'll focus on how I structure my dotfiles and what worked well and what didn't.

## Machines and Users

I group my dotfiles based on which machine and user they belong to. Machine is a pretty flexible term here and doesn't just mean different physical hardware, but also different operating system (OS) and/or desktop environment (DE). For example I currently have 2 machines:

```fish
$ exa --tree -L 1 machines/
machines
├── arch_desktop
└── nixos_desktop
```

Both OSes happen to live on the same machine but other than that they don't share any basic OS configuration. Users is even less impressive, since there's only one user right now:

```fish
user
└── tifa
```

The idea for structuring my dotfiles like this comes from the [Nix Home Manager](https://github.com/rycee/home-manager), where quite a lot of people use a format like that ([example 1](https://github.com/Xe/nixos-configs) [example 2](https://git.sr.ht/~vdemeester/home/tree/master/users)). It follows my personal coding guideline of grouping things by domains and "where they belong" rather than "what they are". I never need to look at all my terminal emulators or GUI apps at the same time, but I often want to know which tools I have installed on NixOS for example.

The `user` folder stores configuration which is independent from the OS, such as my Neovim `init.vim`, or my `.gitconfig`. The `machine` folders then store stuff that is highly specific to an OS. For example, my window manager ([`bspwm`](https://github.com/baskerville/bspwm)) configuration for Arch, which doesn't make any sense on MacOS.

In the beginning I limited the dotfiles repository to files stored in `$HOME`, but I've since it expanded this to certain files in `/usr` and also `/etc`. The latter requires running `stow` with superuser privileges, which doesn't feel like the best solution, but it allows me to keep things like systemd hooks in my dotfiles repo as well.

**Update:** This kind of symlinking to `/etc` and `/usr` with `stow` does not work on Arch (it's fine on NixOS) and it's probably not a good idea in any case. `/usr` is meant to be handled by the administrator and symlinking it to a single user's home folder doesn't seem very idiomatic. I've changed it so that these files are just copied over and they're now stored under `src/`

```fish
$ exa -a --tree machines/arch_desktop/root/
machines/arch_desktop/root
├── etc
│  └── systemd
│     ├── network
│     │  └── 20-wired.network
│     └── system
│        ├── efistub-update.path
│        └── efistub-update.service
└── usr
   └── share
      └── xsessions
         └── bspwm.desktop
```

The most popular alternative dotfiles structure is to just create one folder per application. So you'd have, for example, `nvim/.config/nvim/init.vim`. Running `stow nvim` with your dotfiles folder located in `$HOME` would then default to stowing _the contents of `nvim/`_ (meaning `.config/nvim/init.vim`) in the _parent of the dotfiles_ folder, meaning `$HOME`. In other words, with one simple command your Neovim stuff would end up in the right place. Here's what such a repo might look like. 

```fish
$ exa -a --tree some_dotfiles_repo
some_dotfiles_repo
├── nvim
│  └── .config
│     └── nvim
│        └── init.vim
└── fish
   └── .config
      └── fish
         └── config.fish
```

The downside is that you'll have to figure out a way to assign apps to hosts/machines and users. Shell scripts and/or Makefiles can definitely achieve this, I just prefer to model these relationships through my dotfiles folder structure.

## Be Careful with Version Control

GNU stow is mostly straight forward, except when it comes to creating symlinked directories. Here's something which used to be a pretty regular occurrence for a while: I create a path in my dotfiles repo which doesn't exist on my host OS at all, like `nvim/.config/nvim/init.vim`. `stow nvim` will now not only create a symlink from `init.vim` to my dotfiles folder, it'll symlink the entire `nvim/` folder (so `~/.config/nvim/` points at `$DOTFILES/nvim/.config/nvim`).[^3] When I then run my Neovim package manager, it will download lots of stuff into the `nvim` folder, which is a symlink to my dotfiles repo. In other words, stuff gets added to my dotfiles repo which shouldn't be tracked. A careless `git add .` can therefore easily clutter your repo, or worse, expose secrets. I get around this issue by checking what I add to version control and using `.gitignore`. One feature that many people are probably not aware of is that you can use wildcards to ignore entire subfolders and then [selectively negate](https://git-scm.com/docs/gitignore#_pattern_format) that pattern to add individual files. Here's an excerpt from my `.gitignore` which I use to ignore fish plugins downloaded with [`fisher`](https://github.com/jorgebucaran/fisher).

```text
# Only allow specific files in git for fish
**/.config/fish/functions/*.fish
!**/.config/fish/functions/fish_greeting.fish
!**/.config/fish/functions/fish_prompt.fish
!**/.config/fish/functions/fisher.fish
```

## Avoid `if $OS then else`

This is another coding guideline of mine: try to avoid using if/else. I find it confusing if many files contain code that's only relevant to a specific environment. Instead I try to make it explicit what's shared and what's OS or environment specific. For example, there are some shell variables which I always export on every OS, such as my `fzf` settings in `config.fish`. And then there are some customizations, such as prepending GNU utils to `$PATH`, which are only used on MacOS. Currently I use if/else for this, but I'd rather specify one list of shared path segments, and then merge this (append or prepend) with host specific path segments. There are plenty of ways of doing this, but my preferred way is using [Dhall](dhall-lang.org/). At some point I'll go ahead and create some really tiny abstractions around common [Fish shell](fishshell.com/) constructs so that I can create an OS specific `config.fish`. My [Alacritty](https://github.com/alacritty/alacritty) configuration is [managed like that already](https://github.com/cideM/dotfiles/blob/master/src/alacritty/nixos.dhall). This is obviously a lot of overhead if you're not into Dhall already, but since Dhall happens to be my favorite way of handling all configuration needs, any file I can port to Dhall is a net win in my book. There's something extremely satisfying about being able to say `let darwinPaths = sharedPaths # [ "/foo", "/bar" ]`. You can of course just use bash scripts to concatenate some texts. Or use if/else. They're your dotfiles after all.

## Alternatives

There are plenty of [alternatives](https://wiki.archlinux.org/index.php/Dotfiles) to using GNU stow. The most specialized and comprehensive tool for dotfiles management is probably [`chezmoi`](https://github.com/twpayne/chezmoi), a tool written in Go, which unsurprisingly let's you use Go templating to inject variables. Since I dislike both Go[^2] and its text and HTML templating, it's an immediate no for me, but judging by the GitHub stars it must be doing a lot of things right.

So why GNU stow?

I think it strikes a nice balance between taking care of some of the tedium of managing configuration files, without doing too much for you. That's not to say that tools like `chezmoi` do too much! It's just that `stow` happens to give me the minimum amount of features I need. I "get" to manage secrets and variables and folder structure myself, which you may or may not like.

[^1]: I reset my dotfiles repo before writing this post, in case you're wondering about the rather short Git history
[^2]: I write Go professionally right now
[^3]: Check the manual for more info on how [tree folding](https://www.gnu.org/software/stow/manual/stow.html#Tree-folding) works in GNU stow
