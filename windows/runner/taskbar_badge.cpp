#include "taskbar_badge.h"

#include <shobjidl.h>

#include <cstring>
#include <string>

namespace {

constexpr int kSize = 16;

// Roter Punkt mit weißer Zahl. GDI schreibt keinen Alphakanal: Gezeichnete Pixel werden danach deckend gesetzt,
// der Rest bleibt durchsichtig.
HICON CreateBadgeIcon(int count) {
  HDC screen = GetDC(nullptr);
  HDC dc = CreateCompatibleDC(screen);
  ReleaseDC(nullptr, screen);
  if (!dc) return nullptr;

  BITMAPV5HEADER header{};
  header.bV5Size = sizeof(header);
  header.bV5Width = kSize;
  header.bV5Height = -kSize;
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;
  void* bits = nullptr;
  HBITMAP color = CreateDIBSection(dc, reinterpret_cast<BITMAPINFO*>(&header),
                                   DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!color || !bits) {
    DeleteDC(dc);
    return nullptr;
  }
  std::memset(bits, 0, kSize * kSize * 4);
  HGDIOBJ old_bitmap = SelectObject(dc, color);

  HBRUSH brush = CreateSolidBrush(RGB(185, 28, 28));
  HGDIOBJ old_brush = SelectObject(dc, brush);
  HGDIOBJ old_pen = SelectObject(dc, GetStockObject(NULL_PEN));
  Ellipse(dc, 0, 0, kSize + 1, kSize + 1);

  // „9+“ ist zwei Zeichen breit und berührt bei 11 px den Rand des Kreises (#330): dafür kleiner. Einstellige Zahlen
  // bleiben bei 11 px.
  const int font_height = count > 9 ? -9 : -11;
  HFONT font = CreateFontW(font_height, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, NONANTIALIASED_QUALITY,
                           DEFAULT_PITCH, L"Segoe UI");
  HGDIOBJ old_font = SelectObject(dc, font);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(255, 255, 255));
  std::wstring label = count > 9 ? L"9+" : std::to_wstring(count);
  RECT rect{0, 0, kSize, kSize};
  DrawTextW(dc, label.c_str(), -1, &rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE);
  GdiFlush();

  auto* pixels = static_cast<DWORD*>(bits);
  for (int i = 0; i < kSize * kSize; ++i) {
    if (pixels[i] & 0x00FFFFFF) pixels[i] |= 0xFF000000;
  }

  SelectObject(dc, old_font);
  SelectObject(dc, old_pen);
  SelectObject(dc, old_brush);
  SelectObject(dc, old_bitmap);
  DeleteObject(font);
  DeleteObject(brush);

  HBITMAP mask = CreateBitmap(kSize, kSize, 1, 1, nullptr);
  ICONINFO info{};
  info.fIcon = TRUE;
  info.hbmMask = mask;
  info.hbmColor = color;
  HICON icon = CreateIconIndirect(&info);
  DeleteObject(mask);
  DeleteObject(color);
  DeleteDC(dc);
  return icon;
}

}  // namespace

bool SetTaskbarBadge(HWND hwnd, int count) {
  ITaskbarList3* taskbar = nullptr;
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&taskbar)))) {
    return false;
  }
  bool ok = SUCCEEDED(taskbar->HrInit());
  if (ok) {
    if (count <= 0) {
      ok = SUCCEEDED(taskbar->SetOverlayIcon(hwnd, nullptr, L""));
    } else {
      HICON icon = CreateBadgeIcon(count);
      std::wstring description = std::to_wstring(count);
      ok = icon && SUCCEEDED(taskbar->SetOverlayIcon(hwnd, icon, description.c_str()));
      if (icon) DestroyIcon(icon);
    }
  }
  taskbar->Release();
  return ok;
}
