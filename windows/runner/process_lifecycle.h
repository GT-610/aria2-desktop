#ifndef RUNNER_PROCESS_LIFECYCLE_H_
#define RUNNER_PROCESS_LIFECYCLE_H_

#include <flutter/flutter_engine.h>

#include <memory>

class ProcessLifecycle {
 public:
  explicit ProcessLifecycle(flutter::FlutterEngine* engine);
  ~ProcessLifecycle();

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_PROCESS_LIFECYCLE_H_
