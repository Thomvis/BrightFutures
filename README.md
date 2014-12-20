BrightFutures
=============

BrightFutures is a simple Futures &amp; Promises library for iOS and OS X written in Swift.

BrightFutures uses Control Flow-like syntax to wrap complicated calculations and provide an asynchronous interface to their result when it becomes available.

The goal of this project is to port Scala's Futures & Promises ([guide](http://docs.scala-lang.org/overviews/core/futures.html), [api](http://www.scala-lang.org/api/current/#scala.concurrent.Future)) to Swift. Second to this readme, the Scala documentation should therefore also be of help.

## Current State
[![Travis build status badge](https://travis-ci.org/Thomvis/BrightFutures.svg?branch=master)](https://travis-ci.org/Thomvis/BrightFutures)

BrightFutures is compatible with Swift 1.0. The project is currently moving towards a 1.0 release. Issue [#12](https://github.com/Thomvis/BrightFutures/issues/12) has been created to track the progress towards that goal. Please feel free to provide feedback or file your requests! Until 1.0, the API could change significantly.

If you don't want to deal with frequent breaking changes, you are advised to use '[v1.0.0-beta.1](https://github.com/Thomvis/BrightFutures/releases/tag/v1.0.0-beta.1)' for the time being.

## Examples
### Motivating Use Case
We write a lot of asynchronous code. Whether we're waiting for something to come in from the network or want to perform an expensive calculation off the main thread and then update the UI, we often do the 'fire and callback' dance. Here's a typical snippet of asynchronous code:

```swift
User.logIn(username, password) { user, error in
  if !error {
    Posts.fetchPosts(user, success: { posts in
        // do something with the user's posts
    }, failure: handleError)
  } else {
    handleError(error) // handeError is a custom function to handle errors
  }
}
```

Now let's see what BrightFutures can do for you:

```swift
User.logIn(username,password).flatMap { user, _ in
  Posts.fetchPosts(user)
}.onSuccess { posts in
  // do something with the user's posts
}.onFailure { error in
  // either logging in or fetching posts failed
}
```

Both `User.logIn` and `Posts.fetchPosts` now immediately return a `Future`. A future can either fail with an error or succeed with a value, which can be anything from an Int to your custom struct, class or tuple. You can keep a future around and register for callbacks for when the future succeeds or fails at your convenience.

When the future returned from `User.logIn` fails, e.g. the username and password did not match, `flatMap` and `onSuccess` are skipped and `onFailure` is called with the error that occurred while logging in. If the login attempt succeeded, the resulting user object is passed to `flatMap`, which 'turns' the user into an array of his or her posts. If the posts could not be fetched, `onSuccess` is skipped and `onFailure` is called with the error that occurred when fetching the posts. If the posts could be fetched successfully, `onSuccess` is called with the user's posts.

This is just the tip of the proverbial iceberg. A lot more examples and techniques can be found in this readme or by looking at the tests.

## The base case
If you already have a function (or really any expression) defined that you just want to execute asynchronously, you can just wrap it in a `future()` call and turn it into a Future:

```swift
future(fibonacci(10)).onSuccess { value in
  // value is 55
}
```

While this is really short and simple, it is equally limited. In many cases, you will need a way to indicate that the task failed. That is where the control-flow syntax comes in.

## Control-flow syntax

Because Swift allows to omit parenthesis for a function call if the only parameter is closure, we can pretend to add a `future` construct to the language:

```swift
let f = future { error in
  fibonacci(10)
}

f.onSuccess { value in
  // value will be 55
}
```

`error` is an inout parameter that can be set in the closure if the calculation failed. If `error` is non-nil after the execution of the closure, the future is considered to have failed.

## Providing Futures
Now let's assume the role of an API author who wants to use BrightFutures. The 'producer' of a future is called a `Promise`. A promise contains a future that you can immediately hand to the client. The promise is kept around while performing the asynchronous operation, until calling `Promise.success(result)` or `Promise.error(error)` when the operation ended. Futures can only be completed through a Promise.

```swift
func complicatedQuestion() -> Future<String> {
  let promise = Promise<String>()

  Queue.async {
  
    // do a complicated task
    
    promise.success("forty-two")
  }

  return promise.future
}
```

`Queue` is a simple wrapper around a dispatch queue.

## Chaining callbacks

Using the `andThen` function on a `Future`, the order of callbacks can be explicitly defined. The closure passed to `andThen` is meant to perform side-effects and does not influence the result. `andThen` returns a new Future with the same result as this future.

```swift
var answer = 10

future(4).andThen { result in
    switch result {
      case .Succeeded(let val):
        answer *= val.value
      case .Failure(_):
        break
    }    
}.andThen { result in
    // short-hand for the switch statement. Closure is executed immediately iff result is .Succeeded
    result.succeeded { val in
      answer += 2
    }
}

// answer will be 42 (not 48)
```

`result` is an instance of `TaskResult`, which mimics a typical `Try` construct as much as the Swift compiler currently allows. Due to limitations of generic enum types, the actual value needs to be wrapped in the `.value` property. (See [#8](https://github.com/Thomvis/BrightFutures/issues/8).)

## Functional Composition

### map

`map` returns a new Future that contains the error from this Future if this Future failed, or the return value from the given closure that was applied to the value of this Future. There's also a `flatMap` function that can be used to map the result of a future to the value of a new Future.

```swift
future { _ in
    fibonacci(10)
}.map { number, error in
    if number > 5 {
        return "large"
    }
    return "small"
}.map { sizeString, _ in
    return sizeString == "large"
}.onSuccess { numberIsLarge in
  // numberIsLarge is true
}
```

### zip

```swift
let f = future(1)
let f1 = future(2)

f.zip(f1).onSuccess { (let a, let b) in
    // a is 1, b is 2
}
```

### filter
```swift
future(3).filter { $0 > 5 }.onComplete { result in
  // failed with error NoSuchElementError
}

future("Swift").filter { $0.hasPrefix("Sw") }.onComplete { result in
  // succeeded with value "Swift"
}
```

## Recovering from errors
If a `Future` fails, use `recover` to offer a default or alternative value and continue the callback chain.

```swift
future { _ in
    // fetch something from the web
    if (request.error) { // it could fail
        error = request.error
        return nil    
    }
}.recover { _ in // provide an offline default
    return 5
}.onSuccess { value in // either the request or the recovery succeeded
  //value is 5
}
```

In addition to `recover`, `recoverWith` can be used to provide a Future that will provide the value to recover with.

## Custom execution contexts
By default, all tasks and callbacks are performed on the global GCD queue. All future-wrapped tasks are performed concurrently, but all callbacks of a single future will be executed serially. You can however change this behavior by providing an execution context when creating a future or adding a callback:

```swift
let f = future(context: ImmediateExecutionContext()) { _ in
  fibonacci(10)
}

f.onComplete(context: Queue.main) { value in
  // update the UI, we're on the main thread
}
```

The calculation of the 10nth Fibonacci number is now performed on the same thread as where the future is created.

## Utility Functions
BrightFutures also comes with a number of utility functions that simplify working with multiple futures. These functions are part of the `FutureUtils` class, which is the counterpart of Scala's `Future` object.

## Fold
The built-in `fold` function allows you to turn a list of values into a single value by performing an operation on every element in the list that *consumes* it as it is added to the resulting value. A trivial usecase for fold would be to calculate the sum of a list of integers.

Folding a list of Futures is not possible with the built-in fold function, which is why `FutureUtils` provides one that does work. Our version of fold turns a list of Futures into a single Future that contains the resulting value. This allows us, for example, to calculate the sum of the first 10 Future-wrapped elements of the fibonacci sequence:

```swift
// 1+1+2+3+5+8+13+21+34+55
let fibonacciSequence = [future(fibonacci(1)), future(fibonacci(2)), ... future(fibonacci(10))]

FutureUtils.fold(fibonacciSequence, zero: 0, op: { $0 + $1 }).onSuccess { val in
  // value is 143
}
```

## Sequence
With `FutureUtils.sequence`, you can turn a list of Futures into a single Future that contains a list of the results from those futures.

```swift
// 1+1+2+3+5+8+13+21+34+55
let fibonacciSequence = [future(fibonacci(1)), future(fibonacci(2)), ... future(fibonacci(10))]

FutureUtils.sequence(fibonacciSequence).onSuccess { fibNumbers in
    // fibNumbers is an array of Ints: [1, 1, 2, 3, etc.]
}
```

## Traverse
`FutureUtils.traverse` combines `map` and `fold` in one convenient function. `traverse` takes a list of values and a closure that takes a single value from that list and turns it into a Future. The result of `traverse` is a single Future containing an array of the values from the Futures returned by the given closure.

```swift
FutureUtils.traverse(Array(1...10)) {
    future(fibonacci($0))
}.onSuccess { fibNumbers in
  // fibNumbers is an array of Ints: [1, 1, 2, 3, etc.]
}
```

You can find more examples in the tests.

## Credits

BrightFutures is created by me, [Thomas Visser](https://github.com/Thomvis). I am an iOS Engineer at [Touchwonders](http://www.touchwonders.com/). I aspire for this project to have a growing list of [contributors](https://github.com/Thomvis/BrightFutures/graphs/contributors).

I really like Facebook's [BFTasks](https://github.com/BoltsFramework/Bolts-iOS), had a good look at the Promises & Futures implementation in [Scala](http://docs.scala-lang.org/overviews/core/futures.html) and also like what Max Howell is doing with [PromiseKit](https://github.com/mxcl/PromiseKit).

## Contact

I am looking forward to your feedback. I am very much still learning Swift. We all are. Let me know how I could improve BrightFutures by creating an issue, a pull request or by reaching out on twitter. I'm [@thomvis88](https://twitter.com/thomvis88).

## License

BrightFutures is available under the MIT license. See the LICENSE file for more info.
