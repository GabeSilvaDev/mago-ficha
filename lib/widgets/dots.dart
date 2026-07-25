import 'package:flutter/material.dart';
import '../theme.dart';

/// Linha de bolinhas (estilo OOOOO da ficha). Toca numa bolinha para definir
/// o valor; tocar na bolinha já preenchida no valor atual reduz em 1.
///
/// [max] = quantas bolinhas aparecem (teto absoluto, ex. 5).
/// [maxInterativo] = valor máximo que o toque pode atingir agora (ex. 3 nas
/// habilidades durante a criação). Bolinhas acima disso aparecem, mas travadas.
class LinhaBolinhas extends StatelessWidget {
  final int valor;
  final int max;
  final int min;
  final int? maxInterativo;
  final ValueChanged<int> onChanged;
  const LinhaBolinhas({
    super.key,
    required this.valor,
    required this.onChanged,
    this.max = 5,
    this.min = 0,
    this.maxInterativo,
  });

  @override
  Widget build(BuildContext context) {
    final teto = maxInterativo ?? max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= max; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: i > teto
                ? null
                : () {
                    final novo = (valor == i) ? i - 1 : i;
                    onChanged(novo.clamp(min, teto));
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= valor ? Cores.indigo : Colors.transparent,
                  border: Border.all(
                    color: i > teto ? Colors.grey.shade400 : Cores.dourado,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
