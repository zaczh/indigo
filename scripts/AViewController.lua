--local AView = require "AView"
local BViewController = require "BViewController"
local HeartViewController = require "HeartViewController"

class("AViewController", "UIViewController", {"UITableViewDataSource", "UITableViewDelegate", "UIScrollViewDelegate"})

property{name="source", type="@"}
property{name="tableView", type="@"}

function AViewController:initWithNibName_bundle_(nibNameOrNil, nibBundleOrNil)
    print("initWithNibName:bundle called");
    self = self.super.initWithNibName_bundle_(nibNameOrNil, nibBundleOrNil)

    local provincesFilePath = objcClass("NSBundle").mainBundle.pathForResource_ofType_("china_provinces", "json")
    local provincesData = objcClass("NSData").dataWithContentsOfFile_(provincesFilePath)
    local provincesDict = objcClass("NSJSONSerialization").JSONObjectWithData_options_error_(provincesData, 0, nil)

    self.source = provincesDict
    return self
end

function AViewController:dealloc()
    print("AViewController dealloc called")
    self.super.dealloc()
end

function AViewController.class:foo()
    print("This is a class method")
end

function AViewController:viewDidLoad()
    self.super.viewDidLoad()
    --self.source = objcClass("NSArray"):arrayWithObject_("a")
    --self:view().backgroundColor = objcClass("UIColor"):colorWithRed_green_blue_alpha_(213/255.0, 135/255.0, 149/255, 1.0)
    --self:view():setNeedsLayout()
    self.title = "China"
    local v = objcClass("UITableView").initWithFrame_(self.view.bounds)
    --v.backgroundColor = objcClass("UIColor"):greenColor()
    v.DataSource = self
    v.Delegate = self
    self.view.addSubview_(v)
    self.tableView = v

    local rightItem = objcClass("UIBarButtonItem").initWithTitle_style_target_action_("Click!!!❤️", 0, self, "onRightButtonClick_")
    self.navigationItem.rightBarButtonItem = rightItem
end

function AViewController:onRightButtonClick_(sender)
    print("onRightButtonClick_", sender)
    local heartViewController = HeartViewController.init()
    self.navigationController.pushViewController_animated_(heartViewController, true)
end

function AViewController:viewWillAppear_(animated)
    self.super.viewWillAppear_(animated)
    local indexPath = self.tableView.indexPathForSelectedRow
    if indexPath ~= nil then
        self.tableView.deselectRowAtIndexPath_animated_(indexPath, true)
    end
end

function AViewController:viewWillLayoutSubviews()
    self.super.viewWillLayoutSubviews()
    self.tableView.frame = self.view.bounds
end

function AViewController:viewDidAppear_(animated)
    self.super.viewDidAppear_(animated)
    print("AViewController:viewDidAppear_")

    local arr = objcClass("NSArray").arrayWithObjects_(3,5,7,4,2,1,8,9,6,0)
    local sortedArr = arr.sortedArrayUsingComparator_(
        function (num1, num2)
            print("comparing num1: ", num1.asObject.integerValue, " and num2: ", num2.asObject.integerValue)
            return num1.asObject.integerValue>num2.asObject.integerValue
        end
    )

    local dict = objcClass("NSDictionary").dictionaryWithObjectsAndKeys_(3,5,7,4,2,1,8,9,6,0)
    probe(dict)

    --local heartVC = objcClass("HeartViewController").init()

    arr.enumerateObjectsUsingBlock_(
        function(obj, index, stop)
            --print("viewController is ", heartVC)
            --NOTE: block parameters need to be converted explicitly
            if index.asInt == 3 then
                stop.asInoutBool = true
            end
            print("enumerateObjectsUsingBlock_ obj: ", obj.asObject, " index: ", index.asInt, " stop: ", stop.asInoutBool)
        end
    )

    -- objcClass("UIView").animateWithDuration_animations_completion_(2.0,
    --     function()
    --         self.view.backgroundColor = objcClass("UIColor").colorWithRed_green_blue_alpha_(213/255.0, 135/255.0, 149/255, 1.0)
    --     end,
    --     function(finish)
    --         --test block capture and release
    --         print("animation finished: ", finish.asBool, heartVC)
    --     end
    -- )

    -- dispatch_async(dispatch_get_main_queue(), function()
    --     print("dispatch_async on main queue")
    -- end)


    -- dispatch_async(dispatch_get_global_queue(0, 0), function()
    --     print("viewController is ", viewController)
    --     print("dispatch_async on global queue ", objcClass("NSThread").currentThread)
    -- end)

    --when call functions with no arguments, you can use `.` to index the function
    -- self.foo() --same as self:foo()
    --
    self.class.classFoo_(89)
end

-- DataSource
-------------
function AViewController:numberOfSectionsInTableView_(tableView)
  return 1
end

function AViewController:tableView_numberOfRowsInSection_(tableView, section)
  --print("tableView_numberOfRowsInSection_")
  return self.source.count
end

function AViewController:tableView_cellForRowAtIndexPath_(tableView, indexPath)
  local identifier = "cell"
  local cell = tableView.dequeueReusableCellWithIdentifier_(identifier)
  if cell == nil then
    cell = objcClass("UITableViewCell").initWithStyle_reuseIdentifier_(0, identifier)
  end

  --local data = self.source[indexPath.row + 1]
  cell.textLabel.text = self.source.allKeys.objectAtIndex_(indexPath.row)
  cell.accessoryType = 1

  return cell
end

-- Delegate
-----------
function AViewController:tableView_didSelectRowAtIndexPath_(tableView, indexPath)
   local viewController = objcClass("BViewController").initWithInfo_header_(self.source.allValues.objectAtIndex_(indexPath.row), self.source.allKeys.objectAtIndex_(indexPath.row))
   self.navigationController.pushViewController_animated_(viewController, true)
end

function AViewController:scrollViewDidScroll_(scrollView)
  print("scrollViewDidScroll_")
end

function AViewController:scrollViewWillEndDragging_withVelocity_targetContentOffset_(scrollView, velocity, targetContentOffset)
  print("scrollViewWillEndDragging_withVelocity_targetContentOffset_")
  probe(velocity)
  print("velocity.y: ", velocity.y)

  --NOTE: set inout parameters
  --targetContentOffset.y = 60

  --call class methods
  self.class.classFoo_(89)
end

finish()
