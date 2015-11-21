local TestClass = class("TestClass", "IndigoTestObject", nil)

property{name="testProperty", type="@"}

function TestClass : funcThatTakesNoArg()
    print("arg: none")
    self.super:funcThatTakesNoArg()
end

function TestClass : funcThatTakesSelector_(sel)
    print("arg: ", sel)
    return self.super:funcThatTakesSelector_(sel)
end

function TestClass : funcThatTakesCChar_(ch)
    print("arg: ", ch)
    return self.super:funcThatTakesCChar_(ch)
end

function TestClass : funcThatTakesCUnsignedChar_(ch)
    print("arg: ", show(ch))
    return self.super:funcThatTakesCUnsignedChar_(ch)
end

function TestClass : funcThatTakesShort_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesShort_(arg)
end

function TestClass : funcThatTakesUnsignedShort_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesUnsignedShort_(arg)
end

function TestClass : funcThatTakesInt_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesInt_(arg)
end

function TestClass : funcThatTakesLong_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesLong_(arg)
end

function TestClass : funcThatTakesUnsignedInt_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesUnsignedInt_(arg)
end

function TestClass : funcThatTakesDouble_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesDouble_(arg)
end

function TestClass : funcThatTakesFloat_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesFloat_(arg)
end

function TestClass : funcThatTakesUnsignedLong_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesUnsignedLong_(arg)
end

function TestClass : funcThatTakesLongLong_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesLongLong_(arg)
end

function TestClass : funcThatTakesUnsignedLongLong_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesUnsignedLongLong_(arg)
end

function TestClass : funcThatTakesStruct_(arg)
    print("arg: ", arg)
    return self.super:funcThatTakesStruct_(arg)
end

function TestClass : dealloc()
    print("test: dealloc")
    self.super:dealloc()
end

finish()
