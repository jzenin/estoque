import 'package:isar/isar.dart';
part 'produto_isar.g.dart';

@collection
class ProdutoIsar {
  Id id = Isar.autoIncrement;
  String? nome;
  double? preco;
  int? quantidade;
  bool sincronizado = false;
}