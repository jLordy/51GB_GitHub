import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/assistance/data/assistance_repository.dart';

final assistanceProvider = FutureProvider<AssistanceData>((ref) {
  return ref.watch(assistanceRepositoryProvider).fetchAll();
});
