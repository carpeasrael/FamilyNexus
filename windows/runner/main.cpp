#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "link_handler.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Einladungslinks (`familynexus://join?...`) kommen als Argument; nur dieses Schema wird
  // weitergereicht, geprüft wird in Dart. Andere Argumente erreichen Dart nicht.
  std::string initial_link;
  for (const std::string& argument : GetCommandLineArguments()) {
    if (link_handler::IsFamilyNexusLink(argument)) {
      initial_link = argument;
      break;
    }
  }

  // Nur eine Instanz je Sitzung (zwei Programme dürften nicht dieselbe verschlüsselte Datenbank öffnen):
  // Ein Klick auf einen Einladungslink übergibt ihn an die laufende App (E-69).
  if (!link_handler::ClaimInstance() && link_handler::ForwardToRunningInstance(initial_link)) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }
  link_handler::RegisterUrlScheme();

  FlutterWindow window(project, initial_link);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"FamilyNexus", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
