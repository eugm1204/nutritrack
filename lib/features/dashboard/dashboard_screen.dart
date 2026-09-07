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
import '../../widgets/pressable_card.dart';
import '../../widgets/suggestion_sheet.dart';
import '../auth/auth_controller.dart';
import '../onboarding/onboarding_screen.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardControllerProvider);
    final theme = Theme.of(context);

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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greetingWithName(state.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: appTextPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, d MMM').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 13,
                                color: appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (state.streakDays > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: appFill,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '🔥 ${state.streakDays}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: appTextPrimary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _HeaderAvatar(
                        avatarUrl: state.avatarUrl,
                        name: state.name,
                        onTap: () => context.push('/settings'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 20, color: appTextSecondary),
                        tooltip: 'Terminar sessão',
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ProgressCard(
                    state: state,
                    onSuggest: state.remainingCalories >= 200
                        ? () => _openSuggestions(context, ref, state)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/capture'),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    label: const Text('Analisar refeição'),
                  ),
                  const SizedBox(height: 20),
                  _WaterCard(
                    cups: state.waterCups,
                    onAdd: () =>
                        ref.read(dashboardControllerProvider.notifier).addWater(),
                    onRemove: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .removeWater(),
                  ),
                  const SizedBox(height: 16),
                  _WeeklyChart(state: state),
                  const SizedBox(height: 20),
                  if (state.favorites.isNotEmpty) ...[
                    _FavoritesSection(
                      favorites: state.favorites,
                      onRepeated: () => ref
                          .read(dashboardControllerProvider.notifier)
                          .refreshFavorites(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Refeições',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (state.meals.isEmpty)
                    const _EmptyMeals()
                  else
                    for (var i = 0; i < state.meals.length; i++)
                      AnimatedListItem(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey('meal-${state.meals[i].id}'),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => ref
                                .read(dashboardControllerProvider.notifier)
                                .deleteMeal(state.meals[i].id),
                            background: _DeleteBackground(),
                            child: MealCard(
                              meal: state.meals[i],
                              onTap: () =>
                                  context.push('/meal', extra: state.meals[i]),
                              onDelete: () => ref
                                  .read(dashboardControllerProvider.notifier)
                                  .deleteMeal(state.meals[i].id),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _greetingWithName(String? name) {
    final trimmed = name?.trim() ?? '';
    final firstName = trimmed.isEmpty
        ? ''
        : trimmed.split(RegExp(r'\s+')).first;
    final display =
        firstName.length > 14 ? '${firstName.substring(0, 12)}…' : firstName;

    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Bom dia' : (h < 19 ? 'Boa tarde' : 'Boa noite');
    return display.isEmpty ? greeting : '$greeting, $display';
  }
}

class _ProgressCard extends StatelessWidget {
  final DashboardState state;
  final VoidCallback? onSuggest;

  const _ProgressCard({required this.state, this.onSuggest});

  @override
  Widget build(BuildContext context) {
    final consumed = state.consumedCalories;
    final remaining = state.remainingCalories;
    final goal = state.goalCalories;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CountUpText(
                      target: remaining < 0 ? 0 : remaining,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: appTextPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remaining >= 0 ? 'de $goal kcal restantes' : 'acima da meta',
                      style: const TextStyle(
                        fontSize: 13,
                        color: appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$consumed kcal consumidas',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedCalorieRing(
                progress: state.progress,
                consumed: consumed,
                goal: goal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MacroBars(state: state),
          const SizedBox(height: 14),
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
          if (onSuggest != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onSuggest,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text('O que comer?'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
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

class _TargetWeightRow extends StatelessWidget {
  final double current;
  final double target;

  const _TargetWeightRow({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    final diff = current - target;
    final (String text, bool positive) = diff.abs() < 0.25
        ? ('Estás no teu peso alvo', true)
        : diff > 0
            ? ('Faltam ${diff.toStringAsFixed(1)} kg para o alvo', true)
            : ('Ultrapassaste o alvo em ${diff.abs().toStringAsFixed(1)} kg', true);

    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 14, color: appGreen),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: positive ? appGreen : appTextPrimary,
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
    return SizedBox(
      width: 96,
      height: 96,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(progress: value),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CountUpText(
                  target: consumed,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: appTextPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(fontSize: 10.5, color: appTextSecondary),
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

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = appFill;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = appGreen;
    canvas.drawArc(rect, -1.5708, progress * 6.2832, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimos 7 dias', style: theme.textTheme.titleMedium),
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
                      color: appTextSecondary.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isToday ? appGreen : appTextSecondary,
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
                        width: 16,
                        borderRadius: BorderRadius.circular(6),
                        color: i == 6
                            ? appGreen
                            : appGreen.withValues(alpha: 0.22),
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

class _FavoritesSection extends ConsumerWidget {
  final List<FavoriteMeal> favorites;
  final VoidCallback onRepeated;

  const _FavoritesSection({
    required this.favorites,
    required this.onRepeated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
        Text('Favoritas', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final favorite in favorites) ...[
                _FavoriteChip(
                  favorite: favorite,
                  onTap: () => repeat(favorite),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  final FavoriteMeal favorite;
  final VoidCallback onTap;

  const _FavoriteChip({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = favorite.items.fold<int>(0, (sum, item) => sum + item.calories);
    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 16, color: appOrange),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                favorite.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: appTextPrimary,
                ),
              ),
              Text(
                '$total kcal',
                style: const TextStyle(fontSize: 11.5, color: appTextSecondary),
              ),
            ],
          ),
          const SizedBox(width: 6),
          const Icon(Icons.play_circle_outline, size: 18, color: appGreen),
        ],
      ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appFill,
          border: Border.all(color: appHairline),
        ),
        alignment: Alignment.center,
        child: avatarUrl != null
            ? ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
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
        fontSize: 16,
      ),
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