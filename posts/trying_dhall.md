---
title: Exploring the Dhall configuration language
date: 2020-04-28
publish: true
---

Over the last weekend I looked into the [Dhall configuration language](https://dhall-lang.org/). I'm a fan of pure, functional programming in general and the works of [Gabriel Gonzalez](http://www.haskellforall.com/) specifically and so Dhall seemed like something I would like. I'm also not super happy with the way we handle kubernetes configuration files at work through helm, so I'm always looking for alternatives to that.

In this post I'll write down my first impressions of the language, which I got from creating [type definitions and default values](https://github.com/cideM/dhall-alacritty) for the [alacritty terminal emulator](https://github.com/alacritty/alacritty). In other words: I don't have a lot of experience with Dhall yet and haven't used it in a professional context. I'm not going to go through all the language features here, since the website does that much better. Instead, I'll go over some things which stood out to me while exploring Dhall. After that I'll show you an example of how Dhall can make working with configs safer **and simpler for the end user** before I get to the closing thoughts. Please also not that this is not an exhaustive introduction to the language. I'll do my best to add context to all of the code snippets, but not all of them are beginner friendly if you've never worked with a pure, functional language before.

_All code snippets in this post use unicode symbols, so `forall ()` becomes `∀ ()`. This is **not required** and purely for aesthetical reasons. Additionally, unless noted otherwise, all examples -- both inline and code blocks -- are runnable and don't require any additional imports._

## Documentation & Getting Started

The first contact with a new language is usually the landing page and the languages' documentation. In the case of Dhall both are excellent![^1] For a project so young it's impressive how much documentation exists and how **beginner friendly** it is in general. Especially considering that Dhall has a fair share of overlap with the Haskell community, which is not exactly known for soft documentation. The best resource to get started with Dhall is, in my opinion, the [language tour](https://docs.dhall-lang.org/tutorials/Language-Tour.html), followed by the other tutorials on the page. Additionally, the [Discourse](https://discourse.dhall-lang.org/) forum is active and very helpful.

Dhall makes it super easy to just play around with little snippets of code. You can copy & paste this into your shell `echo '{ key = "Value" }' | dhall` to see what it outputs[^1]. Run it with `dhall type` or `dhall --annotate` instead of just `dhall` to see more information about the expression. In general, exploring the different subcommands and flags of the `dhall` binary is time well invested. You can also navigate to any file in your project and play around with its contents like so `echo "(./file.dhall).someExport" | dhall`. And there's also a `dhall repl`! I love that kind of interactive development and it makes it super easy to get started with the language.

## Union Types

Having union types for configuration is generally amazing. It's pretty common that a key only accepts a narrow range of values and union types let you represent those rules pretty much one to one in your code. The compiler will then verify the correctness of your configuration for you. That's much more relaxed than having to do these checks manually.[^3] This saves you time and energy since you don't need to wait for your configuration to be deployed, and rejected, only to discover you made a typo somewhere.

```dhall
let Action = < Copy | Paste >

let Config = { action : Action }

-- Below doesn't compile since DangerousThing is not an allowed value!
-- let myConfig : Config = { action = Action.DangerousThing }

-- This is allowed!
let myConfig : Config = { action = Action.Paste }

in myConfig
```

What's slightly annoying about union types in Dhall is that there's no way of extending them, or making one union type the subtype of another. Consider the following:

```dhall
let Type1 = < A | B | C >
let Type2 = < A | B | C | D >
```

It's clear that `Type1` is "part of" `Type2`, meaning I should be able to do `Type2.A` and use that in any function accepting a `Type1`. But that's not (yet) a thing in Dhall, even though there's [an issue for it](https://github.com/dhall-lang/dhall-lang/issues/175).

There are various ways of dealing with this though. In an early version of `dhall-alacritty`, the base type would be imported into the more extensive types:

```dhall
let Base = < A | B >

let Extended = < Base : Base | C >
```

This works but requires additional work if there are several variations of `Extended` but you want to implement some shared functionality in the module where `Base` lives, which has to work on these variations. Imagine a record, which can hold variations of `Extended`, but the record as a whole mostly consists of shared keys and functionality. The below snippet shows one way of handling this situation in Dhall through the use of polymorphism. The snippet is big but it's not actually that complicated! It really boils down to **passing your extended union type and a function to handle that extension** to the code implementing the shared functionality. In other words: the shared record and the functions operating on that record know almost everything about said record, except for one key and how to work with it. So you're supplying them with this last piece of information to make them whole.

The output of the code below is `{ extraKey = "C", sharedKey = "5", sharedKey2 = "10" }` by the way.

_(Also if you're wondering what `merge` does, it's how you pattern match on union types, since there's no actual pattern matching in the style of Haskell)_

```dhall
let Prelude = https://prelude.dhall-lang.org/package.dhall

let Base = < A | B >

let showBase = λ(b : Base) → merge { A = "A", B = "B" } b

let Extended = < Base : Base | C >

let showExtended =
      λ(e : Extended)
      → merge { C = "C", Base = λ(b : Base) → showBase b } e

let Rec
    : ∀(extraType : Type) → Type
    =   λ(extraType : Type)
      → { sharedKey : Natural
        , sharedKey2 : Natural
        , extraKey : extraType }

let handleRec
    :   ∀(extraType : Type)
      → ∀(handleExtraType : extraType → Text)
      → ∀(rec : Rec extraType)
      → { sharedKey : Text, sharedKey2 : Text, extraKey : Text }
    =   λ(extraType : Type)
      → λ(handleExtraType : extraType → Text)
      → λ(rec : Rec extraType)
      → { sharedKey = Prelude.Natural.show rec.sharedKey
        , sharedKey2 = Prelude.Natural.show rec.sharedKey2
        , extraKey = handleExtraType rec.extraKey
        }

in  handleRec
      Extended
      showExtended
      { sharedKey = 5, sharedKey2 = 10, extraKey = Extended.C }

```

It's actually quite amazing that you can do this in your configuration language. Doesn't mean you have to, of course, and I doubt that it will come up very often.

## Polymorphism

The above paragraph brings me to my next point: polymorphism (hope I'm using the word correctly) in Dhall is fairly straight forward. In a type signature, you can use the `forall` keyword (turned into a pretty unicode symbol by `dhall format`) to create a type variable and then refer to that variable (and type) in the rest of the signature. Like so (example taken straight from my toy project)

_Not a runnable example. I ellided the function body to focus only on the type signature_

```dhall
let showBindings
    :   ∀(action : Type)
      → ∀(show : action → Text)
      → List (KeybindingIn action)
      → List Keybinding
```

Remember that part about extending union types from the paragraph above? That's exactly what's going on here. `KeybindingIn` is used in 3 different contexts and each context needs to first decide which `action` type to use with `KeybindingIn` and how that `action` type can be turned into a string. Armed with that knowledge `showBindings` can do all the heavy lifting.

This is quite powerful but can also impair readability of course. I dare say that most programmers would probably run away sreaming if you told them that their _configuration language_ requires them to understand snippets like the one above. Especially when their day job is something like Javascript or Go (disclaimer: that's my day job). In reality you probably won't need polymorphism in most cases. In the case of the union type you could just copy & paste the common constructors. It's a bit of a maintenance burden, but I'd rather do that and gain some type safety, than throw out the Dhall baby with the polymorphism bath water. Just because powerful features exist, doesn't mean you need to use them.

## Records

There are several helper functions and operators, which make working with records really enjoyable and straightforward in Dhall (that's quite the feat and the same can't be said about records in Haskell). You can shallow merge two records with the `//` operator. As the word shallow implies, this will completely override nested records:

```dhall
{ a = { b = 1, c = 2 } } ⫽ { a.b = 1 }
```

Returns `{ a.b = 1 }`, thereby losing the `c = 2` part. In practice this is less of a danger than it seems, since you'd probably have a type signature making sure that `c` is always present. There's also a recursive merge operator, `/\` but it does not allow for collisions. You can merge but you can't override. So how do you override something that's nested a few levels deep?

```dhall
{ a = { b = 1, c = 2 } } with a.c = 3
```

**I can't overstate how amazing this is**. You'd think that a statically typed, pure functional language would be more tedious at working with records than a dynamic language. Also note the use of the **dot operator** here, which is easy to read and write and makes working with nested records much more ergonomic.

Records can also have schemas, which is just a record with two keys, one for `Type` and one for `default`.

```dhall
let rec = { Type = { b : Natural, c : Natural }, default = { b = 0, c = 0 } }

in  rec::{=}
```

The `::{=}` creates the record with its default values and `::{ c = 5}` let's you shallow override the defaults. It's nice syntax sugar for creating a record with default values although you can achieve the same thing with the existing operators. I'm a fan of orthogonal features and so I'm not a big fan of this one (even though I've used it extensively in my own little toy project). Also this only works for records. `{ Type = Optional Natural, default = None }` does not compile. This means you'll likely end up mixing defaults with syntax sugar and defaults without anyway.

There's also a feature called [projections](https://docs.dhall-lang.org/tutorials/Language-Tour.html#records). It's a bit like destructuring in languages like JS or Clojure.

```dhall
let record = { a = 1, b = 2}

in record.{a}
```

In the first version of this post I complained about not understanding when and how to use this, but the [Discourse](https://discourse.dhall-lang.org/) community helped me with that. Still, I don't find this feature as useful as it could be, since it's a bit limited where you can actually use this. Or in other words, I think I was expecting this to be the equivalent of destructuring in JS and Clojure, which it's not:

_Does not compile since that's not how you use projections_
```dhall
let record = { a = 1, b = 2}

in \(rec.{a} : Record) -> a
```

Dhall doesn't currently have actual destructuring for things like function arguments. Check out some of the discussions for such a feature at [GitHub](https://github.com/dhall-lang/dhall-lang/issues/74).

Also note that if you need to generate a record dynamically you can [actually do so](https://docs.dhall-lang.org/tutorials/Getting-started_Generate-JSON-or-YAML.html#dynamic-records) without having to jump through any hoops, which is pretty neat. The reason I'm not emphasizing this more is that it didn't really come up when I was working with Dhall for `dhall-alacritty`, but it is something many people will want. It's this **attention to real world use cases** that really makes Dhall shine.

## Ergonomics & Tooling

I'm using `neovim` and the dhall language server kinda sorta works some of the time. It doesn't have a lot of features, so it's mostly about error checking and completion. In Visual Studio Code the experience is a bit better, but the features remain the same. The `dhall` binary and its subcommands is how I explore my code and ask the compiler questions about it. To me things like `dhall --annotate` or `dhall type` kind of achieve the same thing as typed holes in Haskell.

I've already mentioned a couple of ways for interactively working with Dhall code throughout this post (`echo '{}' | dhall`, `dhall --file ./file.dhall`), but there's also `dhall repl` which should probably be your first choice for playing around with Dhall. It has a `:help` command so there's no need for me to go through its commands.

One thing I find a bit strange is that currently `dhall format` removes comments. There's an [issue for that too](https://github.com/dhall-lang/dhall-haskell/issues/145) with some workarounds but it's really annoying. Imagine introducing Dhall at work and then not easily being able to leave helpful comments for your colleagues who may be new not only to Dhall but also functional programming in general.

Error messages in Dhall are generally really good but can be a bit hit and miss in certain cases. For smaller types (meaning here not too many keys, not too nested) they show you exactly what's wrong and are easy to interpret. In some cases they even includes helpful hints for common syntax mistakes, which reminded me a bit of Elm. For a project this young I'd say errors are mostly a shining beacon of excellence. It's only when working with huge records that the errors become more and more cryptic, since the size of the diff (expected vs actual) to some degree mirrors the size of the record. Meaning your terminal will suddenly be filled with a wall of text and lots of `...` to hide some lines deemed irrelevant for the error. All in all errors are mostly really good though. For example, here's one of those errors that also displays some helpful hints:

```
r : { Type : Type, default : Optional Natural }

Error: You can only override records

Explanation: You can override records using the ❰⫽❱ operator, like this:


    ┌───────────────────────────────────────────┐
    │ { foo = 1, bar = "ABC" } ⫽ { baz = True } │
    └───────────────────────────────────────────┘


    ┌─────────────────────────────────────────────┐
    │ λ(r : { foo : Bool }) → r ⫽ { bar = "ABC" } │
    └─────────────────────────────────────────────┘


... but you cannot override values that are not records.

For example, the following expressions are not valid:


    ┌──────────────────────────────┐
    │ { foo = 1, bar = "ABC" } ⫽ 1 │
    └──────────────────────────────┘
                                 ⇧
                                 Invalid: Not a record


    ┌───────────────────────────────────────────┐
    │ { foo = 1, bar = "ABC" } ⫽ { baz : Bool } │
    └───────────────────────────────────────────┘
                                 ⇧
                                 Invalid: This is a record type and not a record


    ┌───────────────────────────────────────────┐
    │ { foo = 1, bar = "ABC" } ⫽ < baz : Bool > │
    └───────────────────────────────────────────┘
                                 ⇧
                                 Invalid: This is a union type and not a record


────────────────────────────────────────────────────────────────────────────────

You supplied this expression as one of the arguments:

↳ None Natural

... which is not a record, but is actually a:

↳ Optional Natural

────────────────────────────────────────────────────────────────────────────────

1│                                                                r::{=}
```

## What Dhall Can Do For You

As promised, here's an example of how I used Dhall to model the rules for key mappings in alacritty. I'd say that this is not beginner level Dhall code anymore, especially if you're not familiar with some of the functional programming concepts in use. But I hope that it still illustrates just how much you can achieve in terms of type safety without having to do mental gymnastics and importing various PhD theses, thanks to Dhall's focus on real world use cases.

The alacritty configuration file let's you map keys to actions. This is fairly involved so I'll use a slightly simplified model so the code snippets don't blow up in size. Here's a mapping that binds the "A" key, when "Alt" is held down as well, to the "Copy" action.

```yaml
key_bindings:
  - key: A
    mods: Alt
    action: Copy
```

Modifiers and actions aren't just random strings though. There's a list of possible values for both, so let's model those rules in Dhall:

```dhall
let Modifier = < Alt | Control | Command >

let Action = < Copy | Paste >

let Binding = { mods : Optional Modifier, key : Text, action : Action }

let myBindings : List Binding =
        [ { mods = Some Modifier.Alt, key = "A", action = Action.Copy } ]

in  myBindings
```

Executing this file with `dhall-to-yaml --file ./file.dhall` gives me exactly the keybinding from above (without the actual `key_bindings` key). Yay for more type safety! It also improves the developer experience since you now get reliable autocompletion for allowed values! There's just one issue: this code doesn't support multiple modifiers. It should be possible to eventually render a `.yml` file with an entry like this:

```yaml
key_bindings:
  - key: A
    mods: Alt|Shift
    action: Copy
```

The `mods` key will now have to hold a list of modifiers and then we'll also need to create a function that turns `List Modifier` into `Text` by joining the modifiers with a `|`.[^2]

```dhall
let Prelude = https://prelude.dhall-lang.org/package.dhall

let Modifier =
    -- List the possible modifiers we have
    < Alt | Control | Command >

let renderModifier
    : Modifier → Text
    =
      -- Write a function that converts a single modifier to its text representation
      λ(m : Modifier)
      → merge { Alt = "Alt", Control = "Control", Command = "Command" } m

let convertModifiers
    : List Modifier → Text
    =
      -- Convert a list of modifiers to a string where the modifiers
      -- are joined with a pipe
      λ(m : List Modifier)
      → let mapped = Prelude.List.map Modifier Text renderModifier m

        let joined = Prelude.Text.concatSep "|" a

        in  joined

let Action = < Copy | Paste >

let Binding =
  -- Binding now let's you specify multiple modifiers for a given keybinding
  { mods : Optional (List Modifier), key : Text, action : Action }

let BindingRendered
    : Type
    = { mods : Optional Text, key : Text, action : Action }

let renderBinding
    : Binding → BindingRendered
    =
      -- Use the various functions from above to convert just a
      -- single key in Binding and then use that converted key
      -- and value to create the rendered version of Binding
      λ(b : Binding)
      → let mods =
              Prelude.Optional.map (List Modifier) Text convertModifiers b.mods

        in  { mods } // b.{action,key}

let myBindings
    : List Binding
    = [ { mods = Some [ Modifier.Alt, Modifier.Control ]
        , key = "A"
        , action = Action.Copy
        }
      ]

in  Prelude.List.map Binding BindingRendered renderBinding myBindings
```

:scream:! Let's go through this (I also annoted the file with comments!). The definition of `Modifier` is the same, but I've added a function for converting a value of that type to text (`renderModifier`). It uses the aforementioned `merge` function which let's you pattern match on different constructors of that union type. Here I'm simply mapping each union type value to a string (`Text`) of the same name.

The next function is a bit more involved, but the type signature is an excellent first thing to look at. `convertModifiers` takes a list of modifiers and outputs a single string. What it does is convert **each modifier to a text then combine them all with | in between**. I could also write this in a more compact manner:

_You can run this snippet by replacing `convertModifiers` in the snippet above_

```dhall
let convertModifiers
    : List Modifier → Text
    = Prelude.Function.compose
        (List Modifier)
        (List Text)
        Text
        (Prelude.List.map Modifier Text renderModifier)
        (Prelude.Text.concatSep "|")
```

The version using `compose` simply emphasises the concept of composition a bit more: the list of modifiers flows through a pipeline of "list of modifiers" -> "list of texts" -> "text", which is just a chain of two function calls. That chain can also be expressed as the composition of these two functions. I'd always go with the more verbose and explicit version first, unless I'm working in a team where I know everyone is comfortable with composition.

Back to the bigger snippet. `Binding` now **reflects the changed business logic** through `List Modifier`, and I've added a rendered version of binding. Notice how I need to repeat `key` and `action` though -- there's no merge & override type operator.

Lastly I'm putting all of this together with `renderBinding`. There's something really amazing going in there, which you may not know from other languages. Notice how inside `renderBinding` I'm **never checking if a value is Some or None**, even though both `Binding` and `BindingRendered` contain optional types. All of this plumbing is taken care of by `Prelude.Optional.map`. If you're coming from Elm, Purescript or Haskell this will be familiar. If not, it's like syntax sugar for `if (isSome) then doThis else doThat`.

So what's the output of the above snippets?

```
- action: Copy
  key: A
  mods: "Alt|Control"
```

Is it worth it? I think so. It's a lot of code but it's also a lot of safety. Everyone using that code to generate their mappings will benefit from the initial effort. To me code like this has a great multiplicative impact on others. Also some of the verbosity of Dhall comes from the fact that polymorphic functions require you to explicitly specify types. In Haskell you could simply do `map someFunc someOptional` and the compiler would infer the necessary types for you. In Dhall you need to explicitly state the input and output types of the `map` call.

## Closing Thoughts

Would I use Dhall at work? Absolutely. As I mentioned, I'm a fan of functional programming (FP). Unfortunately there's only a single developer I've met in real life (outside of FP meetups) who's interested enough in FP so that she started learning Elm on her own. There are many reasons why people aren't as excited about FP as I'd wish for, but one of them is simply that there are lots of alternatives. If you're doing just fine with JS, why look into something else? And that's precisely why I think Dhall has a lot of potential to introduce a bigger audience to FP: there aren't that many alternatives in this problem space.

Our kubernetes and helm configuration at work comes down to a mix of `.yaml` files with Go templating directives in strings, held together by conventions. There's nothing which verifies the correctness of the logic in your templates. Stuff like `{{- with .Values.labels }}` and

```
{{- default .Chart.Name .Values.nameOverride |
  replace "." "-" |
  lower |
  trunc 63 |
  trimSuffix "-" -}}
```

is a bug waiting to happen. It's also super exclusive. Imagine a junior developer trying to work with these files, without being able to verify that what they're doing makes any sense. Without understanding where `.Values` comes from, what's inside, what you can do with it. There's often no explicit connection between the variable in one file and its definition in another _(I say junior developer not to belittle them -- I also often don't know exactly what values I'm working with in these files)_.

Dhall isn't the only contender in this area but in my opinion it's the one best equipped to solve these issues. Dhall let's you ramp up the type safety gradually, it gives you _some_ programming features without letting you do whatever you want by limiting the language features it provides. You can improve the type safety **and** ergonomics of your configuration files with minimum effort and without any fancy types. You can also invest a lot of time and effort into making something critical as type safe as possible.

Dhall has a great and unique vision of how to apply a subset of FP to configuration files and I think it has great potential. Also you can easily learn the basiscs in a couple of hours so I'd encourage you to give it a try. The only thing you need to get started is the Dhall compiler and a terminal.

[^1]: In `bash` you can also use a HERE string (`<<<`) but I use `fish` so I'm using `echo` and pipe.
[^2]: At least that's one way of doing it. You could also change the type of `mods` to `Text` and just expect people to apply some `renderListOfModifiers` function to their `List Modifier` **before** creating the `Binding` record.
[^3]: You are only human -- Genji
