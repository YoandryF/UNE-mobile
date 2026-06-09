import 'models.dart';

class BillBreakdown {
  final double used;
  final double rate;
  final double subtotal;
  final bool recargo;
  final double surcharge;
  BillBreakdown({required this.used, required this.rate, required this.subtotal, this.recargo = false, this.surcharge = 0});
}

class BillResult {
  final double total;
  final List<BillBreakdown> breakdown;
  BillResult(this.total, this.breakdown);
}

BillResult calcBill(double kwh, TariffConfig tariffs) {
  if (kwh <= 0) return BillResult(0, []);
  final ranges = tariffs.ranges;
  final surcharge = tariffs.surcharge / 100;
  final breakdown = <BillBreakdown>[];

  if (kwh <= 500) {
    double cost = 0, rem = kwh;
    for (final r in ranges) {
      if (rem <= 0) break;
      final used = rem < r.size ? rem : r.size;
      cost += used * r.rate;
      breakdown.add(BillBreakdown(used: used, rate: r.rate, subtotal: used * r.rate));
      rem -= used;
    }
    return BillResult(cost, breakdown);
  }

  // >500
  double base = 0, rem = 500;
  for (final r in ranges) {
    if (rem <= 0) break;
    final used = rem < r.size ? rem : r.size;
    base += used * r.rate;
    breakdown.add(BillBreakdown(used: used, rate: r.rate, subtotal: used * r.rate));
    rem -= used;
  }

  double acc = 0, excRate = ranges.last.rate;
  for (final r in ranges) {
    acc += r.size;
    if (kwh <= acc) { excRate = r.rate; break; }
  }

  final excess = kwh - 500;
  final excCost = excess * excRate * (1 + surcharge);
  breakdown.add(BillBreakdown(used: excess, rate: excRate, subtotal: excCost, recargo: true, surcharge: tariffs.surcharge));
  return BillResult(base + excCost, breakdown);
}
