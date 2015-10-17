BrightFutures
=============

How do you leverage the power of Swift to write great asynchronous code? BrightFutures is our answer.

BrightFutures implements proven [functional concepts](http://en.wikipedia.org/wiki/Futures_and_promises) in Swift to provide a powerful alternative to completion blocks and support typesafe error handling in asynchronous code.

The goal of BrightFutures is to be *the* idiomatic Swift implementation of futures and promises.
Our Big Hairy Audacious Goal (BHAG) is to be copy-pasted into the Swift standard library.

## Latest news
[![CircleCI build status badge](https://img.shields.io/circleci/project/Thomvis/BrightFutures/master.svg)](https://circleci.com/gh/Thomvis/BrightFutures) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) [![CocoaPods version](https://img.shields.io/cocoapods/v/BrightFutures.svg)](https://cocoapods.org/pods/BrightFutures) [![MIT License](https://img.shields.io/cocoapods/l/BrightFutures.svg)](LICENSE) ![Platform iOS OS X](https://img.shields.io/cocoapods/p/BrightFutures.svg)

BrightFutures 3.0 is now available! Major parts of the framework have been rewritten for Swift 2 in order to leverage its power and provide the best compatibility. Please check the [Migration guide](Documentation/Migration_3.0.md) for help on how to migrate your project to BrightFutures 3.0.

## Installation
### [CocoaPods](http://cocoapods.org/)
Add the following to your [Podfile](http://guides.cocoapods.org/using/the-podfile.html):

```rb
pod 'BrightFutures'
```

Make sure that you are integrating your dependencies using frameworks: add `use_frameworks!` to your Podfile. Then run `pod install`.

### [Carthage](https://github.com/Carthage/Carthage)
Add the following to your [Cartfile](https://github.com/Carthage/Carthage/blob/master/Documentation/Artifacts.md#cartfile):

```
github "Thomvis/BrightFutures"
```

Run `carthage update` and follow the steps as described in Carthage's [README](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

## Documentation
- API documentation is available at the wonderful [cocoadocs.org](http://cocoadocs.org/docsets/BrightFutures) (100% documentation coverage)
- This README covers almost all features of BrightFutures
- The [tests](BrightFuturesTests) contain (trivial) usage examples for every feature (97% test coverage)
- The primary author, Thomas Visser, gave [a talk](https://www.youtube.com/watch?v=lgJT2KMMEmU) at the April 2015 CocoaHeadsNL meetup
- The [Highstreet Watch App](https://github.com/GetHighstreet/HighstreetWatchApp) is an Open Source WatchKit app that makes extensive use of BrightFutures

## Examples
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
let f = future { () -> Result<NSDate, ReadmeError> in
   let now: NSDate? = serverTime()
    if let now = now {
        return Result(value: now)
    }
    
    return Result(error: ReadmeError.TimeServiceError)
}

f.onSuccess { value in
    // value will the NSDate from the server
}
```

The future block needs an explict type because the Swift compiler is not able to deduce the type of multi-statement blocks. `ReadmeError` is an enum consisting of all errors that can happen in this readme.

## Providing Futures
Now let's assume the role of an API author who wants to use BrightFutures. The 'producer' of a future is called a `Promise`. A promise contains a future that you can immediately hand to the client. The promise is kept around while performing the asynchronous operation, until calling `Promise.success(result)` or `Promise.failure(error)` when the operation ended. Futures can only be completed through a Promise.

```swift
func asyncCalculation() -> Future<String, NoError> {
    let promise = Promise<String, NoError>()
    
    Queue.global.async {
        // do a complicated task and then hand the result to the promise:
        promise.success("forty-two")
    }
    
    return promise.future
}
```

`Queue` is a simple wrapper around a dispatch queue. `NoError` indicates that the `Future` cannot fail. This is guaranteed by the type system, since `NoError` has no initializers.

## Callbacks
You can be informed of the result of a `Future` by registering callbacks: `onComplete`, `onSuccess` and `onFailure`. The order in which the callbacks are executed upon completion of the future is not guaranteed, but it is guaranteed that the callbacks are executed serially. It is not safe to add a new callback from within a callback of the same future.

## Chaining callbacks

Using the `andThen` function on a `Future`, the order of callbacks can be explicitly defined. The closure passed to `andThen` is meant to perform side-effects and does not influence the result. `andThen` returns a new Future with the same result as this future.

```swift
var answer = 10

let f = Future<Int, NoError>(value: 4).andThen { result in
    switch result {
    case .Success(let val):
        answer *= val
    case .Failure(_):
        break
    }
}.andThen { result in
    if case .Success(_) = result {
        answer += 2
    }
}

// answer will be 42 (not 48)
```

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

f.zip(f1).onSuccess { a, b in
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
let f = future {
    // imagine a request failed
    return Result<Int, ReadmeError>(error: .RequestFailed)
}.recover { _ in // provide an offline default
    return 5
}.onSuccess { value in
    // value is 5 if the request failed or 10 if the request succeeded
}
```

In addition to `recover`, `recoverWith` can be used to provide a Future that will provide the value to recover with.

## Utility Functions
BrightFutures also comes with a number of utility functions that simplify working with multiple futures. These are implemented as free (i.e. global) functions to work around current limitations of Swift.

## Fold
The built-in `fold` function allows you to turn a list of values into a single value by performing an operation on every element in the list that *consumes* it as it is added to the resulting value. A trivial usecase for fold would be to calculate the sum of a list of integers.

Folding a list of Futures is not very convenient with the built-in `fold` function, which is why BrightFutures provides one that works especially well for our use case. BrightFutures' `fold` turns a list of Futures into a single Future that contains the resulting value. This allows us to, for example, calculate the sum of the first 10 Future-wrapped elements of the fibonacci sequence:

```swift
let fibonacciSequence = [future(fibonacci(1)), future(fibonacci(2)), ...,  future(fibonacci(10))]

// 1+1+2+3+5+8+13+21+34+55
fibonacciSequence.fold(0, f: { $0 + $1 }).onSuccess { sum in
    // sum is 143
}
```

## Sequence
With `sequence`, you can turn a list of Futures into a single Future that contains a list of the results from those futures.

```swift
let fibonacciSequence = [future(fibonacci(1)), future(fibonacci(2)), ..., future(fibonacci(10))]
    
fibonacciSequence.sequence().onSuccess { fibNumbers in
    // fibNumbers is an array of Ints: [1, 1, 2, 3, etc.]
}
```

## Traverse
`traverse` combines `map` and `fold` in one convenient function. `traverse` takes a list of values and a closure that takes a single value from that list and turns it into a Future. The result of `traverse` is a single Future containing an array of the values from the Futures returned by the given closure.

```swift
(1...10).traverse {
    i in future(fibonacci(i))
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

If you want to have custom threading behavior, skip do do not the section. next [:wink:](https://twitter.com/nedbat/status/194452404794691584)

## Custom execution contexts
The default threading behavior can be overridden by providing explicit execution contexts. By default, BrightFutures comes with three contexts: `Queue.main`, `Queue.global`, and `ImmediateExecutionContext`. You can also create your own by implementing the `ExecutionContext` protocol.

```swift
let f = future(ImmediateExecutionContext) {
    fibonacci(10)
}
    
f.onComplete(Queue.main.context) { value in
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
        ImageLoader.loadImage(model.image).onSuccess(token.validContext) { [weak self] UIImage in
            self.imageView.image = UIImage
        }
    }
}
```

By invalidating the token on every reuse, we prevent that the image of the previous model is set after the next model has been set.

Invalidation tokens _do not_ cancel the task that the future represents. That is a different problem. With invalidation tokens, the result is merely ignored. Invalidating a token after the original future completed does nothing.

If you are looking for a way to cancel a running task, you could look into using [NSProgress](https://developer.apple.com/library/ios/documentation/Foundation/Reference/NSProgress_Class/Reference/Reference.html).

## Credits

BrightFutures' primary author is [Thomas Visser](https://twitter.com/thomvis88). He is lead iOS Engineer at [Highstreet](http://www.highstreetapp.com/). We welcome any feedback and pull requests. Get your name on [this list](https://github.com/Thomvis/BrightFutures/graphs/contributors)!

BrightFutures was inspired by Facebook's [BFTasks](https://github.com/BoltsFramework/Bolts-iOS), the Promises & Futures implementation in [Scala](http://docs.scala-lang.org/overviews/core/futures.html) and Max Howell's [PromiseKit](https://github.com/mxcl/PromiseKit).

## License

BrightFutures is available under the MIT license. See the LICENSE file for more info.
