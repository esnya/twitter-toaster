module tt.toaster;

import std.json;
import std.stdio;
import tt.twitter;
import tt.streaming;
import tt.filecache;
import tt.toast;

auto getIcon(string url) {
    import std.digest.sha;
    import std.file;
    import std.net.curl;
    import std.path;
    import std.string;

    auto _url = url.replace("_normal", "_bigger");
    auto path = buildPath("icon", hexDigest!SHA1(_url)).setExtension(_url.extension);

    if (!path.exists) {
        _url.download(path);
    }

    return path.absolutePath;
}

class ToasterSwitch {
    void off() {
        if (_handler) _handler();
    }

    private void delegate() _handler;
}

void toaster(ToasterSwitch s = null) {
    writeln("Start toasting");

    enum Consumer = Token(cast(string[2])std.string.splitLines(import("consumer.token"))[0 .. 2]);
    auto tokens = cache!((Token a) => a.requestToken("oob").authenticate().accessToken())("data/access.token", Consumer);

    writeln(tokens);

    auto screen_name = tokens.screen_name;

    auto profile = tokens.oauth("GET", "https://api.twitter.com/1.1/users/show.json",
            null, [ "screen_name": screen_name ]).parseJSON();
    //writeln(profile);

    auto name = profile["name"].str;
    auto profile_image_url = profile["profile_image_url"].str;

    //writeln(profile_image_url);

    toast(name, "Twitter-Toaster is ready!", profile_image_url.getIcon());

    bool on = true;
    if (s) s._handler = () { on = false; };
    
    while (on) {
        try {
            foreach (event; tokens.streaming()) {
                if (!on) return;
                if ("text" in event) {
                    event.toastStatus();
                }
            }
        } catch (Throwable t) {
            stderr.writeln(t);
        }
    }
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
    toast!((status, url) { if (status == 0) {browse(url);}})(title, message, icon, "https://twitter.com/" ~ screen_name ~ "/status/" ~ s["id"].integer.to!string());
}
