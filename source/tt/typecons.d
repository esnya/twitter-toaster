module tt.typecons;

public import std.typecons;

auto tuple(T)(string[string] obj) if (isTuple!T) {
    T tuple;

    foreach (i, ref value; tuple) {
        enum key = tuple.fieldNames[i];
        value = obj[key];
    }

    return tuple;
}
auto tuple(T...)(string[string] values) {
    return tuple!(Tuple!T)(values);
}
auto tuple(T...)(T args) if (!is(T == string[string])){
    return std.typecons.tuple!T(args);
}
auto tuple(T...)() {
    return std.typecons.tuple!T();
}

