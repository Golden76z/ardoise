import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:ardoise/theme/tokens.dart';
import 'package:ardoise/widgets/avatar.dart';
import 'package:ardoise/widgets/dashed.dart';
import 'package:ardoise/widgets/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _lea = Person(id: 'L', name: 'Léa', color: Color(0xFFF8C2BC));

Widget _host(Widget child) => MaterialApp(
  theme: buildArdoiseTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('le thème porte la police Sour Gummy et le fond crème', (
    tester,
  ) async {
    final theme = buildArdoiseTheme();
    expect(theme.scaffoldBackgroundColor, T.bg);
    expect(theme.textTheme.bodyMedium?.fontFamily, contains('SourGummy'));
  });

  testWidgets('avatar : initiale de la personne et libellé accessible', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PersonAvatar(person: _lea)));
    expect(find.text('L'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PersonAvatar)).label,
      contains('Léa'),
    );
  });

  testWidgets('avatar sans personne : « ? » et « Non assigné »', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PersonAvatar()));
    expect(find.text('?'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PersonAvatar)).label,
      contains('Non assigné'),
    );
  });

  testWidgets('la pile d’avatars se limite à `max`', (tester) async {
    await tester.pumpWidget(
      _host(
        AvatarStack(
          people: const [
            _lea,
            Person(id: 'K', name: 'Karim', color: Color(0xFFF8CFA2)),
            Person(id: 'T', name: 'Tom', color: Color(0xFFCBE4B6)),
            Person(id: 'I', name: 'Inès', color: Color(0xFFF6E19A)),
            Person(id: 'D', name: 'Damien', color: Color(0xFFEFC4A6)),
          ],
          max: 3,
        ),
      ),
    );
    expect(find.byType(PersonAvatar), findsNWidgets(3));
  });

  testWidgets('le bouton pilule appelle onPressed, et rien quand il est nul', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PillButton(label: '+ Demande', onPressed: () => taps++)),
    );
    await tester.tap(find.text('+ Demande'));
    expect(taps, 1);

    await tester.pumpWidget(
      _host(const PillButton(label: '+ Demande', onPressed: null)),
    );
    await tester.tap(find.text('+ Demande'));
    expect(taps, 1, reason: 'bouton désactivé : aucun appel');
  });

  testWidgets('le compteur affiche son nombre', (tester) async {
    await tester.pumpWidget(_host(const CountBadge(7)));
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('ChoicePill : avec avatar, sans avatar, et sélection', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChoicePill(
              label: 'En revue',
              selected: true,
              fill: T.statusColor(RequestStatus.review),
              onTap: () => taps++,
            ),
            ChoicePill(
              label: 'Léa',
              avatar: _lea,
              selected: false,
              fill: T.accentSoft,
              onTap: () {},
            ),
            ChoicePill(
              label: 'Personne',
              showAvatar: true,
              selected: false,
              fill: T.accentSoft,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(find.text('En revue'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('En revue')),
      isSemantics(isSelected: true),
    );
    await tester.tap(find.text('En revue'));
    expect(taps, 1);
  });

  testWidgets('InkOutline porte un contour encre et le rayon demandé', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const InkOutline(radius: T.rCard, color: T.surface, child: Text('x')),
      ),
    );
    final decoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byType(InkOutline),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(T.rCard));
    expect(decoration.color, T.surface);
  });

  testWidgets('le fond pointillé se peint sans erreur', (tester) async {
    await tester.pumpWidget(_host(const DottedBackground(child: Text('fond'))));
    expect(find.text('fond'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('les contours pointillés se peignent sans erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DashedBorder(radius: T.rChip, child: Text('puce')),
            DashedBorder(circle: true, child: SizedBox(width: 28, height: 28)),
            SizedBox(width: 120, child: DashedDivider()),
          ],
        ),
      ),
    );
    expect(find.text('puce'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
