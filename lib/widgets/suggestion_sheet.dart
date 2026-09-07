import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/meal_item.dart';
import '../providers/providers.dart';
import '../services/ai_coach_service.dart';
import '../features/dashboard/dashboard_controller.dart';

class SuggestionSheet extends ConsumerStatefulWidget {
  final int remainingKcal;
  final String objective;
  final double protein;
  final double carbs;
  final double fat;
  final int? proteinGoal;
  final int? carbsGoal;
  final int? fatGoal;

  const SuggestionSheet({
    super.key,
    required this.remainingKcal,
    required this.objective,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
  });

  @override
  ConsumerState<SuggestionSheet> createState() => _SuggestionSheetState();
}

class _SuggestionSheetState extends ConsumerState<SuggestionSheet> {
  bool _loading = true;
  String? _error;
  List<MealSuggestion> _suggestions = [];
  bool _registering = false;

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
      final suggestions = await ref.read(aiCoachServiceProvider).suggestMeals(
            remainingKcal: widget.remainingKcal,
            objective: widget.objective,
            protein: widget.protein,
            carbs: widget.carbs,
            fat: widget.fat,
            proteinGoal: widget.proteinGoal,
            carbsGoal: widget.carbsGoal,
            fatGoal: widget.fatGoal,
          );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[suggest] Erro: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível gerar sugestões. Tenta novamente.';
      });
    }
  }

  Future<void> _register(MealSuggestion suggestion) async {
    setState(() => _registering = true);
    try {
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) throw Exception('Sessão expirada');
      await ref.read(mealRepositoryProvider).insertMeal(
            userId: user.id,
            imageUrl: null,
            mealName: suggestion.name,
            items: [
              MealItem(
                name: suggestion.name,
                calories: suggestion.calories,
                protein: suggestion.protein,
                carbs: suggestion.carbs,
                fat: suggestion.fat,
                confirmed: true,
              ),
            ],
            consumedAt: DateTime.now(),
          );
      ref.invalidate(dashboardControllerProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${suggestion.name} registada! 🎉')),
        );
      }
    } catch (e) {
      debugPrint('[suggest/register] Erro: $e');
      setState(() => _registering = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível registar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
        return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('O que comer?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Tens ${widget.remainingKcal} kcal restantes — 3 ideias para ti',
              style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13.5, color: appRed),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _load,
                                child: Text('Tentar de novo'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          children: [
                            for (var i = 0; i < _suggestions.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SuggestionCard(
                                  suggestion: _suggestions[i],
                                  registering: _registering,
                                  onRegister: () => _register(_suggestions[i]),
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

class _SuggestionCard extends StatelessWidget {
  final MealSuggestion suggestion;
  final bool registering;
  final VoidCallback onRegister;

  const _SuggestionCard({
    required this.suggestion,
    required this.registering,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kcal = suggestion.calories;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '$kcal kcal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.description,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  children: [
                    Text(
                      'P ${(suggestion.protein ?? 0).toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: macroProteinColor,
                      ),
                    ),
                    Text(
                      'H ${(suggestion.carbs ?? 0).toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: macroCarbsColor,
                      ),
                    ),
                    Text(
                      'G ${(suggestion.fat ?? 0).toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: macroFatColor,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: registering ? null : onRegister,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: registering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Registar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}