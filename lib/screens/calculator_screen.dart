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
  final _kwhCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  bool _isInverse = false;
  BillResult? _billResult;
  InverseResult? _inverseResult;

  void _calculate() {
    final kwh = double.tryParse(_kwhCtrl.text) ?? 0;
    if (kwh <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ingresa un consumo válido'), backgroundColor: Theme.of(context).colorScheme.secondary),
      );
      return;
    }
    setState(() {
      _billResult = calcBill(kwh, widget.config.tariffs);
      _inverseResult = null;
    });
  }

  void _calcInverse() {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    if (budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ingresa un presupuesto válido'), backgroundColor: Theme.of(context).colorScheme.secondary),
      );
      return;
    }
    setState(() {
      _inverseResult = calcInverse(budget, widget.config.tariffs);
      _billResult = null;
    });
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
          // Mode toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: _ModeButton(
                    label: 'kWh → CUP',
                    icon: Icons.bolt,
                    active: !_isInverse,
                    onTap: () => setState(() => _isInverse = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: 'CUP → kWh',
                    icon: Icons.savings,
                    active: _isInverse,
                    onTap: () => setState(() => _isInverse = true),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _isInverse ? '💰 Plan de ahorro' : 'Consumo del mes',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  _isInverse ? '¿Cuánto puedo consumir con mi presupuesto?' : 'Calcula tu factura por consumo',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (!_isInverse)
                  TextField(
                    controller: _kwhCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0', suffixText: 'kWh'),
                  )
                else
                  TextField(
                    controller: _budgetCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0', suffixText: 'CUP', prefixIcon: Icon(Icons.attach_money)),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isInverse ? _calcInverse : _calculate,
                  icon: Icon(_isInverse ? Icons.savings : Icons.bolt),
                  label: Text(_isInverse ? 'Calcular Consumo' : 'Calcular Factura'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ]),
            ),
          ),
          // Normal result
          if (_billResult != null) ...[
            const SizedBox(height: 16),
            AccentCard(
              accentColor: theme.colorScheme.secondary,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total a pagar', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                  Text('${_kwhCtrl.text} kWh', style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 8),
                GradientText(
                  '${_billResult!.total.toStringAsFixed(2)} CUP',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  gradient: AppTheme.dangerGradient,
                ),
                const Divider(height: 24),
                ..._buildBreakdown(_billResult!.breakdown, theme),
              ]),
            ),
          ],
          // Inverse result
          if (_inverseResult != null) ...[
            const SizedBox(height: 16),
            AccentCard(
              accentColor: Colors.green,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💰 Con tu presupuesto', style: theme.textTheme.titleSmall?.copyWith(color: Colors.green)),
                const SizedBox(height: 8),
                GradientText(
                  '${_inverseResult!.kwh.toStringAsFixed(1)} kWh',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  gradient: const LinearGradient(colors: [Colors.green, Colors.teal]),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Gasto: ${_inverseResult!.spent.toStringAsFixed(2)} CUP', style: theme.textTheme.bodySmall),
                  Text('Sobrante: ${_inverseResult!.remaining.toStringAsFixed(2)} CUP', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                ]),
                const Divider(height: 24),
                ..._buildBreakdown(_inverseResult!.breakdown, theme),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  List<Widget> _buildBreakdown(List<BillBreakdown> breakdown, ThemeData theme) {
    return List.generate(breakdown.length, (i) {
      final b = breakdown[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.5), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${b.used.toStringAsFixed(1)} kWh × \$${b.rate.toStringAsFixed(2)}${b.recargo ? ' (+${b.surcharge.toStringAsFixed(0)}%)' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Text('\$${b.subtotal.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      );
    });
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? AppTheme.accentGradient : null,
          color: active ? null : Colors.transparent,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5))),
        ]),
      ),
    );
  }
}
