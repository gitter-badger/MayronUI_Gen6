local lib = LibStub:GetLibrary("LibObject");

local HelloWorld = lib:CreateClass("Test.HelloWorld");

function HelloWorld:Print(private, msg)
    print(msg);
    print(private.secret);
end

function HelloWorld:_Constructor(private, msg)
    private.secret = "This is a secret!";
    print(msg);
    print("Assert False: " .. (self == HelloWorld));
end

local instance = HelloWorld("My 1st Message");

instance:Print("My 2nd Message");

local HelloWorld2 = lib:ImportClass("Test.HelloWorld")''
print("Assert True: " .. (HelloWorld == HelloWorld2));

-- HelloWorld:Print("hello") -- should be illegal operation