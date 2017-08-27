local _, Core = ...;

local lib = LibStub:GetLibrary("LibObjectLua");

local function HelloWorld_Test1()  
    print("HelloWorld_Test1 Started");

    local TestPackage = lib:CreatePackage("HelloWorld_Test1", "Test");

    local HelloWorld = TestPackage:CreateClass("HelloWorld");

    function HelloWorld:Print(private, msg)
        assert(msg == "My 2nd Message");
        assert(private.secret == "This is a secret!");
    end

    function HelloWorld:__Construct(private, msg)
        private.secret = "This is a secret!";
        assert(msg == "My 1st Message");
        assert(self ~= HelloWorld);
    end

    function HelloWorld:__Destruct(private, msg)
        --print("Instance Destroyed"); -- works!
    end

    local instance = HelloWorld("My 1st Message");
    instance:Print("My 2nd Message");

    local HelloWorld2 = lib:Import("Test.HelloWorld_Test1.HelloWorld");
    assert(HelloWorld == HelloWorld2);

    local className = instance:GetObjectType();
    assert(className == "HelloWorld", className);

    instance:Destroy();

    print("HelloWorld_Test1 Successful!");
end

local function Inheritance_Test1()  
    print("Inheritance_Test1 Started");

    local TestPackage = lib:CreatePackage("Inheritance_Test1", "Test");

    local Parent = TestPackage:CreateClass("Parent"); 

    --local Child = TestPackage:CreateClass("Child", "Parent"); -- invalid namespace (it's not been exported as expected!)
    local Child = TestPackage:CreateClass("Child", Parent); -- this works (as expected) - doesn't need exporting first

    function Parent.Static:Move()
        print("moving");
    end

    function Parent:Talk(private)
        assert(private.Dialog == "I am a child!");
    end

    -- never gets called
    function Child:__Construct(private)
        private.Dialog = "I am a child!";
    end

    function Parent:__Construct(private)
        private.Dialog = "I am a parent.";
    end

    local child = Child();

    assert(child:GetObjectType() == "Child");

    assert(child:IsObjectType("Child"));
    assert(child:IsObjectType("Parent"));

    local child2 = child:Clone();
    assert(child:Equals(child2));

    child:Talk();

    child:Destroy();

    print("Inheritance_Test1 Successful!");
end

function DefineParams_Test1()
    print("DefineParams_Test1 Started");

    local TestPackage = lib:CreatePackage("DefineParams_Test1", "Test");

    local Player = TestPackage:CreateClass("Player");

    TestPackage:DefineParams("string", "?number");
    function Player:GetSpellCasting(private, spellName, spellType)
        spellType = spellType or 0;
    end

    local p = Player();

    p:GetSpellCasting("Bloodlust"); -- should work!    
    p:GetSpellCasting("Flame Shock", 123); -- should work!
    
    lib:SetSilentErrors(true);

    p:GetSpellCasting(123); -- should fail as not a string!
    assert(lib:GetNumErrors() == 1);

    p:GetSpellCasting("Flame Shock", "123"); -- should fail as not a number!  
    assert(lib:GetNumErrors() == 2);     

    lib:FlushErrorLog();
    lib:SetSilentErrors(false);

    print("DefineParams_Test1 Successful!");
end

function DefineReturns_Test1()
    print("DefineReturns_Test1 Started");

    local TestPackage = lib:CreatePackage("DefineReturns_Test1", "Test");

    local Player = TestPackage:CreateClass("Player");

    TestPackage:DefineReturns("string", "?number");
    function Player:Func1(private)        
        return "Success!";
    end

    TestPackage:DefineReturns("string", "?number");
    function Player:Func2(private)        
        return "Success!", 123;
    end

    TestPackage:DefineReturns("string", "?number");
    function Player:Func3(private)        
        return 123;
    end

    TestPackage:DefineReturns("string", "?number");
    function Player:Func4(private)        
        return "Fail", "123";
    end

    local p = Player();

    p:Func1();
    p:Func2();

    lib:SetSilentErrors(true);

    p:Func3(); -- should fail!
    p:Func4(); -- should fail!

    assert(lib:GetNumErrors() == 2);

    lib:FlushErrorLog();
    lib:SetSilentErrors(false);

    print("DefineReturns_Test1 Successful!");
end

function ImportPackage_Test1()
    print("ImportPackage_Test1 Started");

    local TestPackage = lib:CreatePackage("ImportPackage_Test1");
    lib:Export("Test", TestPackage); -- same as: lib:CreatePackage("ImportPackage_Test1", "Test");
    
    local CheckButton   = TestPackage:CreateClass("CheckButton");
    local Button        = TestPackage:CreateClass("Button");
    local Slider        = TestPackage:CreateClass("Slider");
    local TextArea      = TestPackage:CreateClass("TextArea");
    local FontString    = TestPackage:CreateClass("FontString");
    local Animator      = TestPackage:CreateClass("Animator");

    assert(TestPackage:Size() == 6);

    local CheckButton2 = lib:Import("Test.ImportPackage_Test1.CheckButton");

    assert(CheckButton == CheckButton2);

    local importedPackage = lib:Import("Test.ImportPackage_Test1");

    assert(importedPackage == TestPackage);
    assert(importedPackage:Size() == 6);

    -- packageMap:ForEach(function(className, _) print(className) end); -- works!

    local CheckButton3 = importedPackage:Get("CheckButton");

    assert(CheckButton == CheckButton3);

    print("ImportPackage_Test1 Successful!");
end

function DuplicateClass_Test1()
    print("DuplicateClass_Test1 Started");

    local TestPackage = lib:CreatePackage("DuplicateClass_Test1");

    lib:SetSilentErrors(true);

    local p = TestPackage:CreateClass("Player");
    local p2 = TestPackage:CreateClass("Player");

    assert(lib:GetNumErrors() == 1);
    lib:FlushErrorLog();
    lib:SetSilentErrors(false);

    print("DuplicateClass_Test1 Successful!");
end

function Interfaces_Test1()
    print("Interfaces_Test1 Started");

    local TestPackage = lib:CreatePackage("Interfaces_Test1");

    local IComparable = TestPackage:CreateInterface("IComparable");

    TestPackage:DefineParams("number", "number");
    TestPackage:DefineReturns("boolean");
    function IComparable:Compare(a, b) end

    local Item = TestPackage:CreateClass("Item", nil, IComparable);

    TestPackage:Implements("Compare");
    function Item:Compare(private, a, b)
        return a < b;
    end

    local item1 = Item();
    assert(item1:Compare(19, 20));

    assert(item1:GetObjectType() == "Item");
    assert(item1:IsObjectType("Item")); 
    assert(item1:IsObjectType("IComparable"));

    print("Interfaces_Test1 Successful!");
end

function Interfaces_Test2()
    print("Interfaces_Test2 Started");

    local TestPackage = lib:CreatePackage("Interfaces_Test2");

    local ICell = TestPackage:CreateInterface("ICell");

    function ICell:Create() end
    function ICell:Update() end
    function ICell:Destroy() end

    --local IPanel = TestPackage:CreateInterface("IPanel");
    --function IPanel:Create() end -- not allowed (works!)

    --local Panel = TestPackage:CreateClass("Panel", nil, IPanel, ICell);

    local Panel = TestPackage:CreateClass("Panel", nil, ICell);

    --TestPackage:DefineParams("string")
    TestPackage:Implements("Create");
    function Panel:Create(a) end

    TestPackage:Implements("Destroy");
    function Panel:Destroy(a) end

    TestPackage:Implements("Update");
    function Panel:Update(a) end

    -- local p = Panel();
    -- p:Create(12);

    print("Interfaces_Test2 Successful!");
end

function DefineParams_Test2()
	print("DefineParams_Test2 Started");

    local TestPackage = lib:CreatePackage("DefineParams_Test2");

    local IHandler = TestPackage:CreateInterface("IHandler");

    TestPackage:DefineReturns("string");
    function IHandler:Run() end

    local OnClickHandler = TestPackage:CreateClass("OnClickHandler", nil, IHandler);

    TestPackage:Implements("Run");
    function OnClickHandler:Run()
        return "Success!";
    end

    local CheckButton = TestPackage:CreateClass("CheckButton");

    TestPackage:DefineParams("IHandler");
    function CheckButton:Execute(data, handler)        
        return handler:Run();
    end

    local onclick = OnClickHandler();
    local cb = CheckButton();

    assert(cb:Execute(onclick) == "Success!");

	print("DefineParams_Test2 Successful!");
end

function Inheritance_Test2()
	print("Inheritance_Test2 Started");
    local TestPackage = lib:CreatePackage("Inheritance_Test2");

    local IInterface = TestPackage:CreateInterface("IInterface");

    TestPackage:DefineParams("string");
    TestPackage:DefineReturns("number");
    function IInterface:Run() end

    local SuperParent = TestPackage:CreateClass("SuperParent", nil, IInterface);

    TestPackage:Implements("Run");
    function SuperParent:Run(a)
        return 123;
    end

    local Parent = TestPackage:CreateClass("Parent", SuperParent);
    local Child = TestPackage:CreateClass("Child", Parent);
    local SuperChild = TestPackage:CreateClass("SuperChild", Child);

    local instance = SuperChild();
    instance:Run("hello");

	print("Inheritance_Test2 Successful!");
end

function UsingParent_Test1()
	print("UsingParent_Test1 Started");
    local TestPackage = lib:CreatePackage("UsingParent_Test1");

    local SuperParent = TestPackage:CreateClass("SuperParent");
    local Parent = TestPackage:CreateClass("Parent", SuperParent);
    local Child = TestPackage:CreateClass("Child", Parent);
    local SuperChild = TestPackage:CreateClass("SuperChild", Child);

    function SuperParent:Print(data)
        --assert(data.origin == "SuperChild");
        return "This is SuperParent!";
    end

    function Parent:Print(data)
        return "This is Parent!";
    end

    function Child:Print(data)
        return "This is Child!";
    end

    function SuperChild:Print(data)
        return "This is SuperChild!";
    end

    function SuperChild:__Construct(data)
        data.origin = "SuperChild";
    end

    local instance = SuperChild();
    instance:Parent():Parent():Parent():Print();

    assert(instance:Print() == "This is SuperChild!");
    assert(instance:Parent():Print() == "This is Child!");
    assert(instance:Parent():Parent():Print() == "This is Parent!");
    assert(instance:Parent():Parent():Parent():Print() == "This is SuperParent!");

    -- print(SuperChild:Print()) -- fails as expected

	print("UsingParent_Test1 Successful!");
end

---------------------------------
-- Run Tests:
---------------------------------
HelloWorld_Test1();
Inheritance_Test1();
DefineParams_Test1();
DefineReturns_Test1();
ImportPackage_Test1();
DuplicateClass_Test1();
Interfaces_Test1();
Interfaces_Test2();
DefineParams_Test2();
Inheritance_Test2();
UsingParent_Test1();