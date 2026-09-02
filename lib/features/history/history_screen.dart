import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/pressable_card.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _expandedDay;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Histórico 📅',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (state) {
          final days = state.mealsByDay.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          if (days.isEmpty) return const _EmptyHistory();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(historyControllerProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (state.insights.hasData) ...[
                  _InsightsCard(insights: state.insights),
                  const SizedBox(height: 16),
                ],
                for (var i = 0; i < days.length; i++) ...[
                  AnimatedListItem(
                    index: i,
                    child: _DayCard(
                      day: days[i],
                      meals: state.mealsByDay[days[i]]!,
                      goalCalories: state.goalCalories,
                      expanded: _expandedDay == days[i],
                      onTap: () => setState(() {
                        _expandedDay = _expandedDay == days[i] ? null : days[i];
                      }),
                      onDelete: (meal) => ref
                          .read(historyControllerProvider.notifier)
                          .deleteMeal(meal.id),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final WeeklyInsights insights;

  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = insights.changePercent;
    final hasPrevious = insights.previousWeekKcal != null;

    return PressableCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Insights da semana 📈',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: theme.colorScheme.primary,
                  label: 'Média/dia',
                  value: '${insights.avgKcalPerDay} kcal',
                ),
              ),
              Expanded(
                child: _InsightTile(
                  icon: Icons.calendar_view_day_outlined,
                  iconColor: macroCarbsColor,
                  label: 'Dias registados',
                  value: '${insights.daysLogged}/7',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InsightTile(
                  icon: Icons.thumb_up_alt_outlined,
                  iconColor: macroProteinColor,
                  label: 'Melhor dia',
                  value: insights.bestDay != null
                      ? '${_dayShort(insights.bestDay!)} · ${insights.bestDayKcal} kcal'
                      : '—',
                ),
              ),
              Expanded(
                child: _InsightTile(
                  icon: Icons.thumb_down_alt_outlined,
                  iconColor: theme.colorScheme.error,
                  label: 'Pior dia',
                  value: insights.worstDay != null
                      ? '${_dayShort(insights.worstDay!)} · ${insights.worstDayKcal} kcal'
                      : '—',
                ),
              ),
            ],
          ),
          if (hasPrevious) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  change != null && change <= 0
                      ? Icons.trending_down
                      : Icons.trending_up,
                  size: 18,
                  color: change != null && change <= 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    change == null
                        ? 'Sem dados da semana anterior'
                        : '${change.abs()}% ${change <= 0 ? 'menos' : 'mais'} calorias que a semana anterior',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: change != null && change <= 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dayShort(DateTime day) {
    final now = DateTime.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      return 'Hoje';
    }
    if (now.subtract(const Duration(days: 1)).day == day.day &&
        now.month == day.month &&
        now.year == day.year) {
      return 'Ontem';
    }
    return DateFormat('EEEE').format(day).substring(0, 3);
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InsightTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<Meal> meals;
  final int goalCalories;
  final bool expanded;
  final VoidCallback onTap;
  final void Function(Meal) onDelete;

  const _DayCard({
    required this.day,
    required this.meals,
    required this.goalCalories,
    required this.expanded,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = meals.fold<int>(0, (sum, meal) => sum + meal.totalCalories);
    final now = DateTime.now();
    final isToday = now.year == day.year && now.month == day.month && now.day == day.day;
    final isYesterday = now.subtract(const Duration(days: 1)).day == day.day &&
        now.month == day.month &&
        now.year == day.year;

    final dayLabel = isToday
        ? 'Hoje'
        : isYesterday
            ? 'Ontem'
            : DateFormat('EEEE').format(day);
    final progress = goalCalories <= 0 ? 0.0 : (total / goalCalories).clamp(0.0, 1.0);

    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primary.withValues(alpha: 0.14)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dayLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isToday ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('d MMM').format(day),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '$total',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                ' kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: total > goalCalories
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            for (final meal in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MealCard(
                  meal: meal,
                  showHero: false,
                  onTap: () => context.push('/meal', extra: meal),
                  onDelete: () => onDelete(meal),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(
              'Ainda não tens registos.\nAdiciona a tua primeira refeição!',
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