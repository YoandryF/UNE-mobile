import 'package:flutter/material.dart';
import '../models.dart';
import '../tariff_calc.dart';
import '../theme.dart';

class CalculatorScreen extends StatefulWidget {
  final AppConfig config;
  const CalculatorScreen({super.key, required this.config});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _controller = TextEditingController();
  BillResult? _result;

  void _calculate() {
    final kwh = double.tryParse(_controller.text) ?? 0;
    if (kwh <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ingresa un consumo válido'), backgroundColor: Theme.of(context).colorScheme.secondary),
      );
      return;
    }
    setState(() => _result = calcBill(kwh, widget.config.tariffs));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const GradientText('⚡ Calculadora', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Consumo del mes', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 'kWh',
                    suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Calcular Factura'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ]),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            AccentCard(
              accentColor: theme.colorScheme.secondary,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total a pagar', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                  Text('${_controller.text} kWh', style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 8),
                GradientText(
                  '${_result!.total.toStringAsFixed(2)} CUP',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  gradient: AppTheme.dangerGradient,
                ),
                const Divider(height: 24),
                ...List.generate(_result!.breakdown.length, (i) {
                  final b = _result!.breakdown[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.5), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${b.used.toStringAsFixed(0)} kWh × \$${b.rate.toStringAsFixed(2)}${b.recargo ? ' (+${b.surcharge.toStringAsFixed(0)}%)' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text('\$${b.subtotal.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
