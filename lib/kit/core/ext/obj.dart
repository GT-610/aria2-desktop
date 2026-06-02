import '../rnode.dart';

extension ObjectX<T extends Object> on T {
  VNode<T> get vn => VNode<T>(this);
}

extension ObjectXNullable<T extends Object> on T? {
  A? nullOr<A>(A Function(T) f) => this != null ? f(this!) : null;

  VNode<T?> get vn => VNode<T?>(this);
}

VNode<T?> nvn<T>() => VNode<T?>(null);
