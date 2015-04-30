module tt.windows.event;

version(Windows):

import std.c.windows.windows;
import std.utf;

extern(System) LRESULT wndProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    try {
        if (window in _listenreTable) {
            auto listeners = _listenreTable[window];
            if (message in listeners) {
                listeners[message](window, message, wParam, lParam);
            }
        }
    } catch (Throwable t) {
        try {
            MessageBoxW(window, t.toString().toUTF16z(), "Error", MB_OK | MB_ICONERROR);
        } catch (Throwable t) {
        }
    }
    return DefWindowProcW(window, message, wParam, lParam);
}

alias EventListener = void delegate(HWND window, UINT message, WPARAM wParam, LPARAM lParam);
private EventListener[UINT][HWND] _listenreTable;

void addEventListener(HWND window, UINT message, EventListener listener) {
    _listenreTable[window][message] = listener;
}

int eventLoop(HWND window) in {
    assert(window);
} body {
    MSG msg;
    while (GetMessageW(&msg, null, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return msg.wParam;
}

