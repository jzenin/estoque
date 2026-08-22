
part of 'produto_isar.dart';

extension GetProdutoIsarCollection on Isar {
  IsarCollection<ProdutoIsar> get produtoIsars => this.collection();
}

final ProdutoIsarSchema = CollectionSchema(
  name: r'ProdutoIsar',
  id: 1,
  properties: {
    r'nome': PropertySchema(id: 0, name: r'nome', type: IsarType.string),
    r'preco': PropertySchema(id: 1, name: r'preco', type: IsarType.double),
    r'quantidade': PropertySchema(id: 2, name: r'quantidade', type: IsarType.long),
    r'sincronizado': PropertySchema(id: 3, name: r'sincronizado', type: IsarType.bool)
  },
  estimateSize: _produtoIsarEstimateSize,
  serialize: _produtoIsarSerialize,
  deserialize: _produtoIsarDeserialize,
  deserializeProp: _produtoIsarDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: (obj) => obj.id,
  getLinks: (obj) => [],
  attach: (db, id, obj) { obj.id = id; },
  version: '3.1.0+1',
);

int _produtoIsarEstimateSize(ProdutoIsar object, List<int> offsets, Map<Type, List<int>> allOffsets) {
  var bytesCount = offsets.last;
  if (object.nome!= null) bytesCount += 3 + object.nome!.length * 3;
  return bytesCount;
}

void _produtoIsarSerialize(ProdutoIsar object, IsarWriter writer, List<int> offsets, Map<Type, List<int>> allOffsets) {
  writer.writeString(offsets[0], object.nome);
  writer.writeDouble(offsets[1], object.preco);
  writer.writeLong(offsets[2], object.quantidade);
  writer.writeBool(offsets[3], object.sincronizado);
}

ProdutoIsar _produtoIsarDeserialize(Id id, IsarReader reader, List<int> offsets, Map<Type, List<int>> allOffsets) {
  final object = ProdutoIsar();
  object.id = id;
  object.nome = reader.readStringOrNull(offsets[0]);
  object.preco = reader.readDoubleOrNull(offsets[1]);
  object.quantidade = reader.readLongOrNull(offsets[2]);
  object.sincronizado = reader.readBoolOrNull(offsets[3])?? false;
  return object;
}

P _produtoIsarDeserializeProp<P>(IsarReader reader, int propertyId, int offset, Map<Type, List<int>> allOffsets) {
  switch (propertyId) {
    case 0: return (reader.readStringOrNull(offset)) as P;
    case 1: return (reader.readDoubleOrNull(offset)) as P;
    case 2: return (reader.readLongOrNull(offset)) as P;
    case 3: return (reader.readBoolOrNull(offset)?? false) as P;
    default: throw IsarError('Unknown property with id $propertyId');
  }
}

extension ProdutoIsarQueryFilter on QueryBuilder<ProdutoIsar, ProdutoIsar, QFilterCondition> {
  QueryBuilder<ProdutoIsar, ProdutoIsar, QAfterFilterCondition> sincronizadoEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(property: r'sincronizado', value: value));
    });
  }
}