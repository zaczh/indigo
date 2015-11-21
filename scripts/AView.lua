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
