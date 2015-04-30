import tt.toaster;

version (WindowsDesktop) {
    pragma(msg, "Compiling in Windows GUI mode");
    import std.c.windows.windows;
    import core.runtime;

    extern(System) int WinMain(HINSTANCE, HINSTANCE, in char*, int) {
        Runtime.initialize();
        scope(exit) Runtime.terminate();

        toaster();

        return 0;
    }
} else {
    void main() {
        toaster();
    }
}
