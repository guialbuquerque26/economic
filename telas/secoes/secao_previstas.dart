import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// Próximas faturas do cartão, de todos os bancos: uma página por mês. Ainda não contam nos gastos.
class SecaoPrevistas extends StatefulWidget {
  const SecaoPrevistas({super.key, required this.previstas});

  final List<Dados> previstas;

  @override
  State<SecaoPrevistas> createState() => _EstadoSecaoPrevistas();
}

class _EstadoSecaoPrevistas extends State<SecaoPrevistas> {
  int _pagina = 0;

  /// Já vêm em ordem de data, então os meses saem em ordem.
  List<MapEntry<String, List<Dados>>> get _meses {
    final meses = <String, List<Dados>>{};
    for (final prevista in widget.previstas) {
      meses.putIfAbsent((prevista['data'] as String).substring(0, 7), () => []).add(prevista);
    }
    return meses.entries.toList();
  }

  Widget _seta(String dica, IconData icone, int destino, int total) {
    final ativa = destino >= 0 && destino < total;
    return MolaAoPressionar(
      ativa: ativa,
      child: IconButton(
        tooltip: dica,
        icon: Icon(icone),
        onPressed: ativa ? () => setState(() => _pagina = destino) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final detalhe = textos.bodySmall?.copyWith(color: cores.onSurfaceVariant);
    final meses = _meses;
    final pagina = _pagina.clamp(0, meses.length - 1); // a lista pode encolher numa busca nova
    final MapEntry(key: mes, value: doMes) = meses[pagina];
    final duracao = Movimento.de(context, Movimento.medio);
    final conteudo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Só entra nos seus gastos quando a data chegar.', style: detalhe),
        const SizedBox(height: Espaco.medio),
        Row(
          children: [
            Expanded(child: Text(formatarMesPorExtenso(mes), style: textos.titleSmall)),
            TextoValor(doMes.fold<num>(0, (soma, p) => soma + (p['valor'] as num)), estilo: textos.titleSmall),
          ],
        ),
        for (final prevista in doMes) _linha(prevista, textos, detalhe),
      ],
    );
    return Secao(
      titulo: 'Próximas faturas',
      acoes: [
        if (meses.length > 1) ...[
          _seta('Mês anterior', Icons.chevron_left_rounded, pagina - 1, meses.length),
          Text('${pagina + 1} de ${meses.length}', style: detalhe),
          _seta('Próximo mês', Icons.chevron_right_rounded, pagina + 1, meses.length),
        ],
      ],
      // A altura muda de um mês para outro e se acomoda aos poucos. AnimatedSize com duração zero
      // se redimensiona no meio do próprio layout e dispara erro.
      filho: duracao == Duration.zero
          ? conteudo
          : AnimatedSize(duration: duracao, curve: Movimento.saida, alignment: Alignment.topCenter, child: conteudo),
    );
  }

  Widget _linha(Dados prevista, TextTheme textos, TextStyle? detalhe) {
    final parcela = prevista['parcela'] as int?;
    final total = prevista['total_parcelas'] as int?;
    final banco = prevista['banco'] as String?;
    final quando = parcela == null || total == null
        ? formatarData(prevista['data'] as String)
        : 'parcela $parcela de $total';
    return Padding(
      padding: const EdgeInsets.only(top: Espaco.pequeno),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeLegivel(prevista['descricao'] as String),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textos.bodyMedium,
                ),
                Text(banco == null ? quando : '$banco · $quando', style: detalhe),
              ],
            ),
          ),
          const SizedBox(width: Espaco.pequeno),
          TextoValor(prevista['valor'] as num, estilo: textos.bodyMedium),
        ],
      ),
    );
  }
}
