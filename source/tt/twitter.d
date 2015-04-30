module tt.twitter;

import std.algorithm;
import std.conv;
import std.digest.sha;
import std.net.curl;
import std.range;
import tt.typecons;
import std.uri;
import tt.hmac;

//version = OpenBrowser;

alias Token = Tuple!(string, "key", string, "secret");

version(unittest) {
    enum Consumer = Token(cast(string[2])std.string.splitLines(import("consumer.token"))[0 .. 2]);
}

auto timestamp(S = string)() {
    import std.datetime;

    return Clock.currTime().toUnixTime().to!S();
}

auto nonce() {
    import std.random;
    return hexDigest!SHA1([uniform!int()]).idup;
}

auto oauthJoin(G)(string[string] params, G glue, bool quote = false) {
    auto keys = params.keys;
    keys.sort();

    return keys.map!(key =>
            key ~ "=" ~ (quote ? `"` : "") ~ params[key].encodeComponent() ~ (quote ? `"` : ""))()
        .join(glue);
}

auto formEncode(string[string] params) {
    return oauthJoin(params, '&');
}

auto formDecode(in char[] encoded) {
    string[string] decoded;

    encoded.split('&').map!(a => a.split('='))().each!(a => decoded[cast(string)a[0]] = cast(string)a[1])();

    return decoded;
}

auto sign(string method, string url, string consumer_secret, string token_secret, string[string] params, string[string] query = null) {
    import std.base64;

    if ("oauth_version" !in params) params["oauth_version"] = "1.0";

    if ("oauth_timestamp" !in params) params["oauth_timestamp"] = timestamp;
    if ("oauth_nonce" !in params) params["oauth_nonce"] = nonce;

    params["oauth_signature_method"] = "HMAC-SHA1";

    string[string] _params;
    params.keys.each!(key => _params[key] = params[key])();
    query.keys.each!(key => _params[key] = query[key])();

    auto signature_key = [consumer_secret, token_secret].map!encodeComponent().join('&');

    auto signature_data = [method, url, _params.oauthJoin('&')].map!encodeComponent().join('&');

    params["oauth_signature"] = Base64.encode(hmac!SHA1(signature_data, signature_key));

    return params;
}

unittest {
    auto params = sign("POST", "https://api.twitter.com/oauth/request_token", Consumer.secret, "", [
            "oauth_consumer_key": Consumer.key,
    ], [
            "oauth_callback": "oob",
    ]);
    assert("oauth_signature" in params);
    assert(params["oauth_signature_method"] == "HMAC-SHA1");
}

auto oauthHTTP(string method, string[string] signed, string host = "api.twitter.com") {
    auto con = HTTP(host);
    version (Windows) con.caInfo("curl-ca-bundle.crt");
    con.addRequestHeader("Authorization", "OAuth " ~ signed.oauthJoin(", ", true));
    if (method == "POST") con.addRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    con.addRequestHeader("Accept", "*/*");
    return con;
}

auto oauth(string consumer_key, string consumer_secret, string token, string token_secret, string method, string url, string[string] params = null, string[string] query = null) {
    import std.string;

    params["oauth_consumer_key"] = consumer_key;
    if (token.length > 0) params["oauth_token"] = token;

    auto signed = sign(method, url, consumer_secret, token_secret, params, query);

    auto con = oauthHTTP(method, signed);

    import std.stdio;
    switch (method) {
        case "GET":
            writeln("GET ", query ? (url ~ '?' ~ query.formEncode()) : url);
            return get(query ? (url ~ '?' ~ query.formEncode()) : url, con);
        case "POST":
            writeln("POST ", url);
            return post(url, query.formEncode(), con);
        default:
            assert(0);
    }
}
auto oauth(string consumer_key, string consumer_secret, string method, string url, string[string] params = null, string[string] query = null) {
    return oauth(consumer_key, consumer_secret, null, null, method, url, params, query);
}
auto oauth(T)(T tokens, string method, string url, string[string] params = null, string[string] query = null) if (isTuple!T) {
    static if (tokens.length < 4) {
        return oauth(tokens[0 .. 2], method, url, params, query);
    } else {
        return oauth(tokens[0 .. 4], method, url, params, query);
    }
}

auto requestToken(string consumer_key, string consumer_secret, string callback, string[string] params = null) {
    return oauth(consumer_key, consumer_secret,
            "POST", "https://api.twitter.com/oauth/request_token",
            params, ["oauth_callback": callback]).formDecode()
        .tuple!(string, "oauth_token",
                string, "oauth_token_secret")();
}
auto requestToken(T)(T consumer, string callback, string[string] params = null) if (isTuple!T) {
    return Tuple!(
            string, "consumer_key",
            string, "consumer_secret",
            string, "oauth_token",
            string, "oauth_token_secret",
            )(consumer.expand, requestToken(consumer[0 .. 2], callback, params).expand);
}
unittest {
    auto request_token = Consumer.requestToken("oob");
    assert(request_token[0 .. 2] == Consumer[0 .. 2]);
    assert(request_token.oauth_token);
    assert(request_token.oauth_token_secret);
    //assert(request_token.oauth_callback_confirmed == "true");
}

auto authenticate(string token) {
    import std.process;
    browse("https://api.twitter.com/oauth/authenticate?oauth_token=" ~ token.encodeComponent());
}
auto authenticate(T)(T tokens) if (isTuple!T) {
    authenticate(tokens.oauth_token);
    return tokens;
}
//unittest {
//    version (OpenBrowser) {
//        auto request_token = requestToken(Consumer.key, Consumer.secret, "oob").formDecode();
//        authenticate(request_token["oauth_token"]);
//    }
//}

version (WindowsDesktop) {
    auto readPIN() {
        import std.c.windows.windows;

        AllocConsole();
        scope(exit) FreeConsole();

        uint n;
        WriteConsoleA(GetStdHandle(STD_OUTPUT_HANDLE), "PIN> ".ptr, 5, &n, null);

        char[7] pin;
        ReadConsoleA(GetStdHandle(STD_INPUT_HANDLE), pin.ptr, 7, &n, null);
        return pin.idup;
    }
} else {
    auto readPIN() {
        import std.stdio;
        import std.string;

        write("PIN> ");
        return readln().chomp();
    }
}

auto accessToken(string consumer_key, string consumer_secret, string token, string token_secret, string verifier = null, string[string] params = null) {

    return oauth(consumer_key, consumer_secret, token, token_secret,
            "POST", "https://api.twitter.com/oauth/access_token",
            params, [
                "oauth_verifier": verifier ? verifier : readPIN(),
            ])
        .formDecode()
        .tuple!(string, "oauth_token",
                string, "oauth_token_secret",
                string, "screen_name")();

}
auto accessToken(T)(T tokens, string verifier = null, string[string] params = null) if (isTuple!T) {
    return Tuple!(string, "consumer_key",
            string, "consumer_secret",
            string, "oauth_token",
            string, "oauth_token_secret",
            string, "screen_name")(tokens[0 .. 2],
                accessToken(tokens[0 .. 4], verifier, params).expand);
}
unittest {
    version (OpenBrowser) {
        auto access_token = Consumer.requestToken("oob")
            .authenticate()
            .accessToken();

        std.stdio.writeln(access_token);
    }
}
