#include "desktop_progress.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <cmath>
#include <memory>
#include <optional>

namespace {

std::optional<double> GetProgressArgument(
    const flutter::EncodableValue* arguments) {
  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (args == nullptr) {
    return std::nullopt;
  }
  const auto iterator = args->find(flutter::EncodableValue("progress"));
  if (iterator == args->end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<double>(&iterator->second)) {
    return std::isfinite(*value) ? std::optional<double>(*value)
                                 : std::nullopt;
  }
  return std::nullopt;
}

}  // namespace

class DesktopProgress::Impl {
 public:
  Impl(flutter::FlutterEngine* engine, HWND window) : window_(window) {
    const HRESULT created =
        CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                         IID_PPV_ARGS(&taskbar_));
    if (SUCCEEDED(created) && taskbar_ != nullptr) {
      taskbar_->HrInit();
    }

    channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "setsuna/desktop_progress",
            &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) { HandleMethodCall(call, std::move(result)); });
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() != "setProgress") {
      result->NotImplemented();
      return;
    }

    const auto progress = GetProgressArgument(call.arguments());
    if (!progress.has_value()) {
      result->Error("invalid_arguments", "Expected a finite progress value.");
      return;
    }
    if (taskbar_ == nullptr || window_ == nullptr) {
      result->Error("unavailable",
                    "Windows taskbar integration is unavailable.");
      return;
    }

    if (progress.value() < 0) {
      taskbar_->SetProgressState(window_, TBPF_NOPROGRESS);
    } else if (progress.value() > 1) {
      taskbar_->SetProgressState(window_, TBPF_INDETERMINATE);
    } else {
      const auto completed = static_cast<ULONGLONG>(
          std::round(progress.value() * 10000.0));
      taskbar_->SetProgressState(window_, TBPF_NORMAL);
      taskbar_->SetProgressValue(window_, completed, 10000);
    }
    result->Success();
  }

  HWND window_ = nullptr;
  Microsoft::WRL::ComPtr<ITaskbarList3> taskbar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

DesktopProgress::DesktopProgress(flutter::FlutterEngine* engine, HWND window)
    : impl_(std::make_unique<Impl>(engine, window)) {}

DesktopProgress::~DesktopProgress() = default;
