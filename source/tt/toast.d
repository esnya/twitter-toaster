module tt.toast;

import std.process;
import std.parallelism;

auto toast(string title, string message, string image, bool wait = false) {
    auto cmd = ["toaster/toast/bin/Release/toast.exe", "-t", title, "-m", message];

    if (image.length > 0) cmd ~= ["-p", image];
    if (wait) cmd ~= "-w";

    return cmd.spawnProcess();
}
auto toast(alias callback, T...)(string title, string message, string image, T args) {
    task!((title, message, image, args) => callback(toast(title, message, image, true).wait(), args))(title, message, image, args).executeInNewThread();
}
