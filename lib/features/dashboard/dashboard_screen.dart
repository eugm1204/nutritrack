import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../services/favorites_service.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/celebration_dialog.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/meal_card.dart';
import '../../widgets/suggestion_sheet.dart';
import '../auth/auth_controller.dart';
import '../onboarding/onboarding_screen.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);

    return Scaffold(
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(message: '$error'),
        data: (state) {
          if (!state.onboardingCompleted) return const OnboardingScreen();
          return _CelebrationGate(
            consumedCalories: state.consumedCalories,
            goalCalories: state.goalCalories,
            hasMeals: state.meals.isNotEmpty,
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(dashboardControllerProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  _GreetingHeader(
                    name: state.name,
                    avatarUrl: state.avatarUrl,
                    streakDays: state.streakDays,
                    onSettings: () => context.push('/settings'),
                    onLogout: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                  const SizedBox(height: 20),
                  _CalorieCard(
                    state: state,
                    onTap: () => context.go('/history'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/capture'),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Analisar refeição'),
                  ),
                  if (state.remainingCalories >= 200) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openSuggestions(context, ref, state),
                        icon: const Icon(Icons.lightbulb_outline, size: 16),
                        label: const Text('O que comer?'),
                        style: TextButton.styleFrom(
                          foregroundColor: appGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (state.favorites.isNotEmpty) ...[
                    _FavoritesSection(
                      favorites: state.favorites,
                      onRepeated: () => ref
                          .read(dashboardControllerProvider.notifier)
                          .refreshFavorites(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SectionTitle('Refeições'),
                  const SizedBox(height: 8),
                  if (state.meals.isEmpty)
                    const _EmptyMeals()
                  else
                    ..._mealGroups(state.meals, context, ref),
                  const SizedBox(height: 24),
                  _WaterCard(
                    cups: state.waterCups,
                    onAdd: () =>
                        ref.read(dashboardControllerProvider.notifier).addWater(),
                    onRemove: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .removeWater(),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle('Tendências'),
                  const SizedBox(height: 8),
                  _TrendsCard(state: state),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _mealGroups(
    List<dynamic> meals,
    BuildContext context,
    WidgetRef ref,
  ) {
    final mealsByPart = <String, List<dynamic>>{
      'Manhã': [],
      'Tarde': [],
      'Noite': [],
    };
    for (final meal in meals) {
      final h = meal.consumedAt.hour;
      final part = h < 11 ? 'Manhã' : (h < 18 ? 'Tarde' : 'Noite');
      mealsByPart[part]!.add(meal);
    }

    var index = 0;
    final widgets = <Widget>[];
    for (final entry in mealsByPart.entries) {
      if (entry.value.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(
          entry.key,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: appTextSecondary,
          ),
        ),
      ));
      for (final meal in entry.value) {
        widgets.add(AnimatedListItem(
          index: index++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('meal-${meal.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => ref
                  .read(dashboardControllerProvider.notifier)
                  .deleteMeal(meal.id),
              background: _DeleteBackground(),
              child: MealCard(
                meal: meal,
                onTap: () => context.push('/meal', extra: meal),
                onDelete: () =>
                    ref.read(dashboardControllerProvider.notifier).deleteMeal(meal.id),
              ),
            ),
          ),
        ));
      }
    }
    return widgets;
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia,';
    if (h < 19) return 'Boa tarde,';
    return 'Boa noite,';
  }
}

class _GreetingHeader extends StatelessWidget {
  final String? name;
  final String? avatarUrl;
  final int streakDays;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _GreetingHeader({
    required this.name,
    required this.avatarUrl,
    required this.streakDays,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final firstName = trimmed.isEmpty
        ? ''
        : trimmed.split(RegExp(r'\s+')).first;
    final display =
        firstName.length > 14 ? '${firstName.substring(0, 12)}…' : firstName;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: appTextPrimary,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(text: DashboardScreen._greeting()),
                    if (display.isNotEmpty)
                      TextSpan(
                        text: ' $display',
                        style: const TextStyle(color: appTextSecondary),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, d MMM', 'pt_PT').format(DateTime.now()),
                style: const TextStyle(fontSize: 13, color: appTextSecondary),
              ),
            ],
          ),
        ),
        if (streakDays > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: appFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🔥 $streakDays',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: appTextPrimary,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: appCard,
            shape: BoxShape.circle,
            border: Border.all(color: appHairline),
          ),
          child: _HeaderAvatar(
            avatarUrl: avatarUrl,
            name: name,
            onTap: onSettings,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 20, color: appTextSecondary),
          tooltip: 'Terminar sessão',
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final VoidCallback onTap;

  const _HeaderAvatar({
    required this.avatarUrl,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = this.avatarUrl;
    final initial = name != null && name!.trim().isNotEmpty
        ? name!.trim()[0].toUpperCase()
        : 'N';

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appFill,
        ),
        alignment: Alignment.center,
        child: avatarUrl != null
            ? ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : Container(color: appFill),
                    errorBuilder: (_, _, _) => _InitialText(initial: initial),
                  ),
                ),
              )
            : _InitialText(initial: initial),
      ),
    );
  }
}

class _InitialText extends StatelessWidget {
  final String initial;

  const _InitialText({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: const TextStyle(
        color: appTextPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: appTextPrimary,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final DashboardState state;
  final VoidCallback onTap;

  const _CalorieCard({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final remaining = state.remainingCalories;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, size: 18, color: appGreen),
                  const SizedBox(width: 8),
                  const Text(
                    'Calorias',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: appGreen,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 20, color: appTextSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(
                target: remaining < 0 ? 0 : remaining,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: appTextPrimary,
                  letterSpacing: -0.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  remaining >= 0 ? 'kcal restantes' : 'acima da meta',
                  style: const TextStyle(fontSize: 13, color: appTextSecondary),
                ),
              ),
              const Spacer(),
              _Sparkline(state: state),
            ],
          ),
          const SizedBox(height: 14),
          _MacroBars(state: state),
          const SizedBox(height: 12),
          Text(
            _motivation(remaining: remaining, progress: state.progress),
            style: const TextStyle(
              fontSize: 13,
              color: appTextSecondary,
              height: 1.35,
            ),
          ),
          if (state.latestWeightKg != null && state.targetWeightKg != null) ...[
            const SizedBox(height: 8),
            _TargetWeightRow(
              current: state.latestWeightKg!,
              target: state.targetWeightKg!,
            ),
          ],
        ],
      ),
    );
  }

  String _motivation({required int remaining, required double progress}) {
    if (remaining <= 0) return 'Já atingiste a meta de hoje — bom trabalho.';
    if (progress == 0) return 'Regista a primeira refeição para começar.';
    if (progress < 0.3) return 'Bom começo — continua assim.';
    if (progress < 0.7) return 'Vais a bom caminho hoje.';
    if (progress < 0.9) return 'Quase lá — faltam $remaining kcal.';
    return 'Só faltam $remaining kcal para a meta.';
  }
}

class _Sparkline extends StatelessWidget {
  final DashboardState state;

  const _Sparkline({required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final bars = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return state.weekTotals[DateTime(day.year, day.month, day.day)] ?? 0;
    });
    final maxY = bars.fold<int>(0, (m, v) => v > m ? v : m).clamp(100, 1 << 30);

    return SizedBox(
      width: 84,
      height: 34,
      child: BarChart(
        BarChartData(
          maxY: maxY.toDouble(),
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: bars[i].toDouble(),
                  width: 7,
                  borderRadius: BorderRadius.circular(2),
                  color: i == 6 ? appGreen : appTextSecondary.withValues(alpha: 0.35),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _TargetWeightRow extends StatelessWidget {
  final double current;
  final double target;

  const _TargetWeightRow({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final diff = current - target;
    final String text;
    if (diff.abs() < 0.25) {
      text = 'Estás no teu peso alvo';
    } else if (diff > 0) {
      text = 'Faltam ${diff.toStringAsFixed(1)} kg para o alvo';
    } else {
      text = 'Atingiste o teu alvo';
    }

    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 14, color: appGreen),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: appGreen,
          ),
        ),
      ],
    );
  }
}

class _MacroBars extends StatelessWidget {
  final DashboardState state;

  const _MacroBars({required this.state});

  @override
  Widget build(BuildContext context) {
    double sum(double? Function(dynamic item) extract) => state.meals.fold<double>(
        0,
        (acc, meal) =>
            acc + meal.items.fold<double>(0, (a, item) => a + (extract(item) ?? 0)));

    return Column(
      children: [
        _MacroBar(
          label: 'Proteína',
          current: sum((item) => item.protein),
          goal: state.proteinGoalG,
          color: macroProteinColor,
        ),
        const SizedBox(height: 7),
        _MacroBar(
          label: 'Hidratos',
          current: sum((item) => item.carbs),
          goal: state.carbsGoalG,
          color: macroCarbsColor,
        ),
        const SizedBox(height: 7),
        _MacroBar(
          label: 'Gordura',
          current: sum((item) => item.fat),
          goal: state.fatGoalG,
          color: macroFatColor,
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double current;
  final int? goal;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final target = goal;
    final progress =
        target == null || target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: appTextSecondary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: color,
              backgroundColor: appFill,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            target != null
                ? '${current.toStringAsFixed(0)}/${target}g'
                : '${current.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11.5, color: appTextSecondary),
          ),
        ),
      ],
    );
  }
}

class _TrendsCard extends StatelessWidget {
  final DashboardState state;

  const _TrendsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalFor(int daysAgo) =>
        state.weekTotals[today.subtract(Duration(days: daysAgo))] ?? 0;

    final current = [for (var i = 6; i >= 0; i--) totalFor(i)];
    final previous = [for (var i = 13; i >= 7; i--) totalFor(i)];
    final currentSum = current.fold(0, (a, b) => a + b);
    final previousSum = previous.fold(0, (a, b) => a + b);
    final currentAvg = currentSum / 7;
    final previousAvg = previousSum / 7;

    final hasComparison = previousSum > 0;
    final pct = hasComparison
        ? ((currentSum - previousSum) * 100 / previousSum).round()
        : 0;
    final wentDown = pct <= 0;

    final statement = !hasComparison
        ? 'Sem dados suficientes da semana anterior para comparar.'
        : pct == 0
            ? 'Esta semana consumiste o mesmo que a anterior.'
            : 'Esta semana consumiste ${pct.abs()}% ${wentDown ? 'menos' : 'mais'} calorias que a anterior.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, size: 18, color: appGreen),
              const SizedBox(width: 8),
              const Text(
                'Calorias',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: appGreen,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 20, color: appTextSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statement,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: appTextPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LegendDot(color: appTextSecondary.withValues(alpha: 0.5), label: 'Semana anterior'),
              const SizedBox(width: 12),
              _LegendDot(color: appGreen, label: 'Esta semana'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: (current.fold<int>(0, (m, v) => v > m ? v : m) *
                        1.2)
                    .clamp(100, 1 << 30)
                    .toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${rod.toY.round()} kcal',
                      Theme.of(context).textTheme.bodySmall!,
                    ),
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (hasComparison)
                      HorizontalLine(
                        y: previousAvg,
                        color: appTextSecondary.withValues(alpha: 0.5),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (line) =>
                              'média anterior ${previousAvg.round()}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: appTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    HorizontalLine(
                      y: currentAvg,
                      color: appGreen,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.bottomRight,
                        labelResolver: (line) =>
                            'média atual ${currentAvg.round()}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: appGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                barGroups: [
                  for (var i = 0; i < previous.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: previous[i].toDouble(),
                        width: 9,
                        borderRadius: BorderRadius.circular(3),
                        color: appTextSecondary.withValues(alpha: 0.35),
                      ),
                    ]),
                  for (var i = 0; i < current.length; i++)
                    BarChartGroupData(x: i + 7, barRods: [
                      BarChartRodData(
                        toY: current[i].toDouble(),
                        width: 9,
                        borderRadius: BorderRadius.circular(3),
                        color: appGreen,
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
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: appTextSecondary),
        ),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  final int cups;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _WaterCard({
    required this.cups,
    required this.onAdd,
    required this.onRemove,
  });

  static const _goal = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appHairline),
      ),
      child: Row(
        children: [
          const Text('💧', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Água',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (cups / _goal).clamp(0.0, 1.0),
                    minHeight: 5,
                    color: appWaterBlue,
                    backgroundColor: appFill,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$cups/$_goal copos · ${cups * 250} ml',
                  style: const TextStyle(fontSize: 11.5, color: appTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _WaterButton(icon: Icons.remove, enabled: cups > 0, onTap: onRemove),
          const SizedBox(width: 8),
          _WaterButton(icon: Icons.add, enabled: cups < 20, onTap: onAdd),
        ],
      ),
    );
  }
}

class _WaterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _WaterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? appTextPrimary : appTextSecondary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _FavoritesSection extends ConsumerWidget {
  final List<FavoriteMeal> favorites;
  final VoidCallback onRepeated;

  const _FavoritesSection({
    required this.favorites,
    required this.onRepeated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> repeat(FavoriteMeal favorite) async {
      try {
        final user = ref.read(supabaseProvider).auth.currentUser;
        if (user == null) return;
        await ref.read(mealRepositoryProvider).insertMeal(
              userId: user.id,
              imageUrl: favorite.imageUrl,
              mealName: favorite.name,
              items: favorite.items,
              consumedAt: DateTime.now(),
            );
        ref.invalidate(dashboardControllerProvider);
        onRepeated();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${favorite.name} registada')),
          );
        }
      } catch (e) {
        debugPrint('[favorites/repeat] Erro: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível repetir a refeição.')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Favoritas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: appTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/history'),
              child: const Text('Ver histórico ›'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final favorite in favorites) ...[
                _FavoritePhotoCard(
                  favorite: favorite,
                  onTap: () => repeat(favorite),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoritePhotoCard extends StatelessWidget {
  final FavoriteMeal favorite;
  final VoidCallback onTap;

  const _FavoritePhotoCard({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = favorite.items.fold<int>(0, (sum, item) => sum + item.calories);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 62,
                child: favorite.imageUrl != null
                    ? Image.network(
                        favorite.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _photoFallback(),
                      )
                    : _photoFallback(),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              favorite.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: appTextPrimary,
              ),
            ),
            Text(
              '$total kcal',
              style: const TextStyle(fontSize: 11, color: appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback() {
    return Container(
      color: appFill,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, size: 20, color: appTextSecondary),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: appRed,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appHairline),
      ),
      child: const Column(
        children: [
          Icon(Icons.restaurant, size: 32, color: appTextSecondary),
          SizedBox(height: 10),
          Text(
            'Ainda não registaste refeições hoje.\nTira uma foto ao teu prato para começar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: appTextSecondary, height: 1.4),
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
            const Icon(Icons.error_outline, size: 36, color: appTextSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

void _openSuggestions(
  BuildContext context,
  WidgetRef ref,
  DashboardState state,
) {
  double sum(double? Function(dynamic item) extract) => state.meals.fold<double>(
      0,
      (acc, meal) =>
          acc + meal.items.fold<double>(0, (a, item) => a + (extract(item) ?? 0)));

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SuggestionSheet(
      remainingKcal: state.remainingCalories,
      objective: state.objective,
      protein: sum((item) => item.protein),
      carbs: sum((item) => item.carbs),
      fat: sum((item) => item.fat),
      proteinGoal: state.proteinGoalG,
      carbsGoal: state.carbsGoalG,
      fatGoal: state.fatGoalG,
    ),
  );
}

class _CelebrationGate extends StatefulWidget {
  final int consumedCalories;
  final int goalCalories;
  final bool hasMeals;
  final Widget child;

  const _CelebrationGate({
    required this.consumedCalories,
    required this.goalCalories,
    required this.hasMeals,
    required this.child,
  });

  @override
  State<_CelebrationGate> createState() => _CelebrationGateState();
}

class _CelebrationGateState extends State<_CelebrationGate> {
  bool _celebratedToday = false;

  @override
  void initState() {
    super.initState();
    _checkCelebration();
  }

  @override
  void didUpdateWidget(covariant _CelebrationGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkCelebration();
  }

  Future<void> _checkCelebration() async {
    if (_celebratedToday) return;
    if (!widget.hasMeals) return;
    final goal = widget.goalCalories;
    final consumed = widget.consumedCalories;
    if (goal <= 0) return;

    final ratio = consumed / goal;
    if (ratio < 0.7 || ratio > 1.0) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (prefs.getString('last_celebration') == todayKey) {
      _celebratedToday = true;
      return;
    }

    await prefs.setString('last_celebration', todayKey);
    _celebratedToday = true;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => CelebrationDialog(
        consumedCalories: consumed,
        goalCalories: goal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}