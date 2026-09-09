import '../widgets/stub_icon.dart';

/// Keys a `Category`'s `icon` field can hold — kept in sync by hand with
/// the `icon` check constraint in the `category_icon_color` migration.
/// Order here is the order the icon picker on AddCategoryScreen shows
/// them in; `tag` (the DB default for a category with no explicit pick)
/// comes first as the generic/fallback choice.
const categoryIconKeys = [
  'tag', 'cart', 'car', 'home', 'heart', 'film', 'bag', 'coffee',
  'plane', 'book', 'bolt', 'dumbbell', 'paw', 'gift', 'phone', 'wallet',
];

/// Raw SVG data for a category icon key, falling back to the generic tag
/// icon for any unrecognized/legacy value.
String categoryIconData(String key) => switch (key) {
      'cart' => StubIcons.cart,
      'car' => StubIcons.car,
      'home' => StubIcons.home,
      'heart' => StubIcons.heart,
      'film' => StubIcons.film,
      'bag' => StubIcons.bag,
      'coffee' => StubIcons.coffee,
      'plane' => StubIcons.plane,
      'book' => StubIcons.book,
      'bolt' => StubIcons.bolt,
      'dumbbell' => StubIcons.dumbbell,
      'paw' => StubIcons.paw,
      'gift' => StubIcons.gift,
      'phone' => StubIcons.phone,
      'wallet' => StubIcons.wallet,
      _ => StubIcons.tag,
    };
