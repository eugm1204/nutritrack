import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Profile? _profile;
  bool _uploadingAvatar = false;
  String? _error;

  String? get _email => ref.read(supabaseProvider).auth.currentUser?.email;

  Future<void> _saveField(Profile Function(Profile) update) async {
    final current = _profile;
    if (current == null) return;
    final updated = update(current);
    setState(() {
      _profile = updated;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).update(current.id, updated);
      HapticFeedback.selectionClick();
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardControllerProvider);
    } catch (e) {
      debugPrint('[settings/save] Erro: $e');
      if (mounted) {
        setState(() => _error = 'Não foi possível guardar. Tenta novamente.');
      }
    }
  }

  Future<String?> _editTextDialog({
    required String title,
    required String initial,
    String? hint,
    bool numeric = false,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _editChoiceDialog({
    required String title,
    required List<(String?, String)> options,
    required String? selected,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<String?>(
            groupValue: selected,
            onChanged: (v) => Navigator.pop(context, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, label) in options)
                  RadioListTile<String?>(
                    value: value,
                    title: Text(label),
                    dense: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _profile?.birthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (picked != null) {
      await _saveField((p) => p.copyWith(birthDate: picked));
    }
  }

  Future<void> _editMacros() async {
    final profile = _profile;
    if (profile == null) return;
    final protein = TextEditingController(text: profile.proteinGoalG?.toString() ?? '');
    final carbs = TextEditingController(text: profile.carbsGoalG?.toString() ?? '');
    final fat = TextEditingController(text: profile.fatGoalG?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Metas de macros (g)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: protein,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Proteína',
                        prefixIcon: Icon(Icons.circle, size: 12, color: macroProteinColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbs,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Hidratos',
                        prefixIcon: Icon(Icons.circle, size: 12, color: macroCarbsColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fat,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gordura',
                        prefixIcon: Icon(Icons.circle, size: 12, color: macroFatColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final goal = int.tryParse(
                    protein.text,
                  ); // placeholder para manter o botão com utilidade real
                  if (goal == null || goal <= 0) return;
                  setDialogState(() {
                    protein.text = '${(goal * 0.25 / 4).round()}';
                    carbs.text = '${(goal * 0.45 / 4).round()}';
                    fat.text = '${(goal * 0.30 / 9).round()}';
                  });
                },
                icon: Icon(Icons.auto_awesome, size: 16),
                label: Text('Sugerir (25/45/30%)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _saveField(
                  (p) => p.copyWith(
                    proteinGoalG: int.tryParse(protein.text.trim()),
                    carbsGoalG: int.tryParse(carbs.text.trim()),
                    fatGoalG: int.tryParse(fat.text.trim()),
                  ),
                );
              },
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      mode == ThemeMode.system ? 'system' : mode == ThemeMode.dark ? 'dark' : 'light',
    );
    themeModeNotifier.value = mode;
    if (mounted) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final current = _profile ?? const Profile(id: '');
      final url = await ref.read(profileRepositoryProvider).uploadAvatar(file, userId);
      await ref.read(profileRepositoryProvider).update(
            userId,
            current.copyWith(avatarUrl: url, onboardingCompleted: true),
          );
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardControllerProvider);
      if (mounted) {
        setState(() => _profile = _profile?.copyWith(avatarUrl: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada')),
        );
      }
    } catch (e) {
      debugPrint('[avatar] Erro: $e');
      if (mounted) setState(() => _error = 'Não foi possível atualizar a foto.');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final meals = await ref.read(mealRepositoryProvider).fetchAllMeals(userId);

      final buffer = StringBuffer();
      buffer.writeln('data,refeicao,alimento,calorias,proteina,hidratos,gordura');
      for (final meal in meals) {
        final date = DateFormat('yyyy-MM-dd HH:mm', 'pt_PT').format(meal.consumedAt);
        for (final item in meal.items) {
          buffer.writeln(
            '"$date","${meal.mealName}","${item.name}",${item.calories},'
            '${item.protein ?? ''},${item.carbs ?? ''},${item.fat ?? ''}',
          );
        }
        if (meal.items.isEmpty) {
          buffer.writeln('"$date","${meal.mealName}","",${meal.totalCalories},,,');
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Exportar dados (CSV)'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${meals.length} refeições · '
                    '${buffer.toString().split('\n').length - 1} linhas'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: buffer.toString()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CSV copiado para a área de transferência'),
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copiar CSV'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[exportCsv] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar os dados.')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terminar sessão'),
        content: Text('Tens a certeza que queres sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: appRed),
            child: Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text('Definições')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          _profile ??= data;
          final p = _profile!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _uploadingAvatar ? null : _changeAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surfaceContainerHighest,
                              border: Border.all(color: appGreen, width: 3),
                            ),
                            alignment: Alignment.center,
                            child: p.avatarUrl != null
                                ? ClipOval(
                                    child: SizedBox(
                                      width: 90,
                                      height: 90,
                                      child: Image.network(
                                        p.avatarUrl!,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) =>
                                            progress == null
                                                ? child
                                                : Container(
                                                    color: theme.colorScheme
                                                        .surfaceContainerHighest,
                                                  ),
                                        errorBuilder: (_, _, _) => Icon(
                                          Icons.person,
                                          size: 44,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 44,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: appGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: _uploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      Icons.photo_camera,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.name?.trim().isNotEmpty == true ? p.name!.trim() : 'Sem nome',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email ?? '',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('DADOS PESSOAIS'),
              const SizedBox(height: 6),
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline,
                    label: 'Nome',
                    value: p.name?.trim().isNotEmpty == true ? p.name!.trim() : '—',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Nome',
                        initial: p.name ?? '',
                      );
                      if (value != null && value.trim().isNotEmpty) {
                        await _saveField((x) => x.copyWith(name: value.trim()));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.cake_outlined,
                    label: 'Data de nascimento',
                    value: p.birthDate != null
                        ? DateFormat('d MMM yyyy', 'pt_PT').format(p.birthDate!)
                        : '—',
                    onTap: _editBirthDate,
                  ),
                  _SettingsRow(
                    icon: Icons.person,
                    label: 'Sexo',
                    value: p.sex != null ? sexLabels[p.sex]! : 'Não definido',
                    onTap: () async {
                      final value = await _editChoiceDialog(
                        title: 'Sexo',
                        options: [
                          ('male', 'Masculino'),
                          ('female', 'Feminino'),
                          (null, 'Prefiro não dizer'),
                        ],
                        selected: p.sex,
                      );
                      if (value != p.sex) {
                        await _saveField((x) => x.copyWith(sex: value));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('CORPO'),
              const SizedBox(height: 6),
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon: Icons.height,
                    label: 'Altura',
                    value: p.heightCm != null ? '${p.heightCm!.round()} cm' : '—',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Altura (cm)',
                        initial: p.heightCm?.toString() ?? '',
                        numeric: true,
                      );
                      if (value != null) {
                        await _saveField((x) => x.copyWith(
                              heightCm: double.tryParse(value.trim()),
                            ));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Peso',
                    value: p.weightKg != null ? '${p.weightKg!.toStringAsFixed(1)} kg' : '—',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Peso (kg)',
                        initial: p.weightKg?.toString() ?? '',
                        numeric: true,
                      );
                      if (value != null) {
                        await _saveField((x) => x.copyWith(
                              weightKg: double.tryParse(value.trim()),
                            ));
                      }
                    },
                  ),
_SettingsRow(
                    icon: Icons.flag_outlined,
                    label: 'Peso alvo',
                    value: p.targetWeightKg != null
                        ? '${p.targetWeightKg!.toStringAsFixed(1)} kg'
                        : '—',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Peso alvo (kg)',
                        initial: p.targetWeightKg?.toString() ?? '',
                        numeric: true,
                      );
                      if (value != null) {
                        await _saveField((x) => x.copyWith(
                              targetWeightKg: double.tryParse(value.trim()),
                            ));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.water_drop_outlined,
                    label: 'Meta de água',
                    value: '${p.waterGoalCups} copos · ${p.waterGoalCups * 250} ml',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Meta de água (copos)',
                        initial: '${p.waterGoalCups}',
                        numeric: true,
                      );
                      final cups = int.tryParse(value?.trim() ?? '');
                      if (cups != null && cups > 0 && cups <= 30) {
                        await _saveField((x) => x.copyWith(waterGoalCups: cups));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('OBJETIVOS'),
              const SizedBox(height: 6),
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon: Icons.track_changes,
                    label: 'Objetivo',
                    value: objectiveLabels[p.objective] ?? 'Manter peso',
                    onTap: () async {
                      final value = await _editChoiceDialog(
                        title: 'Objetivo',
                        options: [
                          for (final e in objectiveLabels.entries) (e.key, e.value),
                        ],
                        selected: p.objective,
                      );
                      if (value != null && value != p.objective) {
                        await _saveField((x) => x.copyWith(objective: value));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.directions_run,
                    label: 'Atividade física',
                    value: p.activityLevel != null
                        ? activityLabels[p.activityLevel] ?? '—'
                        : 'Não definido',
                    onTap: () async {
                      final value = await _editChoiceDialog(
                        title: 'Atividade física',
                        options: [
                          (null, 'Não definido'),
                          for (final e in activityLabels.entries) (e.key, e.value),
                        ],
                        selected: p.activityLevel,
                      );
                      if (value != p.activityLevel) {
                        await _saveField((x) => x.copyWith(activityLevel: value));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Meta de calorias',
                    value: '${p.dailyGoalCalories} kcal',
                    onTap: () async {
                      final value = await _editTextDialog(
                        title: 'Meta diária (kcal)',
                        initial: '${p.dailyGoalCalories}',
                        numeric: true,
                      );
                      final goal = int.tryParse(value?.trim() ?? '');
                      if (goal != null && goal > 0) {
                        await _saveField((x) => x.copyWith(dailyGoalCalories: goal));
                      }
                    },
                  ),
                  _SettingsRow(
                    icon: Icons.egg_outlined,
                    label: 'Metas de macros',
                    value: p.proteinGoalG != null || p.carbsGoalG != null || p.fatGoalG != null
                        ? 'P ${p.proteinGoalG ?? '—'} · H ${p.carbsGoalG ?? '—'} · G ${p.fatGoalG ?? '—'}'
                        : 'Não definidas',
                    onTap: _editMacros,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('APARÊNCIA'),
              const SizedBox(height: 6),
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon: Icons.brightness_6_outlined,
                    label: 'Tema',
                    value: themeModeNotifier.value == ThemeMode.dark
                        ? 'Escuro'
                        : themeModeNotifier.value == ThemeMode.light
                            ? 'Claro'
                            : 'Sistema',
                    onTap: () async {
                      final value = await _editChoiceDialog(
                        title: 'Tema',
                        options: const [
                          (null, 'Sistema'),
                          ('light', 'Claro'),
                          ('dark', 'Escuro'),
                        ],
                        selected: themeModeNotifier.value == ThemeMode.dark
                            ? 'dark'
                            : themeModeNotifier.value == ThemeMode.light
                                ? 'light'
                                : null,
                      );
                      if (value == 'dark') {
                        await _setThemeMode(ThemeMode.dark);
                      } else if (value == 'light') {
                        await _setThemeMode(ThemeMode.light);
                      } else if (value == null) {
                        await _setThemeMode(ThemeMode.system);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('DADOS'),
              const SizedBox(height: 6),
              _SettingsSection(
                children: [
                  _SettingsRow(
                    icon: Icons.file_download_outlined,
                    label: 'Exportar dados (CSV)',
                    onTap: _exportCsv,
                  ),
                  _SettingsRow(
                    icon: Icons.logout,
                    label: 'Terminar sessão',
                    destructive: true,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: appRed),
                ),
              ],
              const SizedBox(height: 24),
Center(
                child: Text(
                  'NutriTrack · v1.0',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;

  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
        return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: theme.colorScheme.outlineVariant,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
        final color = destructive ? appRed : appGreen;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: destructive
                      ? appRed
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 17,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}