local lib = LibStub:GetLibrary("LibObject");

local HelloWorld = lib:CreateClass("HelloWorld");
lib:Export(HelloWorld, "Test.Something");

function HelloWorld:Print(private, msg)
    print(msg);
    print(private.secret);
end

-- problem:
function HelloWorld:_Constructor(private, msg)
    private.secret = "This is a secret!";
    print(msg);
    print("Assert False: " .. tostring((self == HelloWorld)));
end

local instance = HelloWorld("My 1st Message");

instance:Print("My 2nd Message");

local HelloWorld2 = lib:Import("Test.Something.HelloWorld");
print("Assert True: " .. tostring((HelloWorld == HelloWorld2)));