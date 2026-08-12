#include <winsock2.h>
#include <windows.h>
#include <iphlpapi.h>

#include "process_lifecycle.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cwctype>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace {

constexpr wchar_t kEngineMutexName[] = L"Local\\SetsunaBuiltinAria2";
constexpr int kTcpTableQueryAttempts = 3;

// MIB_TCP6TABLE_OWNER_PID is hidden by some Windows SDK family partitions
// even though GetExtendedTcpTable supports the corresponding desktop query.
struct Tcp6RowOwnerPid {
  UCHAR local_address[16];
  DWORD local_scope_id;
  DWORD local_port;
  UCHAR remote_address[16];
  DWORD remote_scope_id;
  DWORD remote_port;
  DWORD state;
  DWORD owning_pid;
};

struct Tcp6TableOwnerPid {
  DWORD number_of_entries;
  Tcp6RowOwnerPid table[1];
};

std::optional<int64_t> GetIntegerArgument(const flutter::EncodableMap& args,
                                          const char* key) {
  const auto iterator = args.find(flutter::EncodableValue(key));
  if (iterator == args.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(&iterator->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&iterator->second)) {
    return *value;
  }
  return std::nullopt;
}

std::optional<std::string> GetStringArgument(const flutter::EncodableMap& args,
                                             const char* key) {
  const auto iterator = args.find(flutter::EncodableValue(key));
  if (iterator == args.end()) {
    return std::nullopt;
  }
  const auto* value = std::get_if<std::string>(&iterator->second);
  return value == nullptr ? std::nullopt
                          : std::optional<std::string>(*value);
}

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                          value.c_str(), -1, nullptr, 0);
  if (length <= 1) {
    return std::wstring();
  }
  std::wstring result(length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.c_str(), -1,
                          result.data(), length) == 0) {
    return std::wstring();
  }
  result.pop_back();
  return result;
}

std::wstring NormalizePath(std::wstring value) {
  std::replace(value.begin(), value.end(), L'/', L'\\');
  constexpr wchar_t kExtendedPathPrefix[] = L"\\\\?\\";
  if (value.rfind(kExtendedPathPrefix, 0) == 0) {
    value.erase(0, 4);
  }
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t character) { return std::towlower(character); });
  return value;
}

std::optional<std::wstring> QueryProcessPath(HANDLE process) {
  std::wstring path(32768, L'\0');
  DWORD length = static_cast<DWORD>(path.size());
  if (!QueryFullProcessImageNameW(process, 0, path.data(), &length)) {
    return std::nullopt;
  }
  path.resize(length);
  return path;
}

}  // namespace

class ProcessLifecycle::Impl {
 public:
  explicit Impl(flutter::FlutterEngine* engine) {
    engine_mutex_ = CreateMutexW(nullptr, FALSE, kEngineMutexName);
    owns_engine_lock_ =
        engine_mutex_ != nullptr && GetLastError() != ERROR_ALREADY_EXISTS;

    job_object_ = CreateJobObjectW(nullptr, nullptr);
    if (job_object_ != nullptr) {
      JOBOBJECT_EXTENDED_LIMIT_INFORMATION information{};
      information.BasicLimitInformation.LimitFlags =
          JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      if (!SetInformationJobObject(job_object_, JobObjectExtendedLimitInformation,
                                   &information, sizeof(information))) {
        CloseHandle(job_object_);
        job_object_ = nullptr;
      }
    }

    channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(), "setsuna/process_lifecycle",
            &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                   result) { HandleMethodCall(call, std::move(result)); });
  }

  ~Impl() {
    channel_.reset();
    if (job_object_ != nullptr) {
      CloseHandle(job_object_);
    }
    if (engine_mutex_ != nullptr) {
      CloseHandle(engine_mutex_);
    }
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "ownsEngineLock") {
      result->Success(flutter::EncodableValue(owns_engine_lock_));
      return;
    }

    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args == nullptr) {
      result->Error("invalid_arguments", "Expected a map of arguments.");
      return;
    }
    if (call.method_name() == "findExpectedProcess") {
      const auto port = GetIntegerArgument(*args, "port");
      const auto executable_path = GetStringArgument(*args, "executablePath");
      if (!port.has_value() || port.value() <= 0 || port.value() > 65535 ||
          !executable_path.has_value()) {
        result->Error("invalid_arguments", "Expected port and executablePath.");
        return;
      }
      const auto pid = FindExpectedProcess(
          static_cast<uint16_t>(port.value()), executable_path.value());
      result->Success(pid.has_value()
                          ? flutter::EncodableValue(
                                static_cast<int64_t>(pid.value()))
                          : flutter::EncodableValue());
      return;
    }

    const auto pid = GetIntegerArgument(*args, "pid");
    if (!pid.has_value() || pid.value() <= 0 ||
        pid.value() > static_cast<int64_t>(MAXDWORD)) {
      result->Error("invalid_pid", "Expected a valid process id.");
      return;
    }
    if (call.method_name() == "attachProcess") {
      result->Success(flutter::EncodableValue(AttachProcess(
          static_cast<DWORD>(pid.value()))));
      return;
    }
    if (call.method_name() == "isExpectedProcess") {
      const auto executable_path = GetStringArgument(*args, "executablePath");
      if (!executable_path.has_value()) {
        result->Error("invalid_arguments", "Missing executablePath.");
        return;
      }
      result->Success(flutter::EncodableValue(IsExpectedProcess(
          static_cast<DWORD>(pid.value()), executable_path.value())));
      return;
    }
    result->NotImplemented();
  }

  bool AttachProcess(DWORD pid) const {
    if (!owns_engine_lock_ || job_object_ == nullptr) {
      return false;
    }
    HANDLE process = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE |
                                     PROCESS_QUERY_LIMITED_INFORMATION,
                                 FALSE, pid);
    if (process == nullptr) {
      return false;
    }
    const bool assigned = AssignProcessToJobObject(job_object_, process) != FALSE;
    CloseHandle(process);
    return assigned;
  }

  bool IsExpectedProcess(DWORD pid, const std::string& expected_path) const {
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE,
                                 FALSE, pid);
    if (process == nullptr) {
      return false;
    }
    const bool running = WaitForSingleObject(process, 0) == WAIT_TIMEOUT;
    const auto process_path = running ? QueryProcessPath(process) : std::nullopt;
    CloseHandle(process);
    if (!process_path.has_value()) {
      return false;
    }
    return NormalizePath(process_path.value()) ==
           NormalizePath(Utf16FromUtf8(expected_path));
  }

  std::optional<DWORD> FindExpectedProcess(
      uint16_t port, const std::string& expected_path) const {
    for (const ULONG address_family : {AF_INET, AF_INET6}) {
      ULONG size = 0;
      std::vector<unsigned char> buffer;
      DWORD status = ERROR_INSUFFICIENT_BUFFER;
      for (int attempt = 0;
           attempt < kTcpTableQueryAttempts &&
           status == ERROR_INSUFFICIENT_BUFFER;
           ++attempt) {
        buffer.resize(size);
        status = GetExtendedTcpTable(
            buffer.empty() ? nullptr : buffer.data(), &size, FALSE,
            address_family, TCP_TABLE_OWNER_PID_LISTENER, 0);
      }
      if (status != NO_ERROR) {
        return std::nullopt;
      }

      if (address_family == AF_INET) {
        const auto* table =
            reinterpret_cast<const MIB_TCPTABLE_OWNER_PID*>(buffer.data());
        for (DWORD index = 0; index < table->dwNumEntries; ++index) {
          const auto& row = table->table[index];
          if (ntohs(static_cast<u_short>(row.dwLocalPort)) == port &&
              IsExpectedProcess(row.dwOwningPid, expected_path)) {
            return row.dwOwningPid;
          }
        }
      } else {
        const auto* table =
            reinterpret_cast<const Tcp6TableOwnerPid*>(buffer.data());
        for (DWORD index = 0; index < table->number_of_entries; ++index) {
          const auto& row = table->table[index];
          if (ntohs(static_cast<u_short>(row.local_port)) == port &&
              IsExpectedProcess(row.owning_pid, expected_path)) {
            return row.owning_pid;
          }
        }
      }
    }
    return std::nullopt;
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HANDLE engine_mutex_ = nullptr;
  HANDLE job_object_ = nullptr;
  bool owns_engine_lock_ = false;
};

ProcessLifecycle::ProcessLifecycle(flutter::FlutterEngine* engine)
    : impl_(std::make_unique<Impl>(engine)) {}

ProcessLifecycle::~ProcessLifecycle() = default;
