#ifndef RUNNER_TASKBAR_BADGE_H_
#define RUNNER_TASKBAR_BADGE_H_

#include <windows.h>

// Zahl ungelesener Nachrichten als Overlay-Symbol in der Taskleiste (#254, E-88).
// 0 entfernt das Overlay. Ab 10 steht „9+“.
bool SetTaskbarBadge(HWND hwnd, int count);

#endif  // RUNNER_TASKBAR_BADGE_H_
