# indigo
an objective-c lua binding
## features
### 1) Swift code style
You no longer need to write colon when calling functions, just write dot `.`
everywhere except when creating class.
```lua
--call class methods
self.class.classFoo_(89)
--call methods
local cell = tableView.dequeueReusableCellWithIdentifier_("cell")
```
### 2) All written in pure C
I am a great fun of C, and I don't want to mess scripts with c codes. :-)

### 3) Better memory management
Indigo does not retain Objective-C objects. When Objective-C runtime no longer
need them, they are dealloced immediately. And what is better is that you now
can overwrite the `dealloc` method, just like an normal method:
```lua
function AView:dealloc()
    print("AView dealloc")
    self.super.dealloc()
end
```
### 4) More reasonable class creation
You can now write a new class or a class extension. To create a new class,
use the `class` keyword:
```lua
class("AView", "UIView", nil)

property{name="title", type="@"}

function AView:initWithFrame_(frame)
  self = self.super.initWithFrame_(frame)
  self.title = "a test view"
  return self
end

function AView:dealloc()
  print("AView dealloc")
  self.super.dealloc()
end

finish()
```
Here I create a class named `AView`, which is a subclass of `UIView`. The
third argument is protocol.
And then I add a property named `title` to this class. Note that add a
property means exactly the same thing when you write a `@property()` in
Objective-C. Indigo create instance variable for it, and make it key-value
compliance.
Note that the `finish()` statement is required because this class will not
be registered in the Objective-C runtime only until you write this statement.

Class extension is much the same:
```lua
--create a category on class AViewController
extension("AViewController", "categoryName")

--instance method
function AViewController:foo()
  print("This is an instance method in category")
end

--class method
function AViewController.class:classFoo_(a)
  print("This is a class method in category param: ", a)
end

finish()
```
Note that class methods and instance methods are different.

### 5) Support multi-threading with GCD
Almost the same as you write Objective-C code:
``` lua
 dispatch_async(dispatch_get_global_queue(0, 0), function()
    print("dispatch_async on global queue ", objcClass("NSThread").currentThread)
 end)
 ```
### 6) Support Objective-c block with an elegant syntax
You pass a lua function as block argument:
``` lua
local arr = objcClass("NSArray").arrayWithObjects_(3,5,7,4,2,1,8,9,6,0)
local sortedArr = arr.sortedArrayUsingComparator_(
    function (num1, num2)
        print("comparing num1: ", num1.asObject.integerValue, " and num2: ", num2.asObject.integerValue)
        return num1.asObject.integerValue>num2.asObject.integerValue
    end
)
```
Because a block has no signature, so we need to translate the parameters
explicitly(calling `asObject`).
One great thing of block is that indigo automatically manages the memory for
the block and its captured external parameters, just like in Objective-C!
You only need to be aware of the retain circles.

### 7) Support inout parameters(partially)
```lua
function AViewController:scrollViewWillEndDragging_withVelocity_targetContentOffset_(scrollView, velocity, targetContentOffset)
  print("velocity.y: ", velocity.y)
  targetContentOffset.y = 60
end
```
### 8) Support Cocoa C functions(partially)
You can run the demo app and click the right button. I create the heart image with
Quartz C API.
