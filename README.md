BrightFutures
=============

BrightFutures is a simple Futures &amp; Promises library for iOS and OS X written in Swift.

BrightFutures offers an alternative to success and failure blocks that are often used to communicate the result of an asynchronous operation. Instead, those operations can immediately return a `Future`, which serves as a _ticket_ for the eventual resulting value (or failure). The user of the operation can add callbacks to the `Future` object, pass it a long and compose it in meaningful (functional) ways.

The goal of this project is to port Scala's Futures & Promises ([guide](http://docs.scala-lang.org/overviews/core/futures.html), [api](http://www.scala-lang.org/api/current/#scala.concurrent.Future)) to Swift. Second to this readme, the Scala documentation should therefore also be of help.

## Current State
[![Travis build status badge](https://travis-ci.org/Thomvis/BrightFutures.svg?branch=master)](https://travis-ci.org/Thomvis/BrightFutures) (Travis is not yet supporting Swift 1.2)

The project is currently moving towards a 1.0 release. Issue [#12](https://github.com/Thomvis/BrightFutures/issues/12) has been created to track the progress towards that goal. Please feel free to provide feedback or file your requests! Until 1.0, the API could change significantly.

If you don't want to deal with frequent breaking changes, you are advised to use '[v1.0.0-beta.2](https://github.com/Thomvis/BrightFutures/releases/tag/1.0.0-beta.2)' for the time being.

## Installation
CocoaPods 0.36.0.beta.1 (a pre-release version) now supports Swift frameworks, thus allows you to add BrightFutures to your project:

```rb
pod 'BrightFutures', :git => "https://github.com/Thomvis/BrightFutures.git"
```

(It doesn't seem to work for me without `:git`, but it should.) You can also use BrightFutures through [Carthage](https://github.com/Carthage/Carthage) or by simply dragging the project into your workspace and adding the framework as a dependency of your target.


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
User.logIn(username,password).flatMap { user in
  Posts.fetchPosts(user)
}.onSuccess { posts in
  // do something with the user's posts
}.onFailure { error in
  // either logging in or fetching posts failed
}
```

Both `User.logIn` and `Posts.fetchPosts` now immediately return a `Future`. A future can either fail with an error or succeed with a value, which can be anything from an Int to your custom struct, class or tuple. You can keep a future around and register for callbacks for when the future succeeds or fails at your convenience.

When the future returned from `User.logIn` fails, e.g. the username and password did not match, `flatMap` and `onSuccess` are skipped and `onFailure` is called with the error that occurred while logging in. If the login attempt succeeded, the resulting user object is passed to `flatMap`, which 'turns' the user into an array of his or her posts. If the posts could not be fetched, `onSuccess` is skipped and `onFailure` is called with the error that occurred when fetching the posts. If the posts could be fetched successfully, `onSuccess` is called with the user's posts.

This is just the tip of the proverbial iceberg. A lot more examples and techniques can be found in this readme, by browsing through the tests or by checking out the official companion framework [FutureProofing](https://github.com/Thomvis/FutureProofing).

## Wrapping expressions
If you already have a function (or really any expression) defined that you just want to execute asynchronously, you can easily wrap it in a `future` block:

```swift
future {
  fibonacci(50)
}.onSuccess { num in
  // value is 12586269025
}
```

While this is really short and simple, it is equally limited. In many cases, you will need a way to indicate that the task failed. To do this, instead of returning the value, you can return a Result. Results can indicate either a success or a failure:

```swift
let f = future { () -> Result<NSDate> in
  let now: NSDate? = serverTime()
  if let someNow = now {
    return .Success(Box(someNow))
  }
  
  return .Failure(NSError(domain: "TimeServiceErrorDomain", code: 404, userInfo: nil))
}

f.onSuccess { value in
  // value will the NSDate from the server
}
```

(The future block needs an explict type because the Swift compiler is not able to deduce the type of multi-statement blocks. The returned date needs to be _boxed_ because the Swift compiler does not yet support variable layout enums.)

## Providing Futures
Now let's assume the role of an API author who wants to use BrightFutures. The 'producer' of a future is called a `Promise`. A promise contains a future that you can immediately hand to the client. The promise is kept around while performing the asynchronous operation, until calling `Promise.success(result)` or `Promise.failure(error)` when the operation ended. Futures can only be completed through a Promise.

```swift
func asyncCalculation() -> Future<String> {
  let promise = Promise<String>()

  Queue.global.async {
  
    // do a complicated task
    
    promise.success("forty-two")
  }

  return promise.future
}
```

`Queue` is a simple wrapper around a dispatch queue.

## Callbacks
You can be informed of the result of a `Future` by registering callbacks: `onComplete`, `onSuccess` and `onFailure`. The order in which the callbacks are executed upon completion of the future is not guaranteed, but it is guaranteed that the callbacks are executed serially. It is not safe to add a new callback from within a callback of the same future.

## Chaining callbacks

Using the `andThen` function on a `Future`, the order of callbacks can be explicitly defined. The closure passed to `andThen` is meant to perform side-effects and does not influence the result. `andThen` returns a new Future with the same result as this future.

```swift
var answer = 10

let f = Future.succeeded(4).andThen { result in
    switch result {
      case .Success(let val):
        answer *= val.value
      case .Failure(_):
        break
    }
}.andThen { result in
    if let val = result.value {
      answer += 2
    }
    return
}

// answer will be 42 (not 48)
```

`result` is an instance of `Result`, which mimics a typical `Try` construct as much as the Swift compiler currently allows. Due to limitations of generic enum types, the actual value needs to be boxed. (See [#8](https://github.com/Thomvis/BrightFutures/issues/8).)

## Functional Composition

### map

`map` returns a new Future that contains the error from this Future if this Future failed, or the return value from the given closure that was applied to the value of this Future. There's also a `flatMap` function that can be used to map the result of a future to the value of a new Future.

```swift
future {
    fibonacci(10)
}.map { number -> String in
    if number > 5 {
        return "large"
    }
    return "small"
}.map { sizeString in
    sizeString == "large"
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
Future.succeeded(3).filter { $0 > 5 }.onComplete { result in
  // failed with error NoSuchElementError
}

Future.succeeded("Swift").filter { $0.hasPrefix("Sw") }.onComplete { result in
  // succeeded with value "Swift"
}
```

## Recovering from errors
If a `Future` fails, use `recover` to offer a default or alternative value and continue the callback chain.

```swift
let f = future { () -> Result<Int> in
    // request something from the web
    
    if (request.error) { // it could fail
        return .Failure(request.error)
    }
    
    return .Success(Box(10))
}.recover { _ in // provide an offline default
    return 5
}.onSuccess { value in // either the request or the recovery succeeded
    // value is 5 if the request failed or 10 if the request succeeded
}
```

In addition to `recover`, `recoverWith` can be used to provide a Future that will provide the value to recover with.

## Utility Functions
BrightFutures also comes with a number of utility functions that simplify working with multiple futures. These functions are part of the `FutureUtils` class, which is the counterpart of Scala's `Future` object.

## Fold
The built-in `fold` function allows you to turn a list of values into a single value by performing an operation on every element in the list that *consumes* it as it is added to the resulting value. A trivial usecase for fold would be to calculate the sum of a list of integers.

Folding a list of Futures is not possible with the built-in fold function, which is why `FutureUtils` provides one that does work. Our version of fold turns a list of Futures into a single Future that contains the resulting value. This allows us, for example, to calculate the sum of the first 10 Future-wrapped elements of the fibonacci sequence:

```swift
// 1+1+2+3+5+8+13+21+34+55
let fibonacciSequence = [Future.succeeded(fibonacci(1)), Future.succeeded(fibonacci(2)), ... Future.succeeded(fibonacci(10))]

FutureUtils.fold(fibonacciSequence, zero: 0, op: { $0 + $1 }).onSuccess { val in
  // value is 143
}
```

## Sequence
With `FutureUtils.sequence`, you can turn a list of Futures into a single Future that contains a list of the results from those futures.

```swift
// 1+1+2+3+5+8+13+21+34+55
let fibonacciSequence = [Future.succeeded(fibonacci(1)), Future.succeeded(fibonacci(2)), ... Future.succeeded(fibonacci(10))]

FutureUtils.sequence(fibonacciSequence).onSuccess { fibNumbers in
    // fibNumbers is an array of Ints: [1, 1, 2, 3, etc.]
}
```

## Traverse
`FutureUtils.traverse` combines `map` and `fold` in one convenient function. `traverse` takes a list of values and a closure that takes a single value from that list and turns it into a Future. The result of `traverse` is a single Future containing an array of the values from the Futures returned by the given closure.

```swift
FutureUtils.traverse(Array(1...10)) {
    Future.succeeded(fibonacci($0))
}.onSuccess { fibNumbers in
  // fibNumbers is an array of Ints: [1, 1, 2, 3, etc.]
}
```

## Default Threading Model
BrightFutures tries its best to provide a simple and sensible default threading model. In theory, all threads are created equally and BrightFutures shouldn't care about which thread it is on. In practice however, the main thread is _more equal than others_, because it has a special place in our hearts and because you'll often want to be on it to do UI updates.

A lot of the methods on `Future` accept an optional _execution context_ and a block, e.g. `onSuccess`, `map`, `recover` and many more. The block is executed (when the future is completed) in the given execution context, which in practice is a GCD queue. When the context is not explicitly provided, the following rules will be followed to determine the execution context that is used:

- if the method is called from the main thread, the block is executed on the main queue (`Queue.main`)
- if the method is not called from the main thread, the block is executed on a global queue (`Queue.global`)

The `future` keyword uses a much simpler threading model. The block (or expression) given to `future` is always executed on the global queue. You can however provide an explicit execution context to override the default behavior.

If you want to have custom threading behavior, skip do do not the section. next

## Custom execution contexts
The default threading behavior can be overridden by providing explicit execution contexts. By default, BrightFutures comes with three contexts: `Queue.main`, `Queue.global`, and `ImmediateExecutionContext`. You can also create your own by implementing the `ExecutionContext` protocol.

```swift
let f = future(context: ImmediateExecutionContext { _ in
  fibonacci(10)
}

f.onComplete(context: Queue.main.context) { value in
  // update the UI, we're on the main thread
}
```

The calculation of the 10nth Fibonacci number is now performed on the same thread as where the future is created.

## Invalidation tokens
An invalidation token can be used to invalidate a callback, preventing it from being executed upon completion of the future. This is particularly useful in cases where the context in which a callback is executed changes often and quickly, e.g. in reusable views such as table views and collection view cells. An example of the latter:

```swift
class MyCell : UICollectionViewCell {
  var token = InvalidationToken()

  public override func prepareForReuse() {
    super.prepareForReuse()
    token.invalidate()
    token = InvalidationToken()
  }

  public func setModel(model: Model) {
    ImageLoader.loadImage(model.image).onSuccess(token: token) { [weak self] UIImage in
      self.imageView.image = UIImage
    }
  }
}
```

By invalidating the token on every reuse, we prevent that the image of the previous model is set after the next model has been set.

Invalidation tokens _do not_ cancel the task that the future represents. That is a different problem. With invalidation tokens, the result is merely ignored. The callbacks are invoked as soon as the token is invalidated, which is typically before the original future is completed, or if the original future is completed. Invalidating a token after the original future completed does nothing.

If you are looking for a way to cancel a running task, you should look into using [NSProgress](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSProgress_Class/Reference/Reference.html) (or [https://github.com/Thomvis/GoodProgress](https://github.com/Thomvis/GoodProgress) if you're looking for a nice Swift wrapper).

## Credits

BrightFutures is created by me, [Thomas Visser](https://github.com/Thomvis). I am an iOS Engineer at [Touchwonders](http://www.touchwonders.com/). I aspire for this project to have a growing list of [contributors](https://github.com/Thomvis/BrightFutures/graphs/contributors).

I really like Facebook's [BFTasks](https://github.com/BoltsFramework/Bolts-iOS), had a good look at the Promises & Futures implementation in [Scala](http://docs.scala-lang.org/overviews/core/futures.html) and also like what Max Howell is doing with [PromiseKit](https://github.com/mxcl/PromiseKit).

## Contact

I am looking forward to your feedback. I am very much still learning Swift. We all are. Let me know how I could improve BrightFutures by creating an issue, a pull request or by reaching out on twitter. I'm [@thomvis88](https://twitter.com/thomvis88).

## License

BrightFutures is available under the MIT license. See the LICENSE file for more info.
