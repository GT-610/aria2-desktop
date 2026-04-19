#include "protocol_integration.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <algorithm>
#include <cwctype>
#include <memory>
#include <optional>
#include <string>

#include "utils.h"

namespace {

constexpr wchar_t kClassesRootPrefix[] = L"Software\\Classes\\";

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }

  const int target_length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.c_str(), -1, nullptr, 0);
  if (target_length <= 1) {
    return std::wstring();
  }

  std::wstring utf16_string(target_length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.c_str(),
                          -1, utf16_string.data(), target_length) == 0) {
    return std::wstring();
  }
  utf16_string.pop_back();
  return utf16_string;
}

std::string FormatWindowsError(const std::string& action, LSTATUS code) {
  wchar_t* buffer = nullptr;
  const DWORD flags =
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS;
  const DWORD length = FormatMessageW(
      flags, nullptr, static_cast<DWORD>(code),
      MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);

  std::string message = action;
  if (length > 0 && buffer != nullptr) {
    message += ": ";
    message += Utf8FromUtf16(buffer);
    LocalFree(buffer);
  }
  return message;
}

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t ch) { return std::towlower(ch); });
  return value;
}

std::wstring GetExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                    static_cast<DWORD>(path.size()));
  while (length == path.size()) {
    path.resize(path.size() * 2, L'\0');
    length = GetModuleFileNameW(nullptr, path.data(),
                                static_cast<DWORD>(path.size()));
  }

  if (length == 0) {
    return std::wstring();
  }

  path.resize(length);
  return path;
}

std::wstring BuildProtocolKey(const std::wstring& scheme) {
  return std::wstring(kClassesRootPrefix) + scheme;
}

std::wstring BuildCommandKey(const std::wstring& scheme) {
  return BuildProtocolKey(scheme) + L"\\shell\\open\\command";
}

std::optional<std::wstring> ReadRegistryString(HKEY root,
                                               const std::wstring& subkey,
                                               const wchar_t* value_name) {
  DWORD size = 0;
  LSTATUS status = RegGetValueW(root, subkey.c_str(), value_name, RRF_RT_REG_SZ,
                                nullptr, nullptr, &size);
  if (status != ERROR_SUCCESS) {
    return std::nullopt;
  }

  std::wstring value(size / sizeof(wchar_t), L'\0');
  status = RegGetValueW(root, subkey.c_str(), value_name, RRF_RT_REG_SZ,
                        nullptr, value.data(), &size);
  if (status != ERROR_SUCCESS) {
    return std::nullopt;
  }

  if (!value.empty() && value.back() == L'\0') {
    value.pop_back();
  }
  return value;
}

bool SetRegistryString(HKEY key, const wchar_t* value_name,
                       const std::wstring& value, std::string* error) {
  const DWORD value_size =
      static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t));
  const LSTATUS status = RegSetValueExW(
      key, value_name, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(value.c_str()), value_size);
  if (status != ERROR_SUCCESS) {
    if (error != nullptr) {
      *error = FormatWindowsError("Failed to write registry value", status);
    }
    return false;
  }
  return true;
}

std::optional<std::wstring> ExtractCommandExecutable(
    const std::wstring& command) {
  if (command.empty()) {
    return std::nullopt;
  }

  if (command.front() == L'"') {
    const size_t closing_quote = command.find(L'"', 1);
    if (closing_quote == std::wstring::npos) {
      return std::nullopt;
    }
    return command.substr(1, closing_quote - 1);
  }

  const size_t separator = command.find(L' ');
  if (separator == std::wstring::npos) {
    return command;
  }
  return command.substr(0, separator);
}

bool ProtocolOwnedByCurrentApp(const std::wstring& scheme) {
  const auto command = ReadRegistryString(HKEY_CURRENT_USER,
                                          BuildCommandKey(scheme), nullptr);
  if (!command.has_value()) {
    return false;
  }

  const auto executable = ExtractCommandExecutable(command.value());
  if (!executable.has_value()) {
    return false;
  }

  return ToLower(executable.value()) == ToLower(GetExecutablePath());
}

bool RegisterProtocol(const std::wstring& scheme, std::string* error) {
  HKEY protocol_key = nullptr;
  const auto protocol_key_path = BuildProtocolKey(scheme);
  LSTATUS status = RegCreateKeyExW(
      HKEY_CURRENT_USER, protocol_key_path.c_str(), 0, nullptr, 0,
      KEY_WRITE, nullptr, &protocol_key, nullptr);
  if (status != ERROR_SUCCESS) {
    if (error != nullptr) {
      *error = FormatWindowsError("Failed to create protocol key", status);
    }
    return false;
  }

  const std::wstring protocol_description = L"URL:" + scheme + L" Protocol";
  const std::wstring executable_path = GetExecutablePath();
  const std::wstring icon_value = L"\"" + executable_path + L"\",0";
  const std::wstring command_value =
      L"\"" + executable_path + L"\" \"%1\"";

  bool success = true;
  std::string write_error;
  success = SetRegistryString(protocol_key, nullptr, protocol_description,
                              &write_error) &&
            SetRegistryString(protocol_key, L"URL Protocol", L"", &write_error);
  RegCloseKey(protocol_key);

  if (!success) {
    if (error != nullptr) {
      *error = write_error;
    }
    return false;
  }

  HKEY icon_key = nullptr;
  status = RegCreateKeyExW(HKEY_CURRENT_USER,
                           (protocol_key_path + L"\\DefaultIcon").c_str(), 0,
                           nullptr, 0, KEY_WRITE, nullptr, &icon_key, nullptr);
  if (status != ERROR_SUCCESS) {
    if (error != nullptr) {
      *error = FormatWindowsError("Failed to create protocol icon key", status);
    }
    return false;
  }
  success = SetRegistryString(icon_key, nullptr, icon_value, &write_error);
  RegCloseKey(icon_key);
  if (!success) {
    if (error != nullptr) {
      *error = write_error;
    }
    return false;
  }

  HKEY command_key = nullptr;
  status = RegCreateKeyExW(HKEY_CURRENT_USER,
                           BuildCommandKey(scheme).c_str(), 0, nullptr, 0,
                           KEY_WRITE, nullptr, &command_key, nullptr);
  if (status != ERROR_SUCCESS) {
    if (error != nullptr) {
      *error = FormatWindowsError("Failed to create protocol command key",
                                  status);
    }
    return false;
  }
  success = SetRegistryString(command_key, nullptr, command_value, &write_error);
  RegCloseKey(command_key);
  if (!success && error != nullptr) {
    *error = write_error;
  }
  return success;
}

bool UnregisterProtocol(const std::wstring& scheme, std::string* error) {
  const auto protocol_key_path = BuildProtocolKey(scheme);
  if (!ReadRegistryString(HKEY_CURRENT_USER, protocol_key_path, nullptr)
           .has_value()) {
    return true;
  }

  if (!ProtocolOwnedByCurrentApp(scheme)) {
    return true;
  }

  const LSTATUS status =
      RegDeleteTreeW(HKEY_CURRENT_USER, protocol_key_path.c_str());
  if (status != ERROR_SUCCESS && status != ERROR_FILE_NOT_FOUND) {
    if (error != nullptr) {
      *error = FormatWindowsError("Failed to remove protocol key", status);
    }
    return false;
  }
  return true;
}

std::optional<std::string> GetStringArgument(const flutter::EncodableMap& args,
                                             const char* key) {
  const auto iterator = args.find(flutter::EncodableValue(key));
  if (iterator == args.end()) {
    return std::nullopt;
  }

  const auto* value = std::get_if<std::string>(&iterator->second);
  if (value == nullptr) {
    return std::nullopt;
  }
  return *value;
}

std::optional<bool> GetBoolArgument(const flutter::EncodableMap& args,
                                    const char* key) {
  const auto iterator = args.find(flutter::EncodableValue(key));
  if (iterator == args.end()) {
    return std::nullopt;
  }

  const auto* value = std::get_if<bool>(&iterator->second);
  if (value == nullptr) {
    return std::nullopt;
  }
  return *value;
}

bool IsSupportedScheme(const std::wstring& scheme) {
  return scheme == L"magnet" || scheme == L"thunder";
}

}  // namespace

class ProtocolIntegration::Impl {
 public:
  explicit Impl(flutter::FlutterEngine* engine) {
    channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "setsuna/protocol_integration",
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
    if (call.method_name() != "setProtocolEnabled") {
      result->NotImplemented();
      return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args == nullptr) {
      result->Error("invalid_arguments",
                    "Expected a map for protocol integration arguments.");
      return;
    }

    const auto scheme = GetStringArgument(*args, "scheme");
    const auto enabled = GetBoolArgument(*args, "enabled");
    if (!scheme.has_value() || !enabled.has_value()) {
      result->Error("invalid_arguments",
                    "Missing scheme or enabled argument.");
      return;
    }

    const std::wstring scheme_utf16 = ToLower(Utf16FromUtf8(scheme.value()));
    if (!IsSupportedScheme(scheme_utf16)) {
      result->Error("unsupported_scheme", "Only magnet and thunder are supported.");
      return;
    }

    std::string error;
    const bool success = enabled.value()
                             ? RegisterProtocol(scheme_utf16, &error)
                             : UnregisterProtocol(scheme_utf16, &error);
    if (!success) {
      result->Error("registry_error", error);
      return;
    }

    result->Success(flutter::EncodableValue(true));
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

ProtocolIntegration::ProtocolIntegration(flutter::FlutterEngine* engine)
    : impl_(std::make_unique<Impl>(engine)) {}

ProtocolIntegration::~ProtocolIntegration() = default;
