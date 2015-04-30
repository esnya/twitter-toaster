module tt.twitter;

import std.algorithm;
import std.conv;
import std.digest.sha;
import std.net.curl;
import std.range;
import std.typecons;
import std.uri;
import tt.hmac;

//version = OpenBrowser;

alias Token = tuple!(string, "key", string, "secret");

version(unittest) {
    enum Consumer = Token(cast(string[2])std.string.splitLines(import("consumer.txt"))[0 .. 2]);
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

auto oauth(string method, string url, string consumer_key, string consumer_secret, string token, string token_secret, string[string] params = null, string[string] query = null) {
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
auto oauth(string method, string url, string consumer_key, string consumer_secret, string[string] params = null, string[string] query = null) {
    return oauth(method, url, consumer_key, consumer_secret, null, null, params, query);
}

auto requestToken(string consumer_key, string consumer_secret, string callback, string[string] params = null) {
    return oauth("POST", "https://api.twitter.com/oauth/request_token",
            consumer_key, consumer_secret,
            params, ["oauth_callback": callback]);
}
unittest {
    auto request_token = requestToken(Consumer.key, Consumer.secret, "oob").formDecode();
    assert("oauth_token" in request_token);
    assert("oauth_token_secret" in request_token);
    assert(request_token["oauth_callback_confirmed"] == "true");
}

auto authenticate(string token) {
    version (Windows) {
        import std.process;
        auto ret = executeShell("start https://api.twitter.com/oauth/authenticate?oauth_token=" ~ token.encodeComponent());
        if (ret.status != 0) throw new Exception("Failed to open browser");
    } else {
        static assert(0);
    }
}
unittest {
    version (OpenBrowser) {
        auto request_token = requestToken(Consumer.key, Consumer.secret, "oob").formDecode();
        authenticate(request_token["oauth_token"]);
    }
}

auto accessToken(string consumer_key, string consumer_secret, string token, string token_secret, string verifier, string[string] params = null) {
    return oauth("POST", "https://api.twitter.com/oauth/access_token",
            consumer_key, consumer_secret, token, token_secret,
            params, [
                "oauth_verifier": verifier
            ]);

}
unittest {
    version (OpenBrowser) {
        import std.stdio;
        import std.string;

        auto request_token = requestToken(Consumer.key, Consumer.secret, "oob").formDecode();
        authenticate(request_token["oauth_token"]);
        
        write("PIN> ");
        auto pin = readln().chomp();
        auto access_token = accessToken(Consumer.key, Consumer.secret,
                request_token["oauth_token"], request_token["oauth_token_secret"],
                pin).formDecode();
    }

}
