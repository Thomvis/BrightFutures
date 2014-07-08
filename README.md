BrightFutures
=============

BrightFutures is a simple Futures &amp; Promises library for iOS and OS X written in Swift. I wrote BrightFutures to learn Swift and hope that in the process, I've created a library that proves to be useful.

BrightFutures uses Control Flow-like syntax to wrap complicated calculations and provide an asynchronous interface to its result when it becomes available.

## Compatibility
BrightFutures is compatible with Xcode 6 beta 3.

# Examples

## Control-flow syntax

```swift
let f = future { error in
  fibonacci(10)
}

f.onSuccess { value in
  // value will be 55
}
```

`error` is an inout parameter that can be set in the closure if the calculation failed. If `error` is non-nil after the execution of the closure, the future has failed. You can also hide the parameter if you don't need it:

```swift
let f = future { _ in
  fibonacci(10)
}
```

## Wrapping expressions in a Future
Using Swift's `@auto_closure` directive, BrightFutures provides a  simple way to wrap any expression into a Future.

```swift
future(fibonacci(10)).onSuccess { value in
    XCTAssert(value == 55)
}
```

This is great concise syntax if there is no need for a way to report a failure.

## The Promise of a Future value
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

Using the `andThen` function on a `Future`, the order of callbacks can be explicitly defined.

```swift
future { _ in
    fibonacci(10)
}.andThen { result -> String in
    if result.value > 5 {
        return "large"
    }
    return "small"
}.andThen { result -> Bool in
    return result.value == "large"
}.onSuccess { numberIsLarge in
    XCTAssert(numberIsLarge)
}
```

`result` is an instance of `TaskResult`, which mimics a typical `Try` construct as much as the Swift compiler currently allows.

## Recovering from errors
If a `Future` fails, use `recover` to offer a default or alternative value and continue the callback chain.

```swift
future { (inout error:NSError?) -> Int? in
    // fetch something from the web
    if (request.error) { // it could fail
        error = request.error
        return nil    
    }
}.recover { _ in // provide an offline default
    return 5
}.onSuccess { value in // either the request or the recovery succeeded
    XCTAssert(value == 5)
}
```

In addition to `recover`, `recoverWith` can be used to provide a Future that will provide the value to recover with.

## Custom execution contexts
By default, all tasks and callbacks are performed in a background queue. All future-wrapped tasks are performed concurrently, but all callbacks of a single future will be executed serially. You can however change this behavior by providing an execution context when creating a future or adding a callback:

```swift
let f = future(context: ImmediateExecutionContext()) { _ in
  fibonacci(10)
}

f.onComplete(context: QueueExecutionContext.main) { value in
  // update the UI, we're on the main thread
}
```

The calculation of the 10nth Fibonacci number is now performed on the same thread as where the future is created.

You can find more examples in the tests.

## Credits

BrightFutures is created by me, [Thomas Visser](https://github.com/Thomvis). I am an iOS Engineer at [Touchwonders](http://www.touchwonders.com/).

I really like Facebook's [BFTasks](https://github.com/BoltsFramework/Bolts-iOS), had a good look at the Promises & Futures implementation in [Scala](http://docs.scala-lang.org/overviews/core/futures.html) and also like what Max Howell is doing with [PromiseKit](https://github.com/mxcl/PromiseKit).

## Contact

I am looking forward to your feedback. I am very much still learning Swift. We all are. Let me know how I could improve BrightFutures by creating an issue, a pull request or by reaching out on twitter. I'm [@thomvis88](https://twitter.com/thomvis88).

## License

BrightFutures is available under the MIT license. See the LICENSE file for more info.
