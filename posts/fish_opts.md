---
title: How To Fish Subcommands
date: 2020-06-14 
publish: true
---

I'm currently working on a somewhat minimalistic Fish Shell implementation of [jrnl](https://github.com/jrnl-org/jrnl/), a popular CLI journal tool written in Python. [My Fish version](https://github.com/cideM/fish-journal/blob/master/functions/journal.fish) is still a work in progress but there's one insight I'd like to share: how to correctly implement subcommands in Fish so that CLI are options are passed through to subcommands.

My first attempt looked something like this. At the bottom of this snippet (which you can paste into a file and run!) I'm defining the "main" export, a function called `foo`. This function has a single subcommand, to which it passes its arguments. That function, called `__hello`, defines a single option, `-i` (or `--info`). Additionally, there's some shared functionality implemented in `__shared`. And to make matters a bit more complicated, `__shared` also accepts an option.

```fish
#!/usr/bin/env fish

function __shared
    set -l options (fish_opt -s t -l tag)
    argparse $options -- $argv

    echo $_flag_t
    echo $argv
end

function __hello
    set -l options (fish_opt -s i -l info)
    argparse $options -- $argv

    echo $_flag_i

    __shared $argv
end

function foo -a cmd
  switch $cmd
    case hello
      __hello $argv
  end
end
```

Running this with `source foo.fish; foo hello -t -i` results in an error:

```text
__hello: Unknown option “-t”
foo.fish (line 12):
    argparse $options -- $argv
    ^
in function '__hello' with arguments 'hello -t -i'
        called on line 22 of file foo.fish
in function 'foo' with arguments 'hello -t -i'
__shared: Unknown option “-i”
foo.fish (line 5):
    argparse $options -- $argv
    ^ in function '__shared' with arguments 'hello -t -i'
        called on line 16 of file foo.fish
in function '__hello' with arguments 'hello -t -i'
        called on line 22 of file foo.fish
in function 'foo' with arguments 'hello -t -i'
```

Line 12 refers to the `argparse` call in `__hello`. As the error message implies, the option `-t` is indeed unknown to the options I've specified in `__hello`. Luckily Fish added an `--ignore-unknown` option in [3.1b1](https://fishshell.com/release_notes.html), which solves this issue. Before that release you had to redirect stderr to `/dev/null` which wasn't ideal. By changing that one line to `argparse -i $options -- $argv` the script works again, hooray! Now let's see what happens if you pass positional parameters to `__shared`. Change the call to `__shared` to `__shared foo bar $argv` and run the script again:

```fish
$ source foo.fish; foo hello -t -i
-i
-t
foo
bar
hello
```

No errors, but the name of the subcommand shows up in the arguments list, which is not what I want. Luckily that's easy to fix. Simply use `set -e argv[1]` to remove the first element (the subcommand name) from the original argument list. Note that I'm not using a dollar sign here which is intentional:

```fish
case hello
  set -e argv[1]
  __hello $argv ```

Let's recap what happens to `$argv`, when the script is called with `foo param -t -i`, as the arguments flow through the different function calls. 

- `param -t -i`
- Remove first element `param` -> `-t -i`
- Any option that `argparse` can succesfully parse is removed, in this case `-i`, but we're adding `foo bar` -> `foo bar -t` 
- Parse `-t` option -> `foo bar`

The final `$argv` at the very end of `__shared` is therefore just `foo bar`, which is exactly what I need.

`argparse` and `fish_opt` are some of the coolest helpers that Fish makes available to you as a script author and evertime I write POSIX sh or Bash scripts I miss their utility. It's therefore absolutely worth it to check out the [documentation](https://fishshell.com/docs/current/cmds/argparse.html)!

Happy Fish Scripting!
