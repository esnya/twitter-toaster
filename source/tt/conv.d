module tt.conv;

public import std.conv;
import std.json;
import std.traits;

auto to(T)(JSONValue json) if (isSomeString!T) {
    return json.str.to!T();
}
auto to(T)(JSONValue json) if (isIntegral!T) {
    return cast(T)json.integer;
}
auto to(T)(JSONValue json) if (isFloatingPoint!T) {
    return cast(T)(json.type == JSON_TYPE.FLOAT ? json.floating : json.integer);
}

auto to(D, S)(S s) if (!is(S == JSONValue)) {
    return std.conv.to!D(s);
}
