BrightFutures
=============

BrightFutures is a simple Futures &amp; Promises library for iOS and OS X written in Swift. I wrote BrightFutures to learn Swift and hope that in the process, I've created a library that proves to be useful.

BrightFutures uses Control Flow-like syntax to wrap complicated calculations and provide an asynchronous interface to its result when it becomes available.

# Examples

## Inline future

```swift
let f = future { error in
  CalculationResult(fibonacci(10))
}

f.onSuccess { value in
  // value will be the CalculationResult containing 55
}
```

(`CalculationResult` is a simple class wrapper around an Int, see 'Known Issues' below why.)

`error` is an inout parameter that can be set in the closure if the calculation failed. If `error` is non-nil after the execution of the closure, the future has failed. You can also hide the parameter if you don't need it:

```swift
let f = future { _ in
  CalculationResult(fibonacci(10))
}
```

## Returning a future
```swift
func complicatedComputation() -> Future<CalculationResult> {
  let promise = Promise<CalculationResult>()

  Queue.async {
  
    // do a complicated calculation
    
    promise.success(CalculationResult(55))
  }

  return promise.future
}
```

`Queue` is a simple wrapper around a dispatch queue.

## Custom execution contexts
By default, all tasks and callbacks are performed in a background queue. All future-wrapped tasks are performed concurrently, but all callbacks of a single future will be executed serially. You can however change this behavior by providing an execution context when creating a future or adding a callback:

```swift
let f = future({ _ in
  ComputationResult(fibonacci(10))
}, executionContext: ImmediateExecutionContext())
```

The calculation of the 10nth Fibonacci number is now performed on the same thread as where the future is created.

You can find more examples in the tests.

## Known Issues
- Futures can currently only return class types. I'd like a future to be able to return any value (classes, structs and enum's), but unfortunately I am running into a compiler error when I define my future like this:

```swift
class Future<T: Any>
```

  and have optional properties inside that class.

- I don't particularly like how the error handling is done. It is now an obligatory inout parameter of every future task closure.

# Feedback
I am looking forward to your feedback. I am very much still learning Swift. We all are. Let me know how I could improve BrightFutures by creating an issue, a pull request or by reaching out on twitter. I'm @thomvis88.
