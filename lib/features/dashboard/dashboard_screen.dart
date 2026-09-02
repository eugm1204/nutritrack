import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/pressable_card.dart';
import '../auth/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              DateFormat('EEEE, d MMM').format(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Definições',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Terminar sessão',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(message: '$error'),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardControllerProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _HeroCard(state: state),
              const SizedBox(height: 16),
              _WeeklyChart(state: state),
              const SizedBox(height: 20),
              Text(
                'Refeições 🍽️',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (state.meals.isEmpty)
                const _EmptyMeals()
              else
                ...state.meals.map(
                  (meal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MealCard(
                      meal: meal,
                      onTap: () => context.push('/meal', extra: meal),
                      onDelete: () => ref
                          .read(dashboardControllerProvider.notifier)
                          .deleteMeal(meal.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Boa noite 🌙';
    if (h < 12) return 'Bom dia ☀️';
    if (h < 19) return 'Boa tarde 🌤️';
    return 'Boa noite 🌙';
  }
}

class _HeroCard extends StatelessWidget {
  final DashboardState state;

  const _HeroCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consumed = state.consumedCalories;
    final remaining = state.remainingCalories;
    final goal = state.goalCalories;

    return PressableCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$remaining kcal',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      remaining >= 0 ? 'restantes hoje' : 'acima da meta',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCalorieRing(
                progress: state.progress,
                consumed: consumed,
                goal: goal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Motivation(remaining: remaining, progress: state.progress),
          const SizedBox(height: 12),
          _MacroChips(state: state),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: remaining >= 0
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
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
    );
  }
}

class _Motivation extends StatelessWidget {
  final int remaining;
  final double progress;

  const _Motivation({required this.remaining, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String message;
    if (remaining <= 0) {
      message = 'Já ultrapassaste a meta de hoje! 🎉';
    } else if (progress == 0) {
      message = 'Regista a primeira refeição para começar! 💪';
    } else if (progress < 0.3) {
      message = 'Bom começo! Continua assim 💪';
    } else if (progress < 0.7) {
      message = 'Vais a bom caminho! 🔥';
    } else if (progress < 0.9) {
      message = 'Quase lá! Só faltam $remaining kcal 🥗';
    } else {
      message = 'Só faltam $remaining kcal — não desistas! 🏁';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.12),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _MacroChips extends StatelessWidget {
  final DashboardState state;

  const _MacroChips({required this.state});

  @override
  Widget build(BuildContext context) {
    double sum(double? Function(dynamic item) extract) =>
        state.meals.fold<double>(
            0,
            (acc, meal) => acc +
                meal.items.fold<double>(
                    0, (a, item) => a + (extract(item) ?? 0)));

    final protein = sum((item) => item.protein);
    final carbs = sum((item) => item.carbs);
    final fat = sum((item) => item.fat);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MacroChip(
          label: 'Proteína',
          value: protein,
          color: macroProteinColor,
        ),
        _MacroChip(
          label: 'Hidratos',
          value: carbs,
          color: macroCarbsColor,
        ),
        _MacroChip(
          label: 'Gordura',
          value: fat,
          color: macroFatColor,
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ${value.toStringAsFixed(0)}g',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedCalorieRing extends StatelessWidget {
  final double progress;
  final int consumed;
  final int goal;

  const AnimatedCalorieRing({
    super.key,
    required this.progress,
    required this.consumed,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 116,
      height: 116,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: theme.colorScheme.primary,
            trackColor: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$consumed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
    const stroke = 13.0;
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
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: -1.5708 + 6.2832,
        colors: [color, color.withValues(alpha: 0.55)],
      ).createShader(rect);
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

    return PressableCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimos 7 dias 📊',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
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
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: state.goalCalories.toDouble(),
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.6),
                      strokeWidth: 1.4,
                      dashArray: [6, 5],
                    ),
                  ],
                ),
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
                              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
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
                        borderRadius: BorderRadius.circular(7),
                        color: i == 6
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.32),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _dayAbbrev(DateTime day) {
    const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return weekdays[day.weekday - 1];
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            'Ainda não registaste refeições hoje.\nTira uma foto ao teu prato para começar!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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