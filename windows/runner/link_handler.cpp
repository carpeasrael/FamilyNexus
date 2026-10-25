#include "link_handler.h"

#include <cstring>

namespace link_handler {

namespace {

constexpr wchar_t kInstanceMutex[] = L"Local\\de.inneso.familynexus.instance";
constexpr wchar_t kWindowClass[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"FamilyNexus";
constexpr wchar_t kSchemeKey[] = L"Software\\Classes\\familynexus";

HANDLE instance_mutex = nullptr;

void SetString(const wchar_t* key, const wchar_t* name, const std::wstring& value) {
  ::RegSetKeyValueW(HKEY_CURRENT_USER, key, name, REG_SZ, value.c_str(),
                    static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}

}  // namespace

bool IsFamilyNexusLink(const std::string& link) {
  return link.rfind("familynexus:", 0) == 0;
}

void RegisterUrlScheme() {
  // Ein Entwicklungslauf unter dem Debugger soll das Schema nicht auf den Debug-Build umbiegen.
  if (::IsDebuggerPresent()) return;
  wchar_t path[MAX_PATH];
  const DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return;
  const std::wstring exe(path, length);
  const std::wstring command = L"\"" + exe + L"\" \"%1\"";
  const std::wstring command_key = std::wstring(kSchemeKey) + L"\\shell\\open\\command";

  wchar_t current[2048];
  DWORD size = sizeof(current);
  if (::RegGetValueW(HKEY_CURRENT_USER, command_key.c_str(), nullptr, RRF_RT_REG_SZ, nullptr, current, &size) ==
          ERROR_SUCCESS &&
      command == current) {
    return;
  }
  SetString(kSchemeKey, nullptr, L"URL:FamilyNexus");
  SetString(kSchemeKey, L"URL Protocol", L"");
  SetString((std::wstring(kSchemeKey) + L"\\DefaultIcon").c_str(), nullptr, L"\"" + exe + L"\",0");
  SetString(command_key.c_str(), nullptr, command);
}

bool ClaimInstance() {
  instance_mutex = ::CreateMutexW(nullptr, FALSE, kInstanceMutex);
  return instance_mutex != nullptr && ::GetLastError() != ERROR_ALREADY_EXISTS;
}

bool ForwardToRunningInstance(const std::string& link) {
  // Die erste Instanz erzeugt ihr Fenster erst kurz nach dem Start: einige Sekunden lang warten.
  HWND window = nullptr;
  for (int attempt = 0; attempt < 20 && window == nullptr; ++attempt) {
    window = ::FindWindowW(kWindowClass, kWindowTitle);
    if (window == nullptr) ::Sleep(250);
  }
  if (window == nullptr) return false;

  if (IsFamilyNexusLink(link) && link.size() < kMaxLinkBytes) {
    COPYDATASTRUCT data;
    data.dwData = kCopyDataId;
    data.cbData = static_cast<DWORD>(link.size() + 1);
    data.lpData = const_cast<char*>(link.c_str());
    DWORD_PTR result = 0;
    if (::SendMessageTimeoutW(window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG, 3000,
                              &result) == 0) {
      return false;
    }
  }
  if (::IsIconic(window)) ::ShowWindow(window, SW_RESTORE);
  ::SetForegroundWindow(window);
  return true;
}

}  // namespace link_handler
