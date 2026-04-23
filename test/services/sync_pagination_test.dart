// ============================================================
// sync_pagination_test.dart
// Testes das constantes e lógica de paginação do sync,
// sem depender de Firebase ou SQLite real.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/comanda_service.dart';

void main() {
  group('ComandaService sync constants', () {
    test('_kSyncBatchSize está definida e é razoável', () {
      // Acessa via reflection não é possível para privados em Dart,
      // mas podemos garantir que o valor padrão 20 está exposto.
      // O teste valida que o código compila e o valor é sensato
      // ao verificar os limites da lógica de negócio.
      const batchSize = ComandaService.kSyncBatchSize;
      expect(batchSize, greaterThan(0));
      expect(batchSize, lessThanOrEqualTo(100));
    });
  });
}
