#include "power_management.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <optional>

namespace {

std::optional<bool> GetEnabledArgument(
    const flutter::EncodableValue* arguments) {
  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (args == nullptr) {
    return std::nullopt;
  }
  const auto iterator = args->find(flutter::EncodableValue("enabled"));
  if (iterator == args->end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<bool>(&iterator->second)) {
    return *value;
  }
  return std::nullopt;
}

}  // namespace

class PowerManagement::Impl {
 public:
  explicit Impl(flutter::FlutterEngine* engine) {
    channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "setsuna/power_management",
            &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) { HandleMethodCall(call, std::move(result)); });
  }

  ~Impl() { Apply(false); }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() != "setPreventSleep") {
      result->NotImplemented();
      return;
    }
    const auto enabled = GetEnabledArgument(call.arguments());
    if (!enabled.has_value()) {
      result->Error("invalid_arguments", "Expected an enabled boolean.");
      return;
    }

    if (!Apply(enabled.value())) {
      result->Error("power_request_failed",
                    "SetThreadExecutionState failed.");
      return;
    }
    result->Success();
  }

  bool Apply(bool enabled) {
    const EXECUTION_STATE state = enabled
                                      ? ES_CONTINUOUS | ES_SYSTEM_REQUIRED
                                      : ES_CONTINUOUS;
    if (SetThreadExecutionState(state) == 0) {
      return false;
    }
    return true;
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

PowerManagement::PowerManagement(flutter::FlutterEngine* engine)
    : impl_(std::make_unique<Impl>(engine)) {}

PowerManagement::~PowerManagement() = default;
