import 'package:flutter/widgets.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'dashed.dart';

/// Rond, initiale, fond pastel propre à la personne. `person == null` =
/// « Non assigné ». `dashed` : l'intervenant sur les cartes.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    this.person,
    this.size = 24,
    this.dashed = false,
  });

  final Person? person;
  final double size;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final initial = person?.initial ?? '?';
    final circle = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: person?.color ?? T.unassigned,
          shape: dashed
              ? const CircleBorder()
              : const CircleBorder(
                  side: BorderSide(color: T.ink, width: T.borderWidth),
                ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: size * 0.44,
              fontWeight: FontWeight.w800,
              color: T.ink,
              height: 1,
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: person?.name ?? 'Non assigné',
      image: true,
      child: dashed ? DashedBorder(circle: true, child: circle) : circle,
    );
  }
}

/// Les votants dans le pied du tiroir : avatars qui se chevauchent.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.people, this.max = 4});

  final List<Person> people;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const size = 24.0;
    const overlap = 7.0;
    // Un `Stack` plutôt qu'un `Transform` : le chevauchement doit aussi
    // réduire la largeur occupée.
    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * (size - overlap),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: PersonAvatar(person: shown[i], size: size),
            ),
        ],
      ),
    );
  }
}
