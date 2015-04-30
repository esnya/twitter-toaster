module tt.windows.menu;

version(Windows):

import std.c.windows.windows;
import std.utf;

extern(Windows) HMENU CreatePopupMenu();
extern(Windows) BOOL InsertMenuW(
        HMENU hMenu,
        UINT uPosition,
        UINT uFlags,
        UINT_PTR uIDNewItem,
        LPCWSTR lpNewItem);

auto createPopupMenu() out(result) {
    assert(result);
} body {
    return CreatePopupMenu();
}

auto append(HMENU menu, wstring item, uint id) in {
    assert(menu);
} body {
    auto r = InsertMenuW(menu, 0u, 0u, id, item.toUTF16z());
    assert(r);
    return menu;
}

enum TPM_BOTTOMALIGN = 0x00000020;
void popup(HWND window, HMENU menu) in {
    assert(window);
    assert(menu);
} body {
    POINT pt;
    GetCursorPos(&pt);
    TrackPopupMenu(menu, TPM_BOTTOMALIGN, pt.x, pt.y, 0, window, null);
}
