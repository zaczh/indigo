require "CViewController"

class("BViewController", "UIViewController", {"UITableViewDataSource", "UITableViewDelegate", "UIScrollViewDelegate"})

property{name="info", type="@"}
property{name="header", type="@"}
property{name="tableView", type="@"}

function BViewController:initWithInfo_header_(info, header)
    self = self.initWithNibName_bundle_(nil, nil)
    self.info = info
    --probe(info)
    self.header = header
    return self
end

function BViewController:viewWillAppear_(animated)
    self.super.viewWillAppear_(animated)
    local indexPath = self.tableView.indexPathForSelectedRow
    if indexPath ~= nil then
        self.tableView.deselectRowAtIndexPath_animated_(indexPath, true)
    end
end

function BViewController:viewWillLayoutSubviews()
    self.super.viewWillLayoutSubviews()
    self.tableView.frame = self.view.bounds
end

function BViewController:dealloc()
    print("BViewController dealloc called")
    self.super.dealloc()
end

function BViewController:viewDidLoad()
    print("BViewController self.meta = ", tostring(getmetatable(self)))
    self.super.viewDidLoad()
    self.title = self.header
    local v = objcClass("UITableView").initWithFrame_(self.view.bounds)
    v.DataSource = self
    v.Delegate = self
    self.view.addSubview_(v)
    self.tableView = v
end

-- DataSource
-------------
function BViewController:tableView_numberOfRowsInSection_(tableView, section)
  --print("tableView_numberOfRowsInSection_")
   return self.info.count
end

function BViewController:tableView_cellForRowAtIndexPath_(tableView, indexPath)
    local identifier = "cell"
    local cell = tableView.dequeueReusableCellWithIdentifier_(identifier)
    if cell == nil then
    cell = objcClass("UITableViewCell").initWithStyle_reuseIdentifier_(0, identifier)
    end

  --probe(self.info)
  --local data = self.source[indexPath.row + 1]

    cell.textLabel.text = self.info.allKeys.objectAtIndex_(indexPath.row)
    cell.accessoryType = 1

  return cell
end

-- Delegate
-----------
function BViewController:tableView_didSelectRowAtIndexPath_(tableView, indexPath)
   local viewController = objcClass("CViewController").initWithInfo_header_(self.info.allValues.objectAtIndex_(indexPath.row), self.info.allKeys.objectAtIndex_(indexPath.row))
   self.navigationController.pushViewController_animated_(viewController, true)
end

finish()
