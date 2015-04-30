module tt.windows.window;

version(Windows):

import std.c.windows.windows;
import std.utf;
import tt.windows.event;

enum ClassName = "TwitterToasterNotifyIconWindowClass"w;

shared static this() {
    WNDCLASSW wc;
    wc.hIcon = LoadIconA(null, IDI_APPLICATION);
    wc.hInstance = GetModuleHandleW(null);
    wc.lpfnWndProc = &wndProc;
    wc.lpszClassName = ClassName.toUTF16z();
    auto atom = RegisterClassW(&wc);
    assert(atom);
}

auto createWindow(wstring title) out(window) {
    assert(window);
} body {
        return CreateWindowW(ClassName.toUTF16z(), title.toUTF16z(), 0, 0, 0, 0, 0, null, null, GetModuleHandleW(null), null);
}

