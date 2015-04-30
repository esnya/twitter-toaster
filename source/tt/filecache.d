module tt.filecache;

import std.file;
import std.functional;
import std.traits;
import std.typecons;

enum OnFailure {
    refresh,
    rethrow,
};

auto cache(alias getter, alias writer, alias reader, OnFailure onFailure = OnFailure.refresh)(in char[] file, ParameterTypeTuple!getter args, bool refresh = false) {
    if (file.exists && !refresh) {
        try {
            return file.readText().unaryFun!reader();
        } catch (Throwable t) {
            if (onFailure == OnFailure.refresh) {
                return cache!(getter, writer, reader, onFailure.rethrow)(file, args, true);
            } else {
                throw t;
            }
        }
    } else {
        auto data = getter(args);
        file.write(data.unaryFun!writer());
        return data;
    }
}

template Converter(T) if (!isTuple!T) {
    import std.conv;
    auto writer(T a) {
        return a.to!string();
    }
    auto reader(in char[] a) {
        return a.to!T();
    }
}
template Converter(T) if (isTuple!T) {
    import std.json;
    import tt.conv;

    auto writer(T data) {
        JSONValue[string] obj;
        
        foreach (i, value; data) {
            obj[T.fieldNames[i]] = JSONValue(value);
        }

        return JSONValue(obj).toString();
    }
    auto reader(in char[] a) {
        auto obj = a.parseJSON().object;

        T data;
        foreach (i, ref value; data) {
            value = obj[T.fieldNames[i]].to!(typeof(value))();
        }

        return data;
    }
}

auto cache(alias getter)(in char[] file, ParameterTypeTuple!getter args, bool refresh = false) {
    alias DataType = ReturnType!getter;
    alias C = Converter!DataType;

    return cache!(getter, C.writer, C.reader)(file, args, refresh);
}
