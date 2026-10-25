#include "flutter_window.h"

#include <cstring>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "link_handler.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             const std::string& initial_link)
    : project_(project), initial_link_(initial_link) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  link_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "de.inneso.familynexus/links",
          &flutter::StandardMethodCodec::GetInstance());
  link_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "getInitialLink") {
          if (initial_link_.empty()) {
            result->Success();
          } else {
            result->Success(flutter::EncodableValue(initial_link_));
            initial_link_.clear();
          }
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  link_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      // Link einer zweiten Instanz (Klick auf einen Einladungslink); nur das eigene Schema, begrenzte Länge.
      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (data != nullptr && data->dwData == link_handler::kCopyDataId && data->lpData != nullptr &&
          data->cbData > 0 && data->cbData <= link_handler::kMaxLinkBytes && link_channel_) {
        const char* text = static_cast<const char*>(data->lpData);
        const std::string link(text, strnlen(text, data->cbData));
        if (link_handler::IsFamilyNexusLink(link)) {
          link_channel_->InvokeMethod("onLink", std::make_unique<flutter::EncodableValue>(link));
        }
        return TRUE;
      }
      return FALSE;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
