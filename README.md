BrightFutures
=============

BrightFutures is a simple Futures &amp; Promises library for iOS and OS X written in Swift. I wrote BrightFutures to learn Swift and hope that in the process, I've created a library that proves to be useful.

BrightFutures uses Control Flow-like syntax to wrap complicated calculations and provide an asynchronous interface to its result when it becomes available.

# Examples

You can find more examples in the tests.

## Known Issues
- Futures can currently only return class types. I'd like a future to be able to return any value (classes, structs and enum's), but unfortunately I am running into a compiler error when I define my future like this:

```objective-c
class Future<T: Any>
```

and have optional properties inside that class.

# Feedback
I am looking forward to your feedback. I am very much still learning Swift. We all are. Let me know how I could improve BrightFutures by creating an issue, a pull request or by reaching out on twitter. I'm @thomvis88.