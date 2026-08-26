import 'package:ritmo/core/domain/realm/realm_state.dart';
import 'package:ritmo/core/domain/realm/resolution/realm_context.dart';

/// Single independent layer in the realm resolution priority pipeline (F-09).
abstract interface class RealmResolutionLayer {
  Future<ActiveRealmState?> tryResolve(RealmContext ctx);
}
