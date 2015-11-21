class("CViewController", "UIViewController", {"UITableViewDataSource", "UITableViewDelegate", "UIScrollViewDelegate"})

property{name="info", type="@"}
property{name="header", type="@"}
property{name="tableView", type="@"}

function CViewController:initWithInfo_header_(info, header)
    self = self.initWithNibName_bundle_(nil, nil)
    self.info = info
    self.header = header
    return self
end

function CViewController:viewWillLayoutSubviews()
    self.super.viewWillLayoutSubviews()
    self.tableView.frame = self.view.bounds
end

function CViewController:dealloc()
    print("CViewController dealloc called")
    self.super.dealloc()
end

function CViewController:viewDidLoad()
    print("CViewController self.meta = ", tostring(getmetatable(self)))
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
function CViewController:tableView_numberOfRowsInSection_(tableView, section)
  --print("tableView_numberOfRowsInSection_")
   return self.info.count
end

function CViewController:tableView_cellForRowAtIndexPath_(tableView, indexPath)
    local identifier = "cell"
    local cell = tableView.dequeueReusableCellWithIdentifier_(identifier)
    if cell == nil then
    cell = objcClass("UITableViewCell").initWithStyle_reuseIdentifier_(0, identifier)
    end

  --probe(self.info)
  --local data = self.source[indexPath.row + 1]

    cell.textLabel.text = self.info.objectAtIndex_(indexPath.row)
  --cell.accessoryType = 0

  return cell
end

-- Delegate
-----------
function CViewController:tableView_didSelectRowAtIndexPath_(tableView, indexPath)
   tableView.deselectRowAtIndexPath_animated_(indexPath, true)
   print("tableView_didSelectRowAtIndexPath_ called")
end

finish()
