module tt.windows.notifyicon;

version(Windows):

import std.c.windows.windows;

struct GUID {
    DWORD Data1;
    WORD  Data2;
    WORD  Data3;
    BYTE[8] Data4;
}

struct NOTIFYICONDATAW {
    DWORD cbSize;
    HWND  hWnd;
    UINT  uID;
    UINT  uFlags;
    UINT  uCallbackMessage;
    HICON hIcon;
    WCHAR[64] szTip;
    DWORD dwState;
    DWORD dwStateMask;
    WCHAR[256] szInfo;
    union {
        UINT uTimeout;
        UINT uVersion;
    };
    WCHAR[64] szInfoTitle;
    DWORD dwInfoFlags;
    GUID  guidItem;
    HICON hBalloonIcon;
}

enum WM_USER = 0x7FFF;
enum NIM_ADD = 0;
enum NIM_MODIFY = 1;
enum NIM_DELETE = 2;
enum NIF_MESSAGE = 1;
enum NIF_ICON = 2;
enum NIF_TIP = 4;

extern(System) BOOL Shell_NotifyIconW(DWORD dwMessage, in NOTIFYICONDATAW* lpdata); 

auto addNotifyIcon(HWND window, wstring tip, uint message = WM_USER + 1) in {
    assert(tip.length < 63);
} body {
    static uint id;

    auto nid = new NOTIFYICONDATAW;
    nid.cbSize = nid.sizeof;
    nid.hIcon = LoadIconA(null, IDI_APPLICATION);
    nid.hWnd = window;
    nid.szTip[0 .. tip.length][] = tip[];
    nid.uCallbackMessage = message;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uID = ++id;

    auto r = Shell_NotifyIconW(NIM_ADD, nid);
    assert(r);

    return nid;
}

void deleteNotifyIcon(NOTIFYICONDATAW* nid) in {
    assert(nid);
} body {
    auto r = Shell_NotifyIconW(NIM_DELETE, nid);
    assert(r);
    delete nid;
}
