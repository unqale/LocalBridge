#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetupWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  DragAcceptFiles(GetHandle(), TRUE);

  this->Show();
  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetupWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "localbridge/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HWND hwnd = GetHandle();
        if (!hwnd) {
          result->Success();
          return;
        }
        const std::string& method = call.method_name();
        if (method == "startDrag") {
          ReleaseCapture();
          SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        } else if (method == "minimize") {
          ShowWindow(hwnd, SW_MINIMIZE);
          result->Success();
        } else if (method == "toggleMaximize") {
          if (IsZoomed(hwnd)) {
            ShowWindow(hwnd, SW_RESTORE);
          } else {
            ShowWindow(hwnd, SW_MAXIMIZE);
          }
          result->Success(flutter::EncodableValue(IsZoomed(hwnd) != FALSE));
        } else if (method == "close") {
          PostMessage(hwnd, WM_CLOSE, 0, 0);
          result->Success();
        } else if (method == "isMaximized") {
          result->Success(flutter::EncodableValue(IsZoomed(hwnd) != FALSE));
        } else if (method == "showSystemMenu") {
          HMENU menu = GetSystemMenu(hwnd, FALSE);
          if (menu) {
            POINT pt{};
            GetCursorPos(&pt);
            int cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                                     pt.x, pt.y, 0, hwnd, nullptr);
            if (cmd) {
              PostMessage(hwnd, WM_SYSCOMMAND, cmd, 0);
            }
          }
          result->Success();
        } else if (method == "setDarkFrame") {
          bool dark = true;
          if (const auto* b = std::get_if<bool>(call.arguments())) {
            dark = *b;
          }
          BOOL val = dark ? TRUE : FALSE;
          DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &val,
                                sizeof(val));
          result->Success();
        } else if (method == "getBounds") {
          WINDOWPLACEMENT wp{};
          wp.length = sizeof(wp);
          GetWindowPlacement(hwnd, &wp);
          RECT r = wp.rcNormalPosition;
          flutter::EncodableMap map;
          map[flutter::EncodableValue("x")] =
              flutter::EncodableValue(static_cast<int>(r.left));
          map[flutter::EncodableValue("y")] =
              flutter::EncodableValue(static_cast<int>(r.top));
          map[flutter::EncodableValue("width")] =
              flutter::EncodableValue(static_cast<int>(r.right - r.left));
          map[flutter::EncodableValue("height")] =
              flutter::EncodableValue(static_cast<int>(r.bottom - r.top));
          map[flutter::EncodableValue("maximized")] =
              flutter::EncodableValue(IsZoomed(hwnd) != FALSE);
          result->Success(flutter::EncodableValue(map));
        } else if (method == "setBounds") {
          if (const auto* map =
                  std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto get_int = [&](const char* k, int def) {
              auto it = map->find(flutter::EncodableValue(k));
              if (it != map->end()) {
                if (const auto* v = std::get_if<int>(&it->second)) return *v;
              }
              return def;
            };
            int x = get_int("x", 80);
            int y = get_int("y", 60);
            int w = get_int("width", 1180);
            int h = get_int("height", 760);
            if (w >= 800 && h >= 600) {
              POINT pt = {x + w / 2, y + h / 2};
              HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTONULL);
              if (mon != nullptr) {
                SetWindowPos(hwnd, nullptr, x, y, w, h,
                             SWP_NOZORDER | SWP_NOACTIVATE);
              }
            }
            auto it_max = map->find(flutter::EncodableValue("maximized"));
            if (it_max != map->end()) {
              if (const auto* m = std::get_if<bool>(&it_max->second)) {
                if (*m) ShowWindow(hwnd, SW_MAXIMIZE);
              }
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
  window_channel_.reset();
  flutter_controller_.reset();

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case WM_SIZE:
      if (window_channel_) {
        window_channel_->InvokeMethod(
            "onWindowStateChanged",
            std::make_unique<flutter::EncodableValue>(IsZoomed(hwnd) != FALSE));
      }
      break;
    case WM_DROPFILES: {
      HDROP hdrop = reinterpret_cast<HDROP>(wparam);
      UINT count = DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0);
      flutter::EncodableList paths;
      for (UINT i = 0; i < count; ++i) {
        UINT len = DragQueryFileW(hdrop, i, nullptr, 0);
        if (len > 0) {
          std::wstring wpath(len + 1, L'\0');
          DragQueryFileW(hdrop, i, wpath.data(), len + 1);
          wpath.resize(len);
          int utf8_len = WideCharToMultiByte(
              CP_UTF8, 0, wpath.c_str(), static_cast<int>(wpath.size()),
              nullptr, 0, nullptr, nullptr);
          if (utf8_len > 0) {
            std::string utf8_path(utf8_len, '\0');
            WideCharToMultiByte(CP_UTF8, 0, wpath.c_str(),
                                static_cast<int>(wpath.size()),
                                utf8_path.data(), utf8_len, nullptr, nullptr);
            paths.emplace_back(utf8_path);
          }
        }
      }
      DragFinish(hdrop);
      if (window_channel_ && !paths.empty()) {
        window_channel_->InvokeMethod(
            "onFilesDropped",
            std::make_unique<flutter::EncodableValue>(paths));
      }
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
