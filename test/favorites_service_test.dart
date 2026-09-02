import 'package:calorie_tracker/models/meal_item.dart';
import 'package:calorie_tracker/services/favorites_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const favorite = FavoriteMeal(
    name: 'Almoço fit',
    imageUrl: 'https://example.com/f.jpg',
    items: [
      MealItem(name: 'Arroz', calories: 200, protein: 4, carbs: 43, fat: 0.5),
      MealItem(name: 'Frango', calories: 350, protein: 40, carbs: 0, fat: 20),
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('toggle adds and removes favorite', () async {
    final service = FavoritesService();

    final afterAdd = await service.toggle(favorite);
    expect(afterAdd.length, 1);
    expect(await service.isFavorite('Almoço fit'), isTrue);

    final afterRemove = await service.toggle(favorite);
    expect(afterRemove, isEmpty);
    expect(await service.isFavorite('Almoço fit'), isFalse);
  });

  test('toggle twice removes (identity by name)', () async {
    final service = FavoritesService();
    await service.toggle(favorite);
    await service.toggle(const FavoriteMeal(
      name: 'Almoço fit',
      items: [MealItem(name: 'Outro', calories: 100)],
    ));
    final favorites = await service.load();
    expect(favorites, isEmpty);
  });

  test('keeps multiple favorites with distinct names', () async {
    final service = FavoritesService();
    await service.toggle(favorite);
    await service.toggle(const FavoriteMeal(
      name: 'Jantar leve',
      items: [MealItem(name: 'Sopa', calories: 120)],
    ));
    final favorites = await service.load();
    expect(favorites.length, 2);
  });

  test('favorite meal serialization roundtrip', () async {
    final service = FavoritesService();
    await service.toggle(favorite);
    final loaded = await service.load();
    expect(loaded.single.name, 'Almoço fit');
    expect(loaded.single.imageUrl, 'https://example.com/f.jpg');
    expect(loaded.single.items.length, 2);
    expect(loaded.single.items.first.calories, 200);
    expect(loaded.single.items.last.protein, 40);
  });
}