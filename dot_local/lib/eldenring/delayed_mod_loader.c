#define WIN32_LEAN_AND_MEAN
#include <windows.h>

/*
 * Elden Ring delayed runtime DLL loader.
 *
 * ModEngine loads this helper at process initialization. CameraFix scans game
 * code and therefore must not initialize that early; wait until Elden Ring has
 * completed enough startup before loading the game-local DLL mods.
 */

static DWORD WINAPI load_delayed_mods(LPVOID unused) {
    (void)unused;
    Sleep(7000);

    LoadLibraryW(L"Z:\\mnt\\Games\\NonSteamGames\\ELDEN RING\\Game\\mods\\CameraFix.dll");
    LoadLibraryW(L"Z:\\mnt\\Games\\NonSteamGames\\ELDEN RING\\Game\\mods\\PauseTheGame.dll");
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        HANDLE thread = CreateThread(NULL, 0, load_delayed_mods, NULL, 0, NULL);
        if (thread != NULL) {
            CloseHandle(thread);
        }
    }
    return TRUE;
}
