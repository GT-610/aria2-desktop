#ifndef RUNNER_DESKTOP_PROGRESS_H_
#define RUNNER_DESKTOP_PROGRESS_H_

#include <flutter/flutter_engine.h>
#include <windows.h>

#include <memory>

class DesktopProgress {
 public:
  DesktopProgress(flutter::FlutterEngine* engine, HWND window);
  ~DesktopProgress();

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_DESKTOP_PROGRESS_H_
