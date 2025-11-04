// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 2;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      billNumber: fields[0] as String,
      date: fields[1] as DateTime,
      customerName: fields[2] as String?,
      customerPhone: fields[3] as String?,
      items: (fields[4] as List).cast<BillItem>(),
      totalAmount: fields[5] as double,
      discount: fields[6] as double,
      paymentMode: fields[7] as String,
      doctorName: fields[8] as String?,
      isDiscountPercentage: fields[9] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.billNumber)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.customerName)
      ..writeByte(3)
      ..write(obj.customerPhone)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.totalAmount)
      ..writeByte(6)
      ..write(obj.discount)
      ..writeByte(7)
      ..write(obj.paymentMode)
      ..writeByte(8)
      ..write(obj.doctorName)
      ..writeByte(9)
      ..write(obj.isDiscountPercentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
