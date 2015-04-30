module tt.streaming;

import std.algorithm;
import std.json;
import std.range;
import tt.twitter;

struct Streaming(T) {
    private this(T tokens) {
        _tokens = tokens;
    }

    private T _tokens;

    int opApply(int delegate(ref JSONValue) dg) {
        import std.net.curl;

        enum url = "https://userstream.twitter.com/1.1/user.json";

        auto signed = sign("GET", url, _tokens.consumer_secret, _tokens.oauth_token_secret, [
                "oauth_consumer_key": _tokens.consumer_key,
                "oauth_token": _tokens.oauth_token,
        ]);

        auto con = oauthHTTP("GET", signed, "userstream.twitter.com");
        con.url = url;
        con.method = HTTP.Method.get;
        con.addRequestHeader("Accept", "*/*");
        con.dataTimeout = core.time.dur!"days"(1);

        ushort code;
        con.onReceiveStatusLine = (HTTP.StatusLine statusLine) {
            code = statusLine.code;
        };

        char[] buf;
        bool first = true;

        con.onReceive = (ubyte[] data) {
            if (code == 200) {
                buf ~= cast(char[])data;
                auto nl = buf.countUntil("\r\n");
                while (nl >= 0) {
                    auto line = buf[0 .. nl];
                    buf.popFrontN(nl + 2);
                    nl = buf.countUntil("\r\n");

                    if (!line.empty) {
                        try {
                            auto json = line.parseJSON();

                            auto result = dg(json);
                            if (result) return result;
                        } catch (Throwable t) {
                            //stderr.writeln(t);
                        }
                    }
                }
            } else {
                //stderr.write(cast(char[])data);
            }
            return data.length;
        };

        con.perform();

        return 0;
    }
}

auto streaming(T)(T tokens) {
    return Streaming!T(tokens);
}
