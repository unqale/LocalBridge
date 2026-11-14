#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include <algorithm>

#include "resource.h"

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  const wchar_t* GetWindowClass();
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;
  static WindowClassRegistrar* instance_;
  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon = static_cast<HICON>(
        LoadImage(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON),
                  IMAGE_ICON, GetSystemMetrics(SM_CXICON),
                  GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR));
    window_class.hbrBackground = CreateSolidBrush(RGB(7, 8, 20));
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }
  const RECT& work = monitor_info.rcWork;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;
  const int width = std::min(Scale(size.width, scale_factor), work_width);
  const int height = std::min(Scale(size.height, scale_factor), work_height);

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      work.left + (work_width - width) / 2,
      work.top + (work_height - height) / 2,
      width, height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  HINSTANCE hInstance = GetModuleHandle(nullptr);
  HICON big_icon = static_cast<HICON>(
      LoadImage(hInstance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON),
                LR_DEFAULTCOLOR));
  HICON small_icon = static_cast<HICON>(
      LoadImage(hInstance, MAKEINTRESOURCE(IDI_APP_ICON), IMAGE_ICON,
                GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
                LR_DEFAULTCOLOR));
  if (big_icon) {
    SendMessage(window, WM_SETICON, ICON_BIG,
                reinterpret_cast<LPARAM>(big_icon));
  }
  if (small_icon) {
    SendMessage(window, WM_SETICON, ICON_SMALL,
                reinterpret_cast<LPARAM>(small_icon));
  }

  UpdateTheme(window);
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_NCCALCSIZE: {
      if (wparam == TRUE) {
        auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        if (IsZoomed(hwnd)) {
          const UINT dpi = GetDpiForWindow(hwnd);
          const int padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
          const int frame_x = GetSystemMetricsForDpi(SM_CXFRAME, dpi) + padding;
          const int frame_y = GetSystemMetricsForDpi(SM_CYFRAME, dpi) + padding;
          params->rgrc[0].left += frame_x;
          params->rgrc[0].top += frame_y;
          params->rgrc[0].right -= frame_x;
          params->rgrc[0].bottom -= frame_y;
        }
        return 0;
      }
      break;
    }

    case WM_NCHITTEST: {
      if (IsZoomed(hwnd)) {
        return HTCLIENT;
      }
      POINT pt = { static_cast<short>(LOWORD(lparam)),
                   static_cast<short>(HIWORD(lparam)) };
      ScreenToClient(hwnd, &pt);
      RECT rc{};
      GetClientRect(hwnd, &rc);
      HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
      int border = Scale(6, dpi / 96.0);

      bool left = pt.x < border;
      bool right = pt.x >= rc.right - border;
      bool top = pt.y < border;
      bool bottom = pt.y >= rc.bottom - border;

      if (top && left) return HTTOPLEFT;
      if (top && right) return HTTOPRIGHT;
      if (bottom && left) return HTBOTTOMLEFT;
      if (bottom && right) return HTBOTTOMRIGHT;
      if (left) return HTLEFT;
      if (right) return HTRIGHT;
      if (top) return HTTOP;
      if (bottom) return HTBOTTOM;
      return HTCLIENT;
    }

    case WM_GETMINMAXINFO: {
      auto* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
      double scale = dpi / 96.0;
      mmi->ptMinTrackSize.x = Scale(800, scale);
      mmi->ptMinTrackSize.y = Scale(600, scale);
      return 0;
    }

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

void Win32Window::UpdateTheme(HWND const window) {
  BOOL enable_dark_mode = TRUE;
  DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                        &enable_dark_mode, sizeof(enable_dark_mode));
  COLORREF caption_color = RGB(8, 9, 12);
  DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR,
                        &caption_color, sizeof(caption_color));
  COLORREF border_color = RGB(34, 38, 49);
  DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR,
                        &border_color, sizeof(border_color));
  DWORD corner_pref = 2;  // DWMWCP_ROUND
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_pref, sizeof(corner_pref));
  MARGINS margins = {0, 0, 1, 0};
  DwmExtendFrameIntoClientArea(window, &margins);
}
