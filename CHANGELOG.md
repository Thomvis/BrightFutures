# 3.0.0-beta.4
- The implementation of `mapError` now explicitly uses `ImmediateExecutionContext`, fixing unnecessary asynchronicity
- Adds `delay(interval: NSTimeInterval)` on `Async`, which produces a new `Async` that completes with the original Async after the given delay
- All FutureUtils free functions are now functions in extensions of the appropriate types (e.g. SequenceType)
- `InvalidationToken` instances now have a `validContext` property which is an `ExecutionContext` that can be passed to any function that accepts an `ExecutionContext` to make the effect of that function depend on the validity of the token.
- Added support for `NSOperationQueue` as an `ExecutionContext`

# 2.0.1
- Adds an implementation of `flatMap` that allows a function to be passed in immediately. Thanks @nghialv!

# 3.0.0-beta.1
This release is compatible with Swift 2. It is a direct port of 2.0, meaning it makes no use of new Swift 2 features yet.

- Removed our homegrown 'ErrorType' with Swift 2's native one
- The 'Box' dependency is gone. Swift 2 removed the need for boxing associated values in enums!

Because antitypical/Result has not yet released a Swift 2 compatible release on CocoaPods, this version of BrightFutures can not yet be built using CocoaPods.

# 2.0.0
- Replaced homegrown `Result` and `Box` types with Rob Rix' excellent types.
- Futures & Promises are now also parametrizable by their error type, in addition to their value type: `Future<ValueType, ErrorType>`. This allows you to use your own (Swifty) error type, instead of `NSError`!
- Adds `BrightFuturesError` enum, containing all three possible errors that BrightFutures can return
- Renames `asType` to `forceType` to indicate that it is a _dangerous_ operation

- Adds missing documentation (jazzy reports 100% documentation coverage!)
- Adds a lot of tests (test coverage is now at 97%, according to [SwiftCov](https://github.com/realm/SwiftCov)!)

# 1.0.1
- Updated README to reflect the pre-1.0.0 change from FutureUtils functions to free functions

# 1.0.0
- The FutureUtils class has been removed in favor of a collection of free functions. This allows for a nicer function type signature (e.g. accepting all sequences instead of just arrays)

# 1.0.0-beta.3
Note: The overview for this release is incomplete
- Changed `ExecutionContext` from a protocol to a function type. This allows for better composition. It does mean that a Queue cannot be used directly as an `ExecutionContext`, instead use the `context` property (e.g. `Queue.main.context`) or the `toContext` function (e.g. `toContext(Queue.main)`).

# 1.0.0-beta.2
Note: this overview is incomplete
- `TaskResultValueWrapper` has been renamed to the conventional name `Box`
- `TaskResult` has been renamed to the conventional name `Result`

# 1.0.0-beta.1
This release marks the state of the project before this changelog was kept up to date.
