---
title: The Compose Newtype and its Applicative Instance
date: '2019-03-27'
publish: true
---

When I went through _Haskell From First Principle_ the first time, I struggled with the `Compose` applicative instance, which is part of an exercise in chapter 25. This post will give you a quick overview of the `Compose` data type and then explain how the applicative instance for that type works.

The `Compose` data type is [part of base](http://hackage.haskell.org/package/base-4.12.0.0/docs/Data-Functor-Compose.html) and allows composing two functors:

```haskell
> :m Data.Functor.Compose
> let a = Right (Just 2)
> :t Compose a
> Compose a :: Num a => Compose (Either a2) Maybe a
```

_Any code that starts with `>` is meant to be run in a repl, such as `stack ghci` or `ghci`._

Here we took two functors (a `Maybe` and an `Either`) and composed them, giving us a new functor! Why is that useful?

```haskell
> :m Data.Functor.Compose
> let a = Right (Just 2)
> fmap ((+) 2) a
• No instance for (Num (Maybe Int)) arising from a use of ‘+’
```

This does not work because `fmap` is trying to map `(+) 2` over our `Either`, which is equivalent to applying `(+) 2` to `Just 2` which doesn't work. However, with the help of `Compose` we can create a new functor from `Either` and `Maybe` which will work with `fmap`!

```haskell
> :m Data.Functor.Compose
> let a = Right (Just 2)
> let b = Compose a
> fmap ((+) 2) b
Compose (Right (Just 4))
```

## The Problem

In the book, you're tasked with writing the applicative instance for `Compose`, which requires at least two functions[^1]: `pure` and `<*>`.

```haskell
pure :: a -> fa a
(<*>) :: fa (a -> b) -> fa a -> fa b
```

I really struggled with the definition of `<*>`, so I turned to google to find some solutions that I could then reverse engineer. Here's one possible definition:

```haskell
instance (Applicative fa, Applicative fb) =>
  Applicative (Compose fa fb) where
  (<*>) ::
       Compose fa fb (a -> b)
    -> Compose fa fb a
    -> Compose fa fb b
  Compose x <*> Compose y =
    Compose ((<*>) <$> x <*> y)
```

_Functor types are named fa, fb, and so on. If you see an f, it's a function, both on the type and the data level. I refer to fa and fb as functors since the applicative type class requires those things to be functors._

As is often the case with Haskell, the code is really concise. In a single line we're dealing with three operators and one of them is the very operator we're defining for `Compose` (`<*>`). While that kind of code is a joy to read and write if you're fluent in all things functor and applicative, it's a mouthful if you're trying to improve your understanding of these topics.

So let's work through the implementation one step at a time!

## Something Concrete

The code below shows a function `(+) 2` wrapped in a `Maybe`. We apply it to a value (wrapped in a `Maybe`) by using `<*>`. Simple enough.

```haskell
> let a = Just ((+) 2)
> let b = Just 5
> a <*> b
Just 7

       Just ((+) 2)     Just 5    Just 7
<*> :: fa   (a -> b) -> fa   a -> fa   b
```

Let's up the ante a bit and wrap both the function and the value in another `Maybe`.

```haskell
> let a = Just (Just ((+) 2))
> let b = Just (Just 5)
> a <*> b
```

This does not work since we can't just add another layer and expect the original `<*>` to work. After all, its type signature expects function and value to be inside a single functor, not nested in another.

So what's the #1 solution for manipulating nested stuff in Haskell? `fmap` all the things!

```haskell
> :m Control.Applicative
> let a = Just (Just ((+) 2))
> let b = Just (Just 5)
> fmap (<*>) a <*> b
```

We map `<*>` over `a`, meaning we partially apply `<*>` to the `Just ((+) 2)` inside `a`. We then take that partially applied function (which is still inside the functor `a`) and apply it to the `Just 5` in `b`. Please go ahead and open a repl now and play around with that code, it can do wonders for understanding stuff like that.

## Something Abstract

But how does the `fmap` knowledge from the last paragraph help us make sense of the instance code?

```haskell
instance (Applicative fa, Applicative fb) =>
  Applicative (Compose fa fb) where
  (<*>) ::
       Compose fa fb (a -> b)
    -> Compose fa fb a
    -> Compose fa fb b
  Compose x <*> Compose y =
    Compose ((<*>) <$> x <*> y)
```

The first part `(<*>) <$> x` written without infix notation and `fmap` instead of the operator is `fmap (<*>) x`. We map the function `<*>` over `x` and `x` has the type `fa fb (a -> b)`. We therefore apply `<*>` to the `fb (a -> b)` inside `x`. Check out the commented code below, which hopefully makes things clearer.

```haskell
instance (Applicative fa, Applicative fb) =>
  Applicative (Compose fa fb) where
    (<*>) ::
          Compose fa fb (a -> b)
                 --  ^^^^^^^^^^^
                 -- This is the first argument to <*>
       -> Compose fa fb a
       -> Compose fa fb b
    Compose x <*> Compose y =
        -- fa' :: fa (fb a -> fb b)
        --            ^^^^ The 2nd argument to <*>
        let fa' = fmap (<*>) x
               -- ^^^^ mapping <*> over x means applying
               -- <*> to the content of x
        in ???
```

The `<*>` only needs its 2nd argument now, which is a functor with a value inside it. And we have something like that **inside** our `y` (`y` is `fa fb b` and therefore the missing argument to `<*>` is the `fb b` part inside the `fa`). How can we apply a function inside a functor to a value inside a functor? `<*>`! And that's how we arrive at the 2nd part:

```haskell
instance (Applicative fa, Applicative fb) =>
  Applicative (Compose fa fb) where
    (<*>) ::
          Compose fa fb (a -> b)
       -> Compose fa fb a
       -> Compose fa fb b
    Compose x <*> Compose y =
        let fa' = fmap (<*>) x
        in Compose $ fa' <*> y
```

This is not so different from how we used `<*>` in "Something Concrete", just that both arguments have an additional level of nesting. Aligning the type signatures of `<*>` (top) and `Compose x <*> Compose y` (bottom) helps with visualising the similarities. It's the exact same operation one level deeper for both arguments.

```haskell
   fb (a -> b) ->    fb a ->    fb b
fa fb (a -> b) -> fa fb a -> fa fb b
```

Quick recap:

- `fmap (<*>) x`: Partially apply `<*>` the contents of `x`, which gives us a functor holding a partially applied function.
- `fa' <*> y`: Fully apply the `<*>` inside `fa'` (!) to the contents of `y` through another use of `<*>`.

## The hackage implementation

The implementation of the applicative instance using `<*>` and a mix of infix operators requires some mental gymnastics. On [hackage](http://hackage.haskell.org/package/base-4.12.0.0/docs/src/Data.Functor.Compose.html#line-112) however the instance uses `liftA2`, which does a much better job of communicating the essence of what's going on. Here's an example of how `liftA2` works, and where it's compared to our use of `liftA` from above.

```haskell
> let a = Just (Just ((+) 2))
> let b = Just (Just 5)
> fmap (<*>) a <*> b
Just (Just 7)
> liftA (<*>) a <*> b
Just (Just 7)
> liftA2 (<*>) a b
Just (Just 7)
```

As you can see, `liftA2` leads to the same result but is a bit more concise and expressive in this case. We can use `liftA2` to conveniently apply `<*>` to the contents of the two functors in the two `Compose` types.

## Edit

Thanks to `u/Syrak` from reddit for reminding me that `liftA` and `fmap` are pretty much the same. I edited the post so that `liftA` is only used at the very end. See also [his comment](https://www.reddit.com/r/haskell/comments/b8067x/blog_post_the_compose_newtype_and_its_applicative/ejvt62y?utm_source=share&utm_medium=web2x) for more insights!

[^1]: Technically the minimal definition of applicative requires `pure` and either `<*>` or `liftA2`
