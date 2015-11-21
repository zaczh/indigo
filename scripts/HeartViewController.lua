--draw a heart
function getHeartImage(size, color)
    probe(color)
    UIGraphicsBeginImageContext(size)
    local context = UIGraphicsGetCurrentContext()

    CGContextTranslateCTM(context, 0.0, size.height)
    CGContextScaleCTM(context, 1.0, -1.0)

    CGContextSetFillColorWithColor(context, color)
    CGContextSetLineWidth(context, 2.0)

    local center = CGPointMake(size.width/2.0, size.height*.675)
    local width = size.width

    CGContextMoveToPoint(context, center.x - width/2, center.y)
    for x_loc=center.x - width/2, center.x + width/2, 0.1 do
        local x = x_loc - center.x
        local y = (width/2*math.abs(x) - x*x)^.5
        CGContextAddLineToPoint(context, x + center.x, y + center.y)
    end
    CGContextAddLineToPoint(context, center.x+ width/2, center.y)

    for x_loc = center.x + width/2, center.x - width/2, -0.1 do
        local x = x_loc - center.x
        local y = -1.25 * (width/2)^0.75 * ((width/2)^.5 - (math.abs(x))^.5)^.5
        CGContextAddLineToPoint(context, x + center.x, y + center.y)
    end
    CGContextAddLineToPoint(context, center.x - width/2, center.y)

    CGContextClosePath(context)
    CGContextFillPath(context)

    local image = UIGraphicsGetImageFromCurrentImageContext()
    return image
end

class("HeartViewController", "UIViewController")
property{name="imageView", type ="@"}
function HeartViewController:dealloc()
    print("HeartViewController dealloc")
    self.super.dealloc()
end

function HeartViewController:viewDidLoad()
    self.super.viewDidLoad()
    self.title = "❤️❤️❤️❤️❤️"

    self.view.backgroundColor = objcClass("UIColor").whiteColor()
    local width = self.view.bounds.size.width
    local size = CGSizeMake(width*.6, width*.8)
    local image = getHeartImage(size, objcClass("UIColor").redColor().CGColor)
    local imageView = objcClass("UIImageView").initWithImage_(image)
    imageView.frame = CGRectMake(width*.2, width*.1, size.width, size.height);
    self.view.addSubview_(imageView)
    self.imageView = imageView

    local animation = objcClass("CABasicAnimation").animationWithKeyPath_("transform")
    animation.duration = 3
    --local transform = CATransform3D
    --animation.toValue = objcClass("NSValue").valueWithCATransform3D
end

function HeartViewController:viewWillLayoutSubviews()
    self.super.viewWillLayoutSubviews()
    local width = self.view.bounds.size.width
    local size = CGSizeMake(width*.6, width*.8)
    self.imageView.frame = CGRectMake(width*.2, width*.1, size.width, size.height);
end

finish()
