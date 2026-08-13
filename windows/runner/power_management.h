#ifndef RUNNER_POWER_MANAGEMENT_H_
#define RUNNER_POWER_MANAGEMENT_H_

#include <flutter/flutter_engine.h>

#include <memory>

class PowerManagement {
 public:
  explicit PowerManagement(flutter::FlutterEngine* engine);
  ~PowerManagement();

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_POWER_MANAGEMENT_H_
