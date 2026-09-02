import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final theme = Theme.of(context);
    final data = dashboard.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data == null
              ? 'NutriTrack'
              : data.isToday
                  ? 'Hoje · ${DateFormat('d MMM').format(data.date)}'
                  : DateFormat('EEEE, d MMM').format(data.date),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Escolher dia',
            onPressed: () => _pickDate(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: 'Peso',
            onPressed: () => context.push('/weight'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Terminar sessão',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Adicionar'),
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(message: '$error'),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardControllerProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _CalorieRingCard(state: state),
              const SizedBox(height: 16),
              _WeeklyChart(state: state),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Refeições', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (!state.isToday)
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(dashboardControllerProvider.notifier).goToToday(),
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('Hoje'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.meals.isEmpty)
                const _EmptyMeals()
              else
                ...state.meals.map((meal) => _MealCard(
                      meal: meal,
                      onTap: () => context.push('/meal', extra: meal),
                      onDelete: () => ref.read(dashboardControllerProvider.notifier).deleteMeal(meal.id),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieRingCard extends StatelessWidget {
  final DashboardState state;

  const _CalorieRingCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = state.consumedCalories;
    final remaining = state.remainingCalories;
    final goal = state.goalCalories;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _CalorieRing(progress: state.progress, consumed: consumed, goal: goal),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$remaining kcal',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remaining >= 0 ? 'restantes hoje' : 'acima da meta',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: remaining >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meta diária: $goal kcal',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieRing extends StatelessWidget {
  final double progress;
  final int consumed;
  final int goal;

  const _CalorieRing({required this.progress, required this.consumed, required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 130,
      height: 130,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: theme.colorScheme.primary,
          trackColor: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$consumed',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'de $goal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({required this.progress, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -1.5708, progress * 6.2832, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _WeeklyChart extends StatelessWidget {
  final DashboardState state;

  const _WeeklyChart({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = state.date;

    final bars = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final total = state.weekTotals[DateTime(day.year, day.month, day.day)] ?? 0;
      return (day: day, total: total);
    });

    final maxY = bars.fold<int>(0, (m, b) => b.total > m ? b.total : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Últimos 7 dias', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: (maxY * 1.2).clamp(100, double.infinity),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem('${rod.toY.round()} kcal', theme.textTheme.bodySmall!),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= bars.length) return const SizedBox.shrink();
                          final isToday = index == 6;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              isToday ? 'Hoje' : _dayAbbrev(bars[index].day),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < bars.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: bars[i].total.toDouble(),
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                          color: i == 6
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.35),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayAbbrev(DateTime day) {
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return weekdays[day.weekday - 1];
  }
}

class _MealCard extends StatelessWidget {
  final dynamic meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MealCard({required this.meal, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: meal.imageUrl != null
              ? Image.network(
                  meal.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _MealPlaceholder(),
                )
              : const _MealPlaceholder(),
        ),
        title: Text(meal.mealName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${meal.itemCount} item(s) · ${DateFormat('HH:mm').format(meal.consumedAt)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Text(
          '${meal.totalCalories} kcal',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        onTap: onTap,
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar refeição'),
        content: const Text('Tens a certeza que queres apagar esta refeição?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) onDelete();
  }
}

class _MealPlaceholder extends StatelessWidget {
  const _MealPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              'Ainda não registaste refeições hoje.\nTira uma foto ao teu prato para começar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(dashboardControllerProvider.notifier);
  final today = DateTime.now();
  final initial = ref.read(dashboardControllerProvider).value?.date ?? today;

  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(today.year, today.month, today.day).subtract(const Duration(days: 365)),
    lastDate: today,
    helpText: 'Escolher dia',
    cancelText: 'Cancelar',
    confirmText: 'Ver dia',
  );

  if (picked != null) {
    await controller.selectDate(picked);
  }
}