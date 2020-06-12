---
title: React Hooks are Tricky
date: 2019-07-15
publish: true
---

When hooks were first introduced, many people thought that they looked a bit magical. Especially the rule that the order of hooks must not change across renders received a lot of pushback. On the other hand, getting rid of the divide between class based and functional components, and making sharing of functionality between components easier, seemed really appealing. That was especially true for me, since I saw them as an opportunity to stop using `recompose` for absolutely everything in our codebase at work.

So I took one of our features and rewrote it using hooks. The goal was to see what using hooks feels like, what issues arise and what solutions are available, so that we're well prepared when we start using hooks throughout the entire codebase.

This post is an experience report, not a review.

## Creating a Timer

To me the trickiest part of hooks is the balancing act of making sure your callbacks don't reference stale data while at the same time minimizing rerenders. One example that highlights this issue is creating a timer that runs every second and increases a value. The twist is that the user can adjust the amount by which the value is increased, without this affecting the timer in any way. No slowdowns, no speedups. The code for this example can be found in [this repl.it](https://repl.it/@cideM/timer).

### Basic Building Blocks

The components are all very simple. There's a component displaying the current value and another that renders the input field, through which you can adjust the amount by which the value increases.

```js
function SomeChild({ x }) {
  return <p>Value: {x}</p>
}

function Input({ onChange, id, type, text }) {
  return (
    <input
      type={type}
      id={id}
      value={text}
      onChange={e => {
        onChange(e.target.value)
      }}
    />
  )
}
```

The timer starts running as soon as the component mounts. Any changes to the input field become visible on the next tick of the timer. Regardless of user input, the timer keeps running on a second interval.

While it looks super simple, implementing this functionality was surprisingly tricky. I'll demonstrate the different iterations this code went through, and how the intuitive solution turned out to be the wrong one.

### Pit of Despair

Below is the first solution that I came up with. I store both text input and value with the `useState` hook. Additionally, I start a timer in `useEffect` and in the body of that function I increase the current value. The timer is cleared when the component unmounts, thanks to the cleanup function returned from `useEffect`. So far, so good. And this actually works! Sort of...

You can copy & paste the code into the repl to observe the issue. If you type anything into the input field just as _the next tick of `setInterval` is about to kick in_, that next tick is delayed. What gives?

```js
function App() {
  const [input, setInput] = React.useState(`1`);
  const [x, setX] = React.useState(0);

  React.useEffect(() => {
    const id = setInterval(() => {
      setX(x + Number(input));
    }, 1000);

    return () => clearInterval(id);
  });
```

To understand this quirky behavior you need to understand how `useEffect` works. It will always run on mount and unmount, much like `componentDidMount` and `componentWillUnmount` [^1]. Additionally, it runs **after every completed render, including the cleanup function**. In the above example, the following happens:

1. Component mounts, `useEffect` runs.
2. User types into input field and state updates, triggering a render of `<App />`
3. `useEffect` runs. It first cleans up the previous interval, then starts a new interval.

If the preceding interval is cleaned up just as it's about to tick, and a new interval is then started, the pause that the user sees is duration old interval + duration new interval. In other words, we're not using a single interval for the entire lifetime of the component -- we're creating a new one on each render.

So how do we fix this? Pass an array of values, that the effect depends on, as a second argument to `useEffect`. We want our interval to remain active for the entire lifetime of the component, therefore we pass an empty array to `useEffect`. Now it only runs on mount and unmount. Wohoo!

```js
    return () => clearInterval(id);
    // eslint-disable-next-line
  }, []);
```

Except that now everything is broken. The interval ticks along nicely, but the value stays at 1.

The new issue is that the function passed to `setInterval` always refers to the initial state. So on each tick it increments 0 to 1 and that's it. You can imagine that on each render the state and props of a component are saved in a snapshot. On subsequent renders, rather than mutating the old snapshot, a new snapshot is created. React compares the virtual DOM that would result from old and new snapshot, and updates the real DOM accordingly.[^5]

But that also means that `x` and `input` in the function passed to `setInterval` will always refer to the values from the very initial render, since `useEffect` is **only run once, after the component rendered the first time** (because of the empty array I added as a second argument).

How can we solve this issue for good? Our requirements are:

- Start an interval that lives as long as the component
- Store the values in a way that we can always reference the most recent values

The solution below is more or less a 1:1 copy from Dan Abramov's [overreacted blog](https://overreacted.io/making-setinterval-declarative-with-react-hooks/), where he happened to talk about almost precisely this issue. I just inlined the function rather than creating a custom hook from it.

```js
const savedCallback = React.useRef()

React.useEffect(() => {
  savedCallback.current = () => {
    setTime(time + Number(input))
  }
})

React.useEffect(() => {
  let id = setInterval(() => {
    savedCallback.current()
  }, 1000)
  return () => clearInterval(id)
}, [])
```

The solution here is to store the function called in `setInterval` in a reference, with `useRef`[^2]. The interval is only created once, as can be seen from the empty dependency array. But instead of referring to a function from the first render of `<App />`, we access (and call), the most recent version of that function through the reference. On each render, we simply update that stored function, by reassigning `savedCallback.current` to a new function using the most recent state. We're mutating the reference in place! Even though `useEffect` only runs once, it can access the updated (mutated) function through the reference.

Fun fact, there's a [tweet](https://twitter.com/dan_abramov/status/1099842565631819776?lang=en) by Dan Abramov where he states that:

> useRef() is basically useState({current: initialValue })[0]

Meaning you can do this:

```js
const ref = useState({ current: 0 })[0]
ref.current = 2
console.log(ref.current) // 2
```

It's just JS after all. Nothing prevents you from mutating stuff willy nilly.

### Pit of Success

What would the timer example look like with class based components?

```js
class App extends React.Component {
  constructor() {
    super()
    this.state = {
      input: `1`,
      count: 0,
    }

    this.intervalId = null
  }

  increment = () => {
    this.setState({
      count: this.state.count + Number(this.state.input),
    })
  }

  componentDidMount() {
    this.intervalId = setInterval(this.increment, 1000)
  }

  componentWillUnmount() {
    clearInterval(this.intervalId)
  }

  setInput = value => {
    this.setState({
      input: value,
    })
  }

  render() {
    return (
      <main className="App">
        <Input
          id="timer-input"
          type="text"
          text={this.state.input}
          onChange={this.setInput}
        />
        <label htmlFor="timer-input">Enter a number:</label>
        <SomeChild value={this.state.count} />
      </main>
    )
  }
}
```

Writing this didn't require much thought. The key advantage of class based components is that methods are stable across renders and can set or refer to the most recent state without any additional work.

## Same Function, Different State

The next problem I ran into is related to the first example, although in a slightly different way. I created another [repl.it](https://repl.it/@cideM/hooks) to demonstrate the problem (it's a bit contrived, sorry). Imagine you have a parent that changes frequently. That parent passes a function down to one or more children. These children should _not re-render_ as frequently as the parent. But the function passed to them needs to update the parent state based on the most recent parent state. In other words, our requirements are:

- A function whose identity remains the same and which passes shallow equality checks
- A function which can get and set the most recent state

To demonstrate the problem I created a component that displays the current time. Note that I'm using `React.memo`, which makes sure that the component only re-renders if its props have changed. Equality is checked with standard, shallow equality.

```js
const ClickChild = React.memo(({ onClick }) => {
  return <div onClick={onClick}>click me. date: {Date.now()}</div>
})
```

The parent holds a counter, but it doesn't pass the current count down to the child.

```js
const [state, setState] = useState(0)
const increment = useCallback(
  () => {
    setState(state + 1)
  },
  [state]
)

return (
  <div>
    <ClickChild onClick={increment} />
    state: {state}
  </div>
)
```

The repl includes both a hooks and a class based version of this component. Click both versions and see that the class based one doesn't update the timestamp, meaning that the child doesn't re-render. In the hooks based version that is unfortunately the case.

Here's the problem: I already wrapped the `increment` function in `useCallback`. But I need to make that `useCallback` hook depend on the current state. Meaning everytime you click the child, the state is updated and `useCallback` reruns. But that's precisely not what we want! Now a new function is passed to `ClickChild` and it re-renders, even though it's not _using the count at all_.

There are two ways you can address this problem:

- Use the alternative function signature for the state updater function from `useState`: `setState(state => state + 1)`. Now we can pass an empty dependency array to `useCallback`. The major limitation here is that you can only use the state from a single `useState` call. If your function needs to use values from for example 5 different `useState` calls, this simply won't work. There's no `setState(state1, state2, state3 => ...)`.
- Use `useReducer` which is currently recommended for more complex cases [^3]

The advantage of the `useReducer` hook is that the dispatch function never changes. It's essentially like the alternative `setState` function signature, except that you're putting all your state in a single reducer, instead of in a single `setState`.

## Conclusion

I don't dislike hooks. I'm also not as hyper-enthusiastic about them as I once was. None of what I said here should be seen as an inherent criticism of hooks, rather it's a reminder that hooks require you to think differently about how you solve problems. Switching from classes to hooks reminds me of switching from an imperative language to a pure functional one.

I'd suggest that anyone looking into using hooks productively should have a solid understanding of shallow equality in JS. Especially with the rise of functionalish programming accompanied by using rest and spread in many places.

You should also understand how `useRef` works. Back in the day, refs were often avoided and their primary use appeared to be attaching them to DOM elements. But as the first part of this post shows, they can come in extremely handy with hooks.

Considering that I've already quoted Dan Abramov numerous times, it only makes sense to end this article with another quote from him:

> Disclaimer: this post focuses on a pathological case. Even if an API simplifies a hundred use cases, the discussion will always focus on the one that got harder.[^4]

[^1]: Unlike the lifecycle methods, the function passed to `useEffect` runs _after_ layout and paint. https://reactjs.org/docs/hooks-reference.html#timing-of-effects
[^2]: Alternatively you could also store input and value in references, but that would make things pretty unergonomical and would force all users of those values to reach them through `.current`.
[^3]: https://reactjs.org/docs/hooks-faq.html#what-can-i-do-if-my-effect-dependencies-change-too-often
[^4]: Dan Abramov, https://overreacted.io/making-setinterval-declarative-with-react-hooks/
[^5]: Dan Abramov, https://overreacted.io/a-complete-guide-to-useeffect/
