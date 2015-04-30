module tt.hmac;

import std.digest.digest;

auto hmac(alias T, size_t BlockSize = 512 / 8)(in void[] data, in void[] key) if (isDigest!T) {
    import std.algorithm;
    import std.range;

    auto _key = cast(ubyte[])key;

    if (_key.length > BlockSize) {
        _key = cast(ubyte[])digest!T(_key);
    }

    if (_key.length < BlockSize) {
        _key ~= (cast(ubyte)0).repeat(BlockSize - _key.length).array;
    }

    auto _data = cast(ubyte[])data;

    ubyte[BlockSize] ki, ko;
    ki[] = _key[] ^ 0x36;
    ko[] = _key[] ^ 0x5c;

    return digest!T(ko ~ digest!T(ki ~ _data));
}
unittest {
    import std.digest.sha;
    import std.base64;

    assert(Base64.encode(hmac!SHA1("foobar", "hoge")) == "w2GqrLlU1R00DrBzywwbFfnFkAo=");
    assert(Base64.encode(hmac!SHA1("hogehoge", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")) == "N7eKUxdryKwZfaxwff+P43YdUyU=");
}
