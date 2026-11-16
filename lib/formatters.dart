String formatRupiah(num? value) {
  final amount = (value ?? 0).toInt();
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final sign = amount < 0 ? '-' : '';
  return 'Rp $sign$grouped';
}
