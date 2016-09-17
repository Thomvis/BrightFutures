/*:
# Welcome to BrightFutures!
Write great asynchronous code in Swift using futures and promises


## Getting Started
In Xcode, select the **Editor** menu and then **Show Rendered Markup**.
To see the output, click on the assistant editor button to display the console output.
*/

import Foundation
import XCPlayground
import Result

//: Once you have BrightFutures installed in your project, simply import the module.

import BrightFutures

//: ## Futures
//: A future is an object that is acts as a read-only placeholder for a result that does not exist yet.  Typically, this is the result of some asynchronous code.  Once the result is available, the future is considered complete.
//: 
//: A completed future can be either a success or a failure.  If successful, the future will call the `onSuccess(value)` callback method returning the value.  If the future failed, it will call the `onFailure(error)` method returning an error implementing the `ErrorType` protocol.

//: Note: There is also an `onComplete()` handler, but this returns the result enum.  It would be up to you to determine if the result was successful or a failure.


//: ## Hello World Example

future {
    return "Hello World"
}.onSuccess {
    println($0)
}

//: This code shows a future that will complete sometime in the future (in this case, it is completed immediately) and returning the string `"Hello World"`.  After a successful completion, the `onSuccess()` callback handler is executed and `"Hello World"` is printed on the console.


//: ## A Simple Example
//:
//: In the Hello World example the future would always be successful.  That's not always useful as we need to consider the case when errors occur in our code.  In order to return an error, you must first implement the `ErrorType` protocol.  An enum is very suitable to model error conditions, so let's use an enum!

enum SimpleError: String, ErrorType, Printable {
    case InvalidError = "Invalid Error"
    case DummyError = "Dummy Error"
    case SomeError = "Some Error"
    
    var nsError: NSError {
        // Note: In production code, return an actual NSError
        return NSError(domain: BrightFuturesErrorDomain, code: 100, userInfo: [:])
    }
    
    var description: String {
        return self.rawValue
    }
}


//: A `future { }` block is used to wrap an expression and create a future.  You can either return a value or a Result enum.
//:
//: Returning a value indicates that the future always succeeds.

future {
    // Always succeeds returning the value 1
    return 1
}.onSuccess {
    println($0)
}


//: The other option is to return a Result enum.  The Result enum has two states:
//:   * success - which you can associate the result value
//:   * failure - which you can associate anything that implements ErrorType
//:
//: Based on the whether the result was successful, the appropriate handler will get called.
//:
//: An example of a conditional return of a future:

func someOperation() -> Bool {
    // Change the return value to either true or false to see what happens.
    return false
}

future { () -> Result<Int, SimpleError> in
    if someOperation() {
        return Result.success(100)
    } else {
        return Result.failure(SimpleError.DummyError)
    }
}.onSuccess {
    value in
    println("The successful value is: \(value)")
}.onFailure {
    error in
    println(error)
}


//: ## Promises
//: 
//: A promise holds a future which can be used to return the future to external calling code.  Once your code has completed any asynchronous operation, you can use the promise to set the result.  Thus calling the `onSuccess()` or `onFailure()` handlers.

func theMeaningOfLife() -> Future<String, NoError> {
    let promise = Promise<String, NoError>()
    
    Queue.global.async {
        // do a complicated task and then hand the result to the promise:
        promise.success("forty-two")
    }
    
    return promise.future
}

theMeaningOfLife().onSuccess {
    value in
    println(value)
}


/*: 
 ## The User Login and Post Fetch Example

 The BrightFutures shows an excellent example of how you might use BrightFutures in actual code.
*/

//: Setting Up User Login and Post Fetch

class User: Printable {
    var username: String
    var password: String
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
//: We create a promise here that sometime in the future, the `logIn()` method will either return a User object or an Error.
    
    class func logIn(username: String, password: String) -> Future<User, NSError> {
        let promise = Promise<User, NSError>()
        
        Queue.global.async {
            // Let's pretend we're looking up a user from an api service or database...
            if username == "thomvis" && password == "thomvis" {
                promise.success(User(username: "thomvis", password: "thomvis"))
            } else {
                promise.failure(NSError(domain: BrightFuturesErrorDomain, code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid Username and/or Password"]))
            }
        }

        return promise.future
    }
    
    var description: String {
        return "{ User: \(username) }"
    }
}

class Post: Printable {
    var user: User
    var post: String
    
    init(whoPosted: User, post: String) {
        self.user = whoPosted
        self.post = post
    }
    
//: Similarly, we create a promise here that sometime in the future, the `fetchPosts()` method will return a list of Posts or an Error.
    
    class func fetchPosts(user: User) -> Future<[Post], NSError> {
        let promise = Promise<[Post], NSError>()
        
        Queue.global.async {
            // Let's assume we're fetching data from some network call or database...
            // You can play with this flag and see what happens!
            let fetchPostSuccessful = true
            
            if fetchPostSuccessful {
                var posts = [Post]()
                
                posts.append(Post(whoPosted: user, post: "abcd"))
                posts.append(Post(whoPosted: user, post: "hello"))
                posts.append(Post(whoPosted: user, post: "world"))
                
                promise.success(posts)
            } else {
                promise.failure(NSError(domain: BrightFuturesErrorDomain, code: 101, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch posts"]))
            }
        }
        
        return promise.future
    }
    
    var description: String {
        return "{ \(user), Post: \(post) }"
    }
}

//: ### The Login and Fetch Posts Example

//: Too many callbacks can make your code hard to read and difficult to understand.  Not to mention, the rightward drift that is  associated with callback code.  The following shows an example of callbacks that's starting to get out of hand.  While this is a simple example, imagine if you had callback code that's three or four layers deep.
/*:
    User.logIn(username, password) { user, error in
        if !error {
            Posts.fetchPosts(user, success: { posts in
                // do something with the user's posts
            }, failure: handleError)
        } else {
            handleError(error) // handeError is a custom function to handle errors
        }
    }
*/
//: 
//: By using promises, you can write your code more cleanly and understandable.

// You can change the username and password to see what happens!
User.logIn("thomvis", password: "thomvis").flatMap { user in
    Post.fetchPosts(user)
}.onSuccess { posts in
    // do something with the user's posts
    println("Fetched Posts")
    for post in posts {
        println(post)
    }
}.onFailure { error in
    // either logging in or fetching posts failed
    println(error)
}

//: The `onSuccess()` handler only executes if both promises are successful, otherwise the `onFailure()` handler is executed.  Notice that if you give a wrong password or set the `fetchPostSuccessful` to `false`, the appropriate error gets propagated to the `onFailure()` handler.


//: ## Functional Primatives
//: Check back in the future

//: ## A Real World Example
//: Check back in the future

//: ## Invalidation Tokens
//: Check back in the future


//: ## More Information
//:
//:
//: For more information on Futures and Promises, read the following link on the [Scala Futures and Promises](http://docs.scala-lang.org/overviews/core/futures.html) implementation for which BrightFutures is heavily based.


XCPSetExecutionShouldContinueIndefinitely()
