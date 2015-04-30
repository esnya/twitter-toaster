module tt.toaster;

import std.algorithm;
import std.json;
import std.range;
import std.stdio;
import std.string;
import tt.twitter;
import std.process;


auto toast(string title, string message, string image, bool wait = false) {
    auto cmd = ["toaster/toast/bin/Release/toast.exe", "-t", title, "-m", message];

    if (image.length > 0) cmd ~= ["-p", image];
    if (wait) cmd ~= "-w";

    return cmd.spawnProcess();
}
auto toast(alias callback, T...)(string title, string message, string image, T args) {
    import std.parallelism;
    task!((title, message, image, args) => callback(toast(title, message, image, true).wait(), args))(title, message, image, args).executeInNewThread();
}

auto getIcon(string url) {
    import std.file;
    import std.net.curl;
    import std.path;
    import std.digest.sha;

    auto _url = url.replace("_normal", "_bigger");
    auto path = buildPath("icon", hexDigest!SHA1(_url)).setExtension(_url.extension);

    if (!path.exists) {
        _url.download(path);
    }

    return path.absolutePath;
}

void toaster() {
    enum Consumer = Token(cast(string[2])std.string.splitLines(import("consumer.txt"))[0 .. 2]);

    auto request_token = requestToken(Consumer.key, Consumer.secret, "oob").formDecode();

    authenticate(request_token["oauth_token"]);

    write("PIN> ");
    auto pin = readln().chomp();

    auto access_token = accessToken(Consumer.key, Consumer.secret,
            request_token["oauth_token"], request_token["oauth_token_secret"],
            pin).formDecode();

    writeln(access_token);

    auto screen_name = access_token["screen_name"];

    auto profile = oauth("GET", "https://api.twitter.com/1.1/users/show.json", Consumer.key, Consumer.secret, access_token["oauth_token"], access_token["oauth_token_secret"], null, [
            "screen_name": screen_name,
    ]).parseJSON();
    //writeln(profile);

    auto name = profile["name"].str;
    auto profile_image_url = profile["profile_image_url"].str;

    //writeln(profile_image_url);

    toast(name, "Twitter-Toaster is ready!", profile_image_url.getIcon());

    
    while (1) {
        try {
            streaming(Consumer.key, Consumer.secret, access_token["oauth_token"], access_token["oauth_token_secret"]);
        } catch (Throwable t) {
            stderr.writeln(t);
        }
    }
}

auto streaming(string consumer_key, string consumer_secret, string token, string token_secret) {
    import std.net.curl;

    enum url = "https://userstream.twitter.com/1.1/user.json";

    auto signed = sign("GET", url, consumer_secret, token_secret, [
            "oauth_consumer_key": consumer_key,
            "oauth_token": token,
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

                //writeln(line);
                if (!line.empty) {
                    try {
                        auto json = line.parseJSON();
                        if ("text" in json) {
                            json.toastStatus();
                        }
                    } catch (Throwable t) {
                        stderr.writeln(t);
                    }
                }
            }
        } else {
            stderr.write(cast(char[])data);
        }
        return data.length;
    };

    con.perform();
}

auto getStatus(string consumer_key, string consumer_secret, string token, string token_secret, long id) {
    import std.conv;
    return oauth("GET", "https://api.twitter.com/1.1/statuses/show.json",
            consumer_key, consumer_secret,
            token, token_secret, null, [
                "id": id.to!string(),
            ]).parseJSON();
}

auto toastStatus(JSONValue s) {
    import std.conv;
    import std.process;

    auto name = s["user"]["name"].str;
    auto screen_name = s["user"]["screen_name"].str;
    auto title = name ~ '@' ~ screen_name;
    auto message = s["text"].str;
    auto icon = s["user"]["profile_image_url"].str.getIcon();
    writeln("status: [", title, "] ", message);
    toast!((status, url) { if (status == 0) {spawnShell("start " ~ url);}})(title, message, icon, "https://twitter.com/" ~ screen_name ~ "/status/" ~ s["id"].integer.to!string());
}
