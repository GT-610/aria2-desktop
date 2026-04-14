#ifndef RUNNER_PROTOCOL_INTEGRATION_H_
#define RUNNER_PROTOCOL_INTEGRATION_H_

#include <flutter/flutter_engine.h>

#include <memory>

class ProtocolIntegration {
 public:
  explicit ProtocolIntegration(flutter::FlutterEngine* engine);
  ~ProtocolIntegration();

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_PROTOCOL_INTEGRATION_H_
