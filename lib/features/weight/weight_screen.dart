import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/weight_entry.dart';
import '../../providers/providers.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  bool _loading = true;
  String? _error;
  List<WeightEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final entries = await ref.read(weightRepositoryProvider).fetchEntries(userId);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o peso.';
      });
    }
  }

  Future<void> _addEntry() async {
    final weightController = TextEditingController();
    DateTime date = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registar peso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(DateFormat('d MMM yyyy').format(date)),
                leading: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    final weight = double.tryParse(weightController.text.trim());
    weightController.dispose();

    if (saved != true || weight == null || weight <= 0) return;

    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      await ref.read(weightRepositoryProvider).addEntry(
            userId: userId,
            weightKg: weight,
            recordedAt: date,
          );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível guardar o peso.')),
        );
      }
    }
  }

  Future<void> _deleteEntry(WeightEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar medição'),
        content: Text('${entry.weightKg.toStringAsFixed(1)} kg de '
            '${DateFormat('d MMM').format(entry.recordedAt)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    await ref.read(weightRepositoryProvider).deleteEntry(entry.id, userId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = _entries.isNotEmpty ? _entries.last.weightKg : null;
    final first = _entries.isNotEmpty ? _entries.first.weightKg : null;
    final change = (latest != null && first != null) ? latest - first : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Peso')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Registar peso'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _entries.isEmpty
                  ? const _EmptyWeight()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${latest!.toStringAsFixed(1)} kg',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        change <= 0
                                            ? Icons.trending_down
                                            : Icons.trending_up,
                                        color: change <= 0
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.error,
                                        size: 20,
                                      ),
                                      Text(
                                        '${change.abs().toStringAsFixed(1)} kg',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 180,
                                    child: _WeightChart(entries: _entries),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Histórico',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ..._entries.reversed.map(
                            (entry) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.monitor_weight_outlined),
                                title: Text(
                                  '${entry.weightKg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  DateFormat('EEEE, d MMM yyyy').format(entry.recordedAt),
                                ),
                                onLongPress: () => _deleteEntry(entry),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;

  const _WeightChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = entries.length > 30 ? entries.sublist(entries.length - 30) : entries;

    final minW = recent.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxW = recent.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final pad = ((maxW - minW) * 0.15).clamp(0.3, 5.0);

    return LineChart(
      LineChartData(
        minY: (minW - pad).floorToDouble(),
        maxY: (maxW + pad).ceilToDouble(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((spot) => LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)} kg',
                      theme.textTheme.bodySmall!,
                    ))
                .toList(),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < recent.length; i++)
                FlSpot(i.toDouble(), recent[i].weightKg),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWeight extends StatelessWidget {
  const _EmptyWeight();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_weight_outlined,
                size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              'Ainda não tens medições.\nToca em "Registar peso" para começar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}