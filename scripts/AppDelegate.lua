require "AViewController"

--begin a new class creation context
class("MyAppDelegate", "NSObject", {"UIApplicationDelegate"})

--NOTE: add property
property{name="window", type="@"}

function MyAppDelegate:application_didFinishLaunchingWithOptions_(application, launchOptions)
    local frame = objcClass("UIScreen").mainScreen.bounds
    self.window = objcClass("UIWindow").initWithFrame_(frame)
    self.window.backgroundColor = objcClass("UIColor").yellowColor()
    local viewController = objcClass("AViewController").initWithNibName_bundle_(nil, nil)
    --NOTE: using `probe` to debug lua userdata
    --probe(viewController)
    local navigationController = objcClass("UINavigationController").initWithRootViewController_(viewController)
    --probe(navigationController)

    self.window.rootViewController = navigationController
    self.window.makeKeyAndVisible()
    return true
end


--NOTE: never forget to finish a class creation context!!!
finish()


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
