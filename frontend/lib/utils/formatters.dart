String formatarData(DateTime? data) {
  if (data == null) return '';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$dia/$mes/$ano';
}

String formatarDataISO(DateTime? data) {
  if (data == null) return '';
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  final ano = data.year.toString();
  return '$ano-$mes-$dia';
}

DateTime? parseDataISO(String? dataStr) {
  if (dataStr == null || dataStr.trim().isEmpty) return null;
  try {
    final partes = dataStr.trim().split('-');
    if (partes.length != 3) return null;
    return DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
  } catch (_) {
    return null;
  }
}

String formatarDataCurta(String? dataStr) {
  if (dataStr == null || dataStr.trim().isEmpty) return '';
  try {
    final partes = dataStr.trim().split('-');
    if (partes.length != 3) return '';
    final dia = partes[2].padLeft(2, '0');
    final mes = partes[1].padLeft(2, '0');
    return '$dia/$mes';
  } catch (_) {
    return '';
  }
}
