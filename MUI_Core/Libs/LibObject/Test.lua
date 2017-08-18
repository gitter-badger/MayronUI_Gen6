local lib = LibStub:GetLibrary("LibObject");

local function HelloWorld_Test1()  
    print("HelloWorld_Test1 Started");

    local HelloWorld = lib:CreateClass("HelloWorld");
    lib:Export(HelloWorld, "Test.Something");

    function HelloWorld:Print(private, msg)
        assert(msg == "My 2nd Message");
        assert(private.secret == "This is a secret!");
    end

    -- problem:
    function HelloWorld:_Constructor(private, msg)
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
    function Child:_Constructor(private)
        private.Dialog = "I am a child!";
    end

    function Parent:_Constructor(private)
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

-- TODO:
-- Test DefineArgs + DefineReturns
-- Test Exporting a namespace (as a list)
-- Test Interfaces

---------------------------------
-- Run Tests:
---------------------------------
HelloWorld_Test1();
Inheritance_Test1();