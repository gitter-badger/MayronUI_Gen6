local lib = LibStub:GetLibrary("LibObject");

local function HelloWorld_Test1()  
    print("HelloWorld_Test1 Started");

    local HelloWorld = lib:CreateClass("HelloWorld");
    lib:Export("Test.Something", HelloWorld);

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
        private.secret = "This is a secret!";
        assert(msg == "My 1st Message");
        assert(self ~= HelloWorld);
    end

    local instance = HelloWorld("My 1st Message");
    instance:Print("My 2nd Message");

    local HelloWorld2 = lib:Import("Test.Something.HelloWorld");
    assert(HelloWorld == HelloWorld2);

    local className = instance:GetObjectType();
    assert(className == "HelloWorld", className);

    print("HelloWorld_Test1 Successful!");
end

local function Inheritance_Test1()  
    print("Inheritance_Test1 Started");

    local Parent = lib:CreateClass("Parent"); 
    -- local Child = lib:CreateClass("Child", "Parent"); -- invalid namespace (it's not been exported as expected!)
    local Child = lib:CreateClass("Child", Parent); -- this works (as expected) - doesn't need exporting first

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

    local Player = lib:CreateClass("Player");

    lib:DefineParams("string", "?number");
    function Player:GetSpellCasting(private, spellName, spellType)
        spellType = spellType or 0;

        print(spellName);
    end

    local p = Player();
    
    lib:SetSilentErrors(true);

    p:GetSpellCasting("Bloodlust"); -- should work!
    p:GetSpellCasting(123); -- should fail as not a string!
    p:GetSpellCasting("Flame Shock", 123); -- should work!
    p:GetSpellCasting("Flame Shock", "123"); -- should fail as not a number!

    assert(lib:GetErrorLog());
    lib:SetSilentErrors(false);

    print("DefineParams_Test1 Successful!");
end

function DefineReturns_Test1()
    print("DefineReturns_Test1 Started");

    local Player = lib:CreateClass("Player");

    lib:DefineReturns("string", "?number");
    function Player:Func1(private)        
        return "Success!";
    end

    lib:DefineReturns("string", "?number");
    function Player:Func2(private)        
        return "Success!", 123;
    end

    lib:DefineReturns("string", "?number");
    function Player:Func3(private)        
        return 123;
    end

    lib:DefineReturns("string", "?number");
    function Player:Func4(private)        
        return "Fail", "123";
    end

    local p = Player();

    p:Func1();

    p:Func2();

    lib:SetSilentErrors(true);

    p:Func3(); -- should fail!
    p:Func4(); -- should fail!

    assert(lib:GetErrorLog());
    lib:SetSilentErrors(false);

    print("DefineReturns_Test1 Successful!");
end

function ExportNamespace_Test1()
    print("ExportNamespace_Test1 Started");

    local CheckButton = lib:CreateClass("CheckButton");
    local Button = lib:CreateClass("Button");
    local Slider = lib:CreateClass("Slider");
    local TextArea = lib:CreateClass("TextArea");
    local FontString = lib:CreateClass("FontString");
    local Animator = lib:CreateClass("Animator");

    lib:Export("Framework.GUI.Widgets", 
        CheckButton, 
        Button, 
        Slider,
        TextArea,
        FontString,
        Animator
    );

    local CheckButton2 = lib:Import("Framework.GUI.Widgets.CheckButton");

    assert(CheckButton == CheckButton2);

    local packageMap = lib:Import("Framework.GUI.Widgets.*");

    print(packageMap:Size());

    packageMap:ForEach(function(className, _) print(className) end);

    local CheckButton3 = packageMap:Get("CheckButton");

    assert(CheckButton == CheckButton3);

    print("ExportNamespace_Test1 Successful!");
end

function DuplicateClass_Test1()
    print("DuplicateClass_Test1 Started");
    lib:SetSilentErrors(true);

    local p = lib:CreateClass("Player");
    local p2 = lib:CreateClass("Player");

    lib:Export("TestArea", p);
    lib:Export("TestArea", p2); 

    assert(lib:GetErrorLog());
    lib:SetSilentErrors(false);
    print("DuplicateClass_Test1 Successful!");
end

function ImplementInterface_Test1()
    print("ImplementInterface_Test1 Started");
    print("ImplementInterface_Test1 Successful!");
end

---------------------------------
-- Run Tests:
---------------------------------
HelloWorld_Test1();
Inheritance_Test1();
DefineParams_Test1();
DefineReturns_Test1();
ExportNamespace_Test1();
DuplicateClass_Test1();
-- ImplementInterface_Test1();