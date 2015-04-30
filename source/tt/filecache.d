module tt.filecache;

import std.file;
import std.functional;
import std.traits;

enum OnFailure {
    refresh,
    rethrow,
};

auto cache(alias getter, alias writer, alias reader, OnFailure onFailure = OnFailure.refresh)(in char[] file, ParameterTypeTuple!getter args, bool refresh = false) {
    if (file.exists && !refresh) {
        return file.readText().unaryFun!reader();
    } else {
        try {
            auto data = getter(args);
            file.write(data.unaryFun!writer());
            return data;
        } catch (Throwable t) {
            if (onFailure == OnFailure.refresh) {
                return cache!(getter, writer, reader, onFailure.rethrow)(file, args, true);
            } else {
                throw t;
            }
        }
    }
}
auto cache(alias getter)(in char[] file, ParameterTypeTuple!getter args, bool refresh = false) {
    import std.conv;

    return cache!(getter, (a => a.to!string()), (a => a.to!(ReturnType!getter)))(file, args, refresh);
}
