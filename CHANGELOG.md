# 8.2.0
- Adds support for Swift 5.6 and Xcode 13.3.
- Adds support for awaiting a Future's value.
- Adds support for @dynamicMemberLookup.

# 8.1.0
- Adds support for Swift 5.4 and Xcode 12.5. ([#216](https://github.com/Thomvis/BrightFutures/pull/216) & [#218](https://github.com/Thomvis/BrightFutures/pull/218), thanks [MagFer](https://github.com/MagFer), [MultiColourPixel](https://github.com/MultiColourPixel) & [paiv](https://github.com/paiv))
- Adds `Future.init(error: E, delay: DispatchTimeInterval)` ([#215](https://github.com/Thomvis/BrightFutures/pull/215), thanks [RomanPodymov](https://github.com/RomanPodymov))
- Fixed casing of various global constants. ([#176](https://github.com/Thomvis/BrightFutures/pull/176), thanks [Sajjon](https://github.com/Sajjon))
- Deprecated `NoValue` in favor of `Never`


# 8.0.1
- Fixes an issue that broke Swift Package Manager support. ([#208](https://github.com/Thomvis/BrightFutures/pull/208), thanks [slessans](https://github.com/slessans)!)

# 8.0.0
Adds support for Swift 5 and Xcode 10.2. Previous versions of Swift are no longer supported.

- Migrated from [antitypical/Result](https://github.com/antitypical/Result) to the new Result type in the standard library
- Removed `NoError` in favor of `Never` from the standard library

Thanks to [kimdv](https://github.com/kimdv) for doing most of the migration work!

# 7.0.1
- Updates Result dependency to 4.1 compatible versions. ([#203](https://github.com/Thomvis/BrightFutures/pull/203]) , thanks [Jeroenbb94](https://github.com/Jeroenbb94)!)
- Fixes an issue related to the threadDictionary on Linux ([#204](https://github.com/Thomvis/BrightFutures/pull/204), thanks [jgh-](https://github.com/jgh-)!)

# 7.0.0
Adds support for Swift 4.2 and Xcode 10.

- Upgrade Result dependency to 4.0.
- [FIX] Fixed a typo and incorrect reference in the `andThen` test ([https://github.com/Thomvis/BrightFutures/pull/197](#197), thanks [https://github.com/robertoaceves](robertoaceves)!)

# 6.0.1
Adds support for Swift 4.1 and Xcode 9.3 (tested with beta 4).

- Workaround for [SR-7059](https://bugs.swift.org/browse/SR-7059)

# 6.0.0
Adds support for Swift 4 and Xcode 9

# 5.2.0
Adds support for Swift 3.1 and Xcode 8.3

# 5.0.0
Adds support for Swift 3 and Xcode 8

# 4.1.1
Adds support for Swift 2.3 and Xcode 8 (tested with beta 4)

# 4.1.0
- [FIX] `AsyncType.delay()` now correctly starts the delay after the AsyncType has completed, which was the intended behavior. This fix can be breaking if you depended on the faulty behavior. ([https://github.com/Thomvis/BrightFutures/pull/139](#139), thanks [peyton](https://github.com/peyton)!)

# 4.0.0
BrightFutures 4.0.0 is compatible with Swift 2.2 and Xcode 7.3.

- [BREAKING] `NoError` has been removed from BrightFutures.
- [Breaking] `SequenceType.fold(_:zero:f:)` and methods that use it (such as `SequenceType.traverse(_:f:)` and `SequenceType.sequence()`) are now slightly more asynchronous: to prevent stack overflows, after a certain number of items, it will perform an asynchronous call.
- [FIX] Fixed stack overflow when using `sequence()` or `traverse()` on large sequences.

# 3.3.0
- Added three new variants of the `future` free function that enables easy wrapping of completionHandler-based API. Thanks @phimage!

Note: some versions are missing here

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
