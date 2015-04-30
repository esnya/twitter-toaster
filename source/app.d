import tt.toaster;

version (unittest) {
} else {
    version (WindowsDesktop) {
        pragma(msg, "Compiling in Windows GUI mode");
        import core.runtime;
        import std.c.windows.windows;
        import std.parallelism;
        import std.utf;
        import tt.windows.event;
        import tt.windows.menu;
        import tt.windows.notifyicon;
        import tt.windows.window;

        int toasterTray() {
            enum title = "Twitter Toaster"w;

            auto window = createWindow(title);

            void onTray(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
                //if (lParam == WM_RBUTTONDOWN) {
                //    auto menu = createPopupMenu().append("Finish Toasting", 1);
                //    window.popup(menu);
                //}
                if (lParam == WM_LBUTTONDBLCLK) {
                    PostQuitMessage(0);
                }
            }
            window.addEventListener(WM_USER + 1, &onTray);

            //void onCommand(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
            //    if (LOWORD(wParam) == 1) {
            //        PostQuitMessage(0);
            //    }
            //}
            //window.addEventListener(WM_COMMAND, &onCommand);

            auto ni = addNotifyIcon(window, title);
            scope(exit) ni.deleteNotifyIcon();

            return window.eventLoop();
        }

        extern(System) int WinMain(HINSTANCE instance, HINSTANCE, in char*, int) {
            Runtime.initialize();
            scope(exit) Runtime.terminate();

            auto s = new ToasterSwitch;
            scope(exit) s.off();

            task!toaster(s).executeInNewThread();

            return toasterTray();
        }
    } else {
        void main() {
            toaster();
        }
    }
}
