import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';

/// De quanto em quanto tempo os cards andam sozinhos.
const intervaloDoGiro = Duration(seconds: 4);
const larguraDoCard = 240.0;
const espacoEntreCards = 12.0;

/// Quanto a rolagem anda a cada giro: um card e o espaço até o próximo.
const passoDoGiro = larguraDoCard + espacoEntreCards;

const _aporteMinimo = 50;
const _aporteMaximo = 100000;
const _aporteInvalido = 'Escolha um valor entre R\$ 50 e R\$ 100.000.';
const _aporteDaSobraZero = 100;

/// Ícone e linha de baixo do nome de cada card de renda fixa.
const _visuaisDaRendaFixa = <String, ({IconData icone, String grupo})>{
  'tesouro_selic': (icone: Icons.account_balance_rounded, grupo: 'Título do governo'),
  'cdb': (icone: Icons.savings_rounded, grupo: 'Empréstimo ao banco'),
  'lci_lca': (icone: Icons.home_work_rounded, grupo: 'Sem imposto de renda'),
  'poupanca': (icone: Icons.paid_rounded, grupo: 'Para comparar'),
  'tesouro_prefixado': (icone: Icons.event_rounded, grupo: 'Taxa fixa'),
  'tesouro_ipca': (icone: Icons.shield_rounded, grupo: 'Protege da inflação'),
};

String _porcentagem(num valor) => valor.toStringAsFixed(2).replaceAll('.', ',');

String _variacao(num valor) => '${valor > 0 ? '+' : ''}${_porcentagem(valor)}% hoje';

/// Onde a sobra pode render: cards que giram sozinhos, as moedas do dia e o caminho até o consultor.
class SecaoInvestimentos extends StatefulWidget {
  const SecaoInvestimentos({
    super.key,
    required this.mercado,
    required this.erro,
    required this.carregando,
    required this.sobraDoMes,
    required this.aoCarregar,
    required this.aoPerguntar,
  });

  final Dados? mercado;
  final String? erro;
  final bool carregando;

  /// Sobra do mês aberto: zero ou negativa muda a frase do aporte.
  final double? sobraDoMes;

  /// null pede de novo com o mesmo aporte ("Tentar de novo"); um valor troca o aporte.
  final ValueChanged<int?> aoCarregar;

  /// null abre o consultor sem pergunta; um texto abre e envia.
  final ValueChanged<String?> aoPerguntar;

  @override
  State<SecaoInvestimentos> createState() => _EstadoSecaoInvestimentos();
}

class _EstadoSecaoInvestimentos extends State<SecaoInvestimentos> {
  final _rolagem = ScrollController();
  Timer? _giro;
  bool _pausado = false;
  bool _mouseEmCima = false;
  bool _focoDentro = false;

  /// A pessoa rolou: o próximo giro espera uma volta.
  bool _esperarUmaVolta = false;
  int _atual = 0;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(() {
      final atual = (_rolagem.offset / passoDoGiro).round();
      if (atual != _atual) setState(() => _atual = atual);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Com as animações desligadas no sistema, nada se mexe sozinho.
    if (MediaQuery.disableAnimationsOf(context)) {
      _giro?.cancel();
      _giro = null;
    } else {
      _giro ??= Timer.periodic(intervaloDoGiro, (_) => _girar());
    }
  }

  @override
  void dispose() {
    _giro?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  void _girar() {
    if (_pausado || _mouseEmCima || _focoDentro || !_rolagem.hasClients) return;
    if (_esperarUmaVolta) {
      _esperarUmaVolta = false;
      return;
    }
    final posicao = _rolagem.position;
    final destino = posicao.pixels >= posicao.maxScrollExtent - 1
        ? 0.0
        : math.min(posicao.pixels + passoDoGiro, posicao.maxScrollExtent);
    _rolagem.animateTo(destino, duration: Movimento.de(context, Movimento.medio), curve: Movimento.saida);
  }

  Future<void> _trocarAporte(int atual) async {
    final novo = await showDialog<int>(context: context, builder: (_) => _DialogoDoAporte(atual: atual));
    if (novo != null) widget.aoCarregar(novo);
  }

  @override
  Widget build(BuildContext context) {
    final mercado = widget.mercado;
    final animar = _giro != null;
    final cores = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => _mouseEmCima = true,
      onExit: (_) => _mouseEmCima = false,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (dentro) => _focoDentro = dentro,
        child: Secao(
          titulo: 'Onde sua sobra pode render',
          acoes: [
            if (animar && mercado != null)
              IconButton(
                tooltip: _pausado ? 'Continuar o giro' : 'Pausar o giro',
                onPressed: () => setState(() => _pausado = !_pausado),
                style: IconButton.styleFrom(side: BorderSide(color: cores.outlineVariant)),
                icon: Icon(_pausado ? Icons.play_arrow_rounded : Icons.pause_rounded, color: cores.onSurfaceVariant),
              ),
            const SizedBox(width: Espaco.pequeno),
            // Em janela estreita o texto não cabe ao lado do título: fica só o ícone, com a mesma dica.
            if (MediaQuery.sizeOf(context).width < Largura.media)
              IconButton(
                tooltip: 'Perguntar ao consultor',
                onPressed: () => widget.aoPerguntar(null),
                icon: Icon(Icons.chat_bubble_outline_rounded, color: cores.secondary),
              )
            else
              TextButton.icon(
                onPressed: () => widget.aoPerguntar(null),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Perguntar ao consultor'),
              ),
          ],
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mercado != null) ...[
                _linhaDoAporte(mercado),
                if (mercado['desatualizado'] == true)
                  _AvisoDeDesatualizado(atualizadoEm: mercado['atualizado_em'] as String),
                if (widget.erro != null)
                  Text(widget.erro!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cores.error)),
                const SizedBox(height: Espaco.medio),
                _cards(mercado),
                const SizedBox(height: Espaco.pequeno),
                _Pontos(quantidade: (mercado['cards'] as List).length, atual: _atual),
                _Moedas(moedas: List<Dados>.from(mercado['moedas'] as List)),
              ] else if (widget.erro != null && !widget.carregando)
                _FaixaDeErro(aoTentarDeNovo: () => widget.aoCarregar(null))
              else
                const _Esqueleto(),
              const SizedBox(height: Espaco.medio),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cores.onSurfaceVariant),
                  const SizedBox(width: Espaco.pequeno - 2),
                  Expanded(
                    child: Text(
                      'Valores estimados com os dados de hoje, já sem imposto. Não é recomendação de investimento.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaDoAporte(Dados mercado) {
    final aporte = mercado['aporte'] as int;
    final textos = Theme.of(context).textTheme;
    final estilo = textos.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final semSobra = (widget.sobraDoMes ?? 1) <= 0 && aporte == _aporteDaSobraZero;
    final botao = Semantics(
      button: true,
      hint: 'Trocar o valor por mês',
      child: InkWell(
        onTap: () => _trocarAporte(aporte),
        borderRadius: BorderRadius.circular(Raio.pequeno),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espaco.minimo, vertical: 2),
          child: Text(
            formatarReais(aporte, centavos: false),
            style: estilo?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
      ),
    );
    return Wrap(
      spacing: Espaco.minimo,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: semSobra
          ? [
              Text('Este mês não sobrou dinheiro. Veja quanto renderiam', style: estilo),
              botao,
              Text('por mês.', style: estilo),
            ]
          : [Text('Simulação com', style: estilo), botao, Text('por mês, por 12 meses', style: estilo)],
    );
  }

  Widget _cards(Dados mercado) {
    final cards = List<Dados>.from(mercado['cards'] as List);
    final aporte = mercado['aporte'] as int;
    return RolagemHorizontal(
      controle: _rolagem,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (_) {
          _esperarUmaVolta = true;
          return false;
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (indice, card) in cards.indexed) ...[
                if (indice > 0) const SizedBox(width: espacoEntreCards),
                SizedBox(
                  width: larguraDoCard,
                  child: _CardDeInvestimento(
                    key: ValueKey('card-${card['id']}'),
                    card: card,
                    aporte: aporte,
                    aoPerguntar: widget.aoPerguntar,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardDeInvestimento extends StatelessWidget {
  const _CardDeInvestimento({super.key, required this.card, required this.aporte, required this.aoPerguntar});

  final Dados card;
  final int aporte;
  final ValueChanged<String?> aoPerguntar;

  String get _grupo => card['grupo'] as String;
  bool get _rendaFixa => _grupo == 'renda_fixa';

  TextSpan _textoDasCotas(int cotas) {
    final valor = formatarReais(aporte, centavos: false);
    if (cotas == 0) return TextSpan(text: 'A cota custa mais que $valor');
    return TextSpan(children: [
      const TextSpan(text: 'Compra '),
      TextSpan(text: '$cotas ${cotas == 1 ? 'cota' : 'cotas'}', style: const TextStyle(fontWeight: FontWeight.w800)),
      TextSpan(text: ' com $valor'),
    ]);
  }

  String _pergunta() => _rendaFixa
      ? 'Vale a pena colocar ${formatarReais(aporte, centavos: false)} por mês no ${card['nome']}?'
      : 'Como o ${card['codigo']} se compara com as outras opções para mim?';

  List<String> _pilulas() => [
        if (card['referencia'] == true) 'Taxa de referência',
        'Risco ${const {'baixo': 'baixo', 'medio': 'médio', 'alto': 'alto'}[card['risco']]}',
        switch (card['garantia']) {
          'governo' => 'Garantia do governo',
          'fgc' => 'Garantia do FGC',
          _ => 'Sem garantia',
        },
        if (!_rendaFixa) 'Sem dados de rendimento',
      ];

  Widget _icone() {
    final visual = switch (_grupo) {
      'fii' => (cor: visualDaCategoria('Fatura do cartão').cor, icone: Icons.apartment_rounded),
      'acao' => (cor: visualDaCategoria('Compras').cor, icone: Icons.show_chart_rounded),
      _ => (
          cor: visualDaCategoria('Investimentos').cor,
          icone: _visuaisDaRendaFixa[card['id']]?.icone ?? Icons.savings_rounded
        ),
    };
    final icone = _IconeDoGrupo(icone: visual.icone, cor: visual.cor);
    final logo = card['logo'] as String?;
    if (logo == null) return icone;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Raio.pequeno),
      child: SvgPicture.string(
        logo,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => icone,
        errorBuilder: (_, __, ___) => icone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final financeiras = context.coresFinanceiras;
    final secundario = textos.bodySmall?.copyWith(color: cores.onSurfaceVariant);
    final variacao = card['variacao_dia'] as num?;
    final grupo = switch (_grupo) {
      'fii' => 'Fundo imobiliário',
      'acao' => 'Ação',
      _ => _visuaisDaRendaFixa[card['id']]?.grupo ?? 'Renda fixa',
    };
    return Semantics(
      container: true,
      label: _rendaFixa
          ? '${card['nome']}, ${_porcentagem(card['taxa_ao_ano'] as num)}% ao ano, rende '
              '${formatarReais(card['rendimento_12_meses'] as num)} em 12 meses. ${card['premissa']}'
          : '${card['codigo']}, ${formatarReais(card['cotacao'] as num)} por cota. ${card['premissa']}',
      child: Container(
        decoration: BoxDecoration(
          color: cores.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Raio.medio),
          border: Border.all(color: cores.outlineVariant),
        ),
        padding: const EdgeInsets.all(Espaco.medio),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _icone(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card['nome'] as String, style: textos.titleSmall),
                      Text(grupo, style: secundario),
                    ],
                  ),
                ),
                // Discreto: só o ícone, que ganha a cor de ação ao passar o mouse.
                IconButton(
                  tooltip: 'Perguntar ao consultor sobre ${card['nome']}',
                  onPressed: () => aoPerguntar(_pergunta()),
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: cores.onSurfaceVariant,
                  hoverColor: cores.secondary.withValues(alpha: 0.08),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: Espaco.pequeno + Espaco.minimo),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: _rendaFixa
                      ? '${_porcentagem(card['taxa_ao_ano'] as num)}% '
                      : '${formatarReais(card['cotacao'] as num)} ',
                ),
                TextSpan(
                  text: _rendaFixa ? 'ao ano' : 'por cota',
                  style: textos.titleSmall?.copyWith(color: cores.onSurfaceVariant),
                ),
              ]),
              style: textos.headlineSmall,
            ),
            if (_rendaFixa)
              Text(card['detalhe_da_taxa'] as String,
                  style: textos.labelMedium?.copyWith(color: cores.onSurfaceVariant))
            else if (variacao != null)
              Text(
                _variacao(variacao),
                style: textos.labelMedium?.copyWith(
                  color: variacao == 0 ? cores.onSurfaceVariant : financeiras.doValor(variacao),
                ),
              ),
            const SizedBox(height: Espaco.pequeno),
            Text.rich(
              _rendaFixa
                  ? TextSpan(children: [
                      const TextSpan(text: 'Rende '),
                      TextSpan(
                        text: '+${formatarReais(card['rendimento_12_meses'] as num)}',
                        style: TextStyle(color: financeiras.positivo, fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' em 12 meses'),
                    ])
                  : _textoDasCotas(card['cotas'] as int),
              style: textos.bodyMedium,
            ),
            const SizedBox(height: Espaco.pequeno),
            Wrap(
              spacing: Espaco.minimo,
              runSpacing: Espaco.minimo,
              children: [for (final pilula in _pilulas()) _Pilula(texto: pilula)],
            ),
            const SizedBox(height: Espaco.pequeno),
            Text('${card['resgate']}.', style: textos.labelSmall?.copyWith(color: cores.onSurfaceVariant)),
            const SizedBox(height: Espaco.minimo),
            Text(card['premissa'] as String, style: textos.labelSmall?.copyWith(color: cores.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _IconeDoGrupo extends StatelessWidget {
  const _IconeDoGrupo({required this.icone, required this.cor});

  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(Raio.pequeno),
        ),
        child: Icon(icone, color: cor, size: 22),
      );
}

class _Pilula extends StatelessWidget {
  const _Pilula({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Espaco.minimo),
      decoration: BoxDecoration(color: cores.surfaceContainerHigh, borderRadius: BorderRadius.circular(Raio.pilula)),
      child: Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cores.onSurfaceVariant)),
    );
  }
}

/// Um ponto por card; o do card à esquerda fica largo. Só mostra a posição.
class _Pontos extends StatelessWidget {
  const _Pontos({required this.quantidade, required this.atual});

  final int quantidade;
  final int atual;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < quantidade; i++)
            AnimatedContainer(
              duration: Movimento.de(context, Movimento.rapido),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == atual ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == atual ? cores.secondary : cores.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// As três primeiras moedas ficam à vista; "Ver mais moedas" abre as outras, separadas entre moedas e criptomoedas.
class _Moedas extends StatefulWidget {
  const _Moedas({required this.moedas});

  final List<Dados> moedas;

  @override
  State<_Moedas> createState() => _EstadoMoedas();
}

class _EstadoMoedas extends State<_Moedas> {
  static const _aVista = 3;
  bool _aberto = false;

  Widget _grupo(String titulo, List<Dados> moedas) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Espaco.pequeno),
          Text(
            titulo,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Espaco.minimo + 2),
          _linha(moedas),
        ],
      );

  Widget _linha(List<Dados> moedas) => Wrap(
        spacing: Espaco.pequeno,
        runSpacing: Espaco.pequeno,
        children: [for (final moeda in moedas) _PilulaDaMoeda(moeda: moeda)],
      );

  @override
  Widget build(BuildContext context) {
    final moedas = widget.moedas;
    if (moedas.isEmpty) return const SizedBox.shrink();
    final textos = Theme.of(context).textTheme;
    final escondidas = moedas.length - _aVista;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Espaco.medio),
        Text('Moedas hoje', style: textos.titleSmall),
        const SizedBox(height: Espaco.pequeno),
        AnimatedSize(
          duration: Movimento.de(context, Movimento.medio),
          curve: Movimento.saida,
          alignment: Alignment.topLeft,
          child: _aberto
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _grupo('Moedas', [
                      for (final m in moedas)
                        if (m['cripto'] != true) m
                    ]),
                    _grupo('Criptomoedas', [
                      for (final m in moedas)
                        if (m['cripto'] == true) m
                    ]),
                  ],
                )
              : _linha(moedas.take(_aVista).toList()),
        ),
        if (escondidas > 0)
          TextButton.icon(
            onPressed: () => setState(() => _aberto = !_aberto),
            icon: Icon(_aberto ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_aberto ? 'Mostrar menos' : 'Ver mais moedas ($escondidas)'),
          ),
      ],
    );
  }
}

class _PilulaDaMoeda extends StatelessWidget {
  const _PilulaDaMoeda({required this.moeda});

  final Dados moeda;

  /// Bitcoin em "mil"; peso argentino e iene, com as casas que fazem sentido (R$ 0,0036).
  static String _valor(num valor) {
    if (valor >= 10000) return '${formatarReais(valor / 1000, centavos: false)} mil';
    if (valor < 1) return 'R\$ ${valor.toStringAsFixed(4).replaceAll('.', ',')}';
    return formatarReais(valor);
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final variacao = moeda['variacao_dia'] as num;
    final codigo = moeda['codigo'] as String;
    final semIcone = Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: cores.outlineVariant, shape: BoxShape.circle),
      child: FittedBox(child: Text(codigo, style: textos.labelSmall)),
    );
    final icone = moeda['icone'] as String?;
    return Container(
      key: ValueKey('moeda-$codigo'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Espaco.pequeno),
      decoration: BoxDecoration(color: cores.surfaceContainerHigh, borderRadius: BorderRadius.circular(Raio.pilula)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone == null)
            semIcone
          else
            ClipOval(
              child: SvgPicture.string(
                icone,
                width: 22,
                height: 22,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => semIcone,
                errorBuilder: (_, __, ___) => semIcone,
              ),
            ),
          const SizedBox(width: Espaco.pequeno),
          Flexible(
            child: Text(
              '${moeda['nome']} ${_valor(moeda['valor'] as num)}',
              style: textos.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Espaco.pequeno),
          Text(
            '${variacao > 0 ? '+' : ''}${_porcentagem(variacao)}%',
            style: textos.labelLarge?.copyWith(color: context.coresFinanceiras.doValor(variacao)),
          ),
        ],
      ),
    );
  }
}

class _AvisoDeDesatualizado extends StatelessWidget {
  const _AvisoDeDesatualizado({required this.atualizadoEm});

  final String atualizadoEm;

  @override
  Widget build(BuildContext context) {
    final momento = DateTime.parse(atualizadoEm);
    String dois(int numero) => numero.toString().padLeft(2, '0');
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Espaco.minimo),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: cores.onSurfaceVariant),
          const SizedBox(width: Espaco.pequeno - 2),
          Expanded(
            child: Text(
              'Taxas de ${dois(momento.day)}/${dois(momento.month)} às ${dois(momento.hour)}:${dois(momento.minute)}. '
              'Sem conexão para atualizar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cores.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaixaDeErro extends StatelessWidget {
  const _FaixaDeErro({required this.aoTentarDeNovo});

  final VoidCallback aoTentarDeNovo;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: Espaco.medio),
      padding: const EdgeInsets.fromLTRB(Espaco.medio, Espaco.pequeno, Espaco.pequeno, Espaco.pequeno),
      decoration: BoxDecoration(color: cores.errorContainer, borderRadius: BorderRadius.circular(Raio.medio)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: cores.onErrorContainer),
          const SizedBox(width: Espaco.pequeno + Espaco.minimo),
          Expanded(
            child: Text(
              'Não foi possível buscar as taxas agora.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cores.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: aoTentarDeNovo,
            style: TextButton.styleFrom(foregroundColor: cores.onErrorContainer),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('esqueleto-dos-investimentos'),
        padding: const EdgeInsets.only(top: Espaco.medio),
        child: Semantics(
          label: 'Buscando as taxas de hoje',
          child: ClipRect(
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: espacoEntreCards),
                  Container(
                    width: larguraDoCard,
                    height: 260,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(Raio.medio),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Pede o novo valor por mês; só fecha com um inteiro de 50 a 100.000.
class _DialogoDoAporte extends StatefulWidget {
  const _DialogoDoAporte({required this.atual});

  final int atual;

  @override
  State<_DialogoDoAporte> createState() => _EstadoDialogoDoAporte();
}

class _EstadoDialogoDoAporte extends State<_DialogoDoAporte> {
  late final _campo = TextEditingController(text: '${widget.atual}');
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _confirmar() {
    // "1.000" e "R$ 1.000" valem; vírgula continua recusada, porque o valor é em reais inteiros.
    final valor = int.tryParse(_campo.text.replaceAll(RegExp(r'R\$|\s|\.'), ''));
    if (valor == null || valor < _aporteMinimo || valor > _aporteMaximo) {
      setState(() => _erro = _aporteInvalido);
      return;
    }
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quanto por mês?'),
        content: TextField(
          controller: _campo,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (_erro != null) setState(() => _erro = null);
          },
          onSubmitted: (_) => _confirmar(),
          decoration: InputDecoration(prefixText: 'R\$ ', errorText: _erro, helperText: 'De R\$ 50 a R\$ 100.000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _confirmar, child: const Text('Simular')),
        ],
      );
}
