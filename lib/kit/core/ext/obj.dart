import '../rnode.dart';

extension ObjectX<T extends Object> on T {
  VNode<T> get vn => VNode<T>(this);
}

extension ObjectXNullable<T extends Object> on T? {
  VNode<T?> get vn => VNode<T?>(this);
}
