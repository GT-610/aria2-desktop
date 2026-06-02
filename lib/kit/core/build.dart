enum BuildMode {
  release,
  debug,
  profile,
  ;

  static final isDebug = _buildMode == BuildMode.debug;
  static final isProfile = _buildMode == BuildMode.profile;
  static final isRelease = _buildMode == BuildMode.release;
}

final _buildMode = () {
  if (const bool.fromEnvironment('dart.vm.product')) {
    return BuildMode.release;
  }
  var result = BuildMode.profile;
  assert(() {
    result = BuildMode.debug;
    return true;
  }());
  return result;
}();
