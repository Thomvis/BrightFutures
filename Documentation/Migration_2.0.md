Please read the [changelog](../CHANGELOG.md) for 2.0 first.

BrightFutures 2.0 has a new dependency: Result. If you're using CocoaPods, `pod update` should automatically integrate it into your project. If you're using Carthage, after running `carthage update`, you need to add `Result.framework` to your target like you have also done for `BrightFutures.framework`. 

In files where you're using `Result`, you'll also need to add an import statement for the respecive frameworks. If you fail to do this, you will see errors like "Use of undeclared type 'Result'".

If you see error messages around `import Result`, the new dependencies have not yet been integrated correctly.

`Future` and `Result` in BrightFutures 1.0 have only one generic parameter: the value type. In BrightFutures 2.0, both types have gained a second generic parameter: the error type. This removes the dependency on `NSError`. If you want to continue to use `NSError`, this means that you'll have to go through your code and update the occurrences of `Future` and `Result`

Examples:

```swift
// BrightFutures 1.0:
`func loadNextBatch() -> Future<Void>`

// BrightFutures 2.0:
`func loadNextBatch() -> Future<Void, NSError>`
```

For people that have been using an enum to represent all possible errors, you can now use that error type directly in `Future` and `Result` types without translating it to a `NSError` first.

If you have been using `Future<Void>` in cases where you know the future will never succeed, you can now also use the `NoValue` type. `NoValue` is an enum with no cases, meaning it cannot be initiated. This offers a strong guarantee that a `Future<NoValue,Error>` will never be able to succeed. The `InvalidationToken` uses this.

If you have futures that you know can never fail, consider using the `NoError` as the error type. Like `NoValue`, `NoError` cannot be instantiated.

The easiest way to create `Result` instances is through its two constructors.

```swift
Result(success: 1314) // a Result.Success
Result(error: .DeserializationFailed(object: json) // a Result.Failure
```
In addition to this migration guide, you can take a look at the changes that were made to the tests during the development of 2.0. These can be found in the [2.0 PR diff](https://github.com/Thomvis/BrightFutures/pull/51/files#diff-a6ad99ed0ef578b716f34ca4e2d578f7L43).
