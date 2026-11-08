import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../estado_conversa.dart';
import '../formatacao.dart';
import '../tema.dart';
import 'componentes.dart';
import 'secao_dicas.dart';

const _sugestoes = [
  'Onde dá para economizar?',
  'Quanto posso guardar sem apertar?',
  'Como meus gastos mudaram nos últimos meses?',
];

/// Conversa com o consultor sobre o seu dinheiro, com o histórico. Quem usa decide o tamanho, a posição e a superfície.
class PainelConsultor extends StatefulWidget {
  const PainelConsultor({super.key, required this.estado, required this.aoFechar, this.aberto = true});

  final EstadoConversa estado;
  final VoidCallback aoFechar;

  /// Quem usa pode manter o painel montado e escondido (para não perder o rascunho): ao abrir, o campo
  /// recebe o foco, porque o autofocus só vale na primeira montagem.
  final bool aberto;

  @override
  State<PainelConsultor> createState() => _EstadoPainelConsultor();
}

class _EstadoPainelConsultor extends State<PainelConsultor> {
  final _campo = TextEditingController();
  final _foco = FocusNode();
  final _rolagem = ScrollController();

  EstadoConversa get _estado => widget.estado;

  @override
  void initState() {
    super.initState();
    _estado.addListener(_aoMudar);
  }

  @override
  void didUpdateWidget(PainelConsultor antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.estado != widget.estado) {
      antigo.estado.removeListener(_aoMudar);
      widget.estado.addListener(_aoMudar);
    }
    if (widget.aberto && !antigo.aberto) _focarCampo();
  }

  /// Depois do quadro: antes dele o painel ainda está escondido (e fora do foco).
  void _focarCampo() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _foco.requestFocus();
      });

  @override
  void dispose() {
    _estado.removeListener(_aoMudar);
    _campo.dispose();
    _foco.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  /// Redesenha e, depois do quadro, desce até a última mensagem.
  void _aoMudar() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rolagem.hasClients) return;
      final duracao = Movimento.de(context, Movimento.medio);
      final fim = _rolagem.position.maxScrollExtent;
      duracao == Duration.zero
          ? _rolagem.jumpTo(fim)
          : _rolagem.animateTo(fim, duration: duracao, curve: Movimento.saida);
    });
  }

  /// Envia o texto pedido (sugestão) ou o do campo. Se der errado, a pergunta volta para o campo.
  Future<void> _enviar([String? texto]) async {
    final pergunta = (texto ?? _campo.text).trim();
    if (pergunta.isEmpty || _estado.pensando) return;
    _campo.clear();
    final respondeu = await _estado.perguntar(pergunta);
    if (!mounted) return;
    if (!respondeu && _estado.erro != null && _campo.text.isEmpty) _campo.text = pergunta;
    _focarCampo();
  }

  /// Enter envia; Shift+Enter fica com o campo, que quebra a linha.
  KeyEventResult _teclaNoCampo(FocusNode _, KeyEvent evento) {
    final enter = evento.logicalKey == LogicalKeyboardKey.enter || evento.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (evento is! KeyDownEvent || !enter || HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _enviar();
    return KeyEventResult.handled;
  }

  Future<void> _comecarDeNovo() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Começar de novo?'),
        content: const Text('A conversa deste mês será apagada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(contexto).colorScheme.error,
              foregroundColor: Theme.of(contexto).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Apagar conversa'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _estado.comecarDeNovo();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final pensando = _estado.pensando;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.aoFechar},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.medio, Espaco.pequeno, Espaco.pequeno),
            child: Row(children: [
              Expanded(
                child: Text('Consultor', maxLines: 1, overflow: TextOverflow.ellipsis, style: textos.titleLarge),
              ),
              IconButton(
                tooltip: 'Começar de novo',
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: _estado.mensagens.isEmpty || pensando ? null : _comecarDeNovo,
              ),
              IconButton(tooltip: 'Fechar', icon: const Icon(Icons.close_rounded), onPressed: widget.aoFechar),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: _rolagem,
              padding: const EdgeInsets.all(Espaco.grande),
              children: [
                if (_estado.mensagens.isEmpty && _estado.pendente == null)
                  _Vazio(habilitado: !pensando, aoEscolher: _enviar),
                for (final (indice, mensagem) in _estado.mensagens.indexed)
                  EntradaSuave(
                    key: ValueKey('mensagem $indice'),
                    child: mensagem['papel'] == 'pessoa'
                        ? _BalaoDaPessoa(mensagem['texto'] as String)
                        : Semantics(
                            liveRegion: indice == _estado.mensagens.length - 1,
                            child: _RespostaDoConsultor(mensagem['texto'] as String),
                          ),
                  ),
                if (_estado.pendente != null) ...[
                  _BalaoDaPessoa(_estado.pendente!),
                  if (_estado.segundosNaFila case final segundos?)
                    _NaFila(segundos: segundos, progresso: _estado.progressoDaFila)
                  else
                    const _Pensando(),
                ],
                if (_estado.erro != null) ...[
                  Text(_estado.erro!, style: textos.bodyMedium?.copyWith(color: cores.error)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: pensando ? null : _enviar, child: const Text('Tentar de novo')),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.pequeno, Espaco.grande, Espaco.medio),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Focus(
                        onKeyEvent: _teclaNoCampo,
                        child: TextField(
                          controller: _campo,
                          focusNode: _foco,
                          autofocus: true,
                          // Só leitura, e não desabilitado: o campo fica com o foco e o Esc continua fechando.
                          readOnly: pensando,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(hintText: 'Pergunte sobre o seu dinheiro', counterText: ''),
                        ),
                      ),
                    ),
                    const SizedBox(width: Espaco.pequeno),
                    MolaAoPressionar(
                      ativa: !pensando,
                      child: IconButton.filled(
                        tooltip: 'Enviar',
                        icon: const Icon(Icons.arrow_upward_rounded),
                        onPressed: pensando ? null : _enviar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espaco.pequeno),
                Row(children: [
                  Icon(Icons.lock_rounded, size: 16, color: cores.onSurfaceVariant),
                  const SizedBox(width: Espaco.minimo + 2),
                  Expanded(
                    child: Text(
                      'Não escreva CPF, senhas ou nomes de pessoas.',
                      style: textos.labelMedium?.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Antes da primeira pergunta: uma frase de gente e três perguntas prontas.
class _Vazio extends StatelessWidget {
  const _Vazio({required this.habilitado, required this.aoEscolher});

  final bool habilitado;
  final ValueChanged<String> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('O que você quer entender sobre o seu dinheiro?', style: textos.titleMedium),
        const SizedBox(height: Espaco.medio),
        Wrap(
          spacing: Espaco.pequeno,
          runSpacing: Espaco.pequeno,
          children: [
            for (final sugestao in _sugestoes)
              MolaAoPressionar(
                ativa: habilitado,
                child: Material(
                  color: cores.surfaceContainerHigh,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: habilitado ? () => aoEscolher(sugestao) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Espaco.medio - 2, vertical: Espaco.pequeno),
                      child: Text(sugestao, style: textos.labelMedium?.copyWith(color: cores.onSurface)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Pergunta da pessoa: balão à direita, em Trilho, sem coral.
/// Enquanto o consultor responde: "Pensando" com três pontos que pulsam em sequência, como a linha de
/// carregamento do topo. Com as animações desligadas no Windows, fica o texto parado "Pensando…".
class _Pensando extends StatefulWidget {
  const _Pensando();

  @override
  State<_Pensando> createState() => _EstadoPensando();
}

class _EstadoPensando extends State<_Pensando> with SingleTickerProviderStateMixin {
  late final _ciclo = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Movimento.de(context, Movimento.medio) == Duration.zero ? _ciclo.stop() : _ciclo.repeat();
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.onSurfaceVariant;
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cor);
    if (!_ciclo.isAnimating) return Text('Pensando…', style: estilo);
    return Row(children: [
      Text('Pensando', style: estilo),
      const SizedBox(width: Espaco.pequeno),
      AnimatedBuilder(
        key: const ValueKey('pontinhos do pensando'),
        animation: _ciclo,
        builder: (context, _) => Row(children: [
          for (var ponto = 0; ponto < 3; ponto++)
            Padding(
              padding: const EdgeInsets.only(right: Espaco.minimo),
              // Cada ponto acende um terço de ciclo depois do anterior.
              child: Opacity(
                opacity: 0.3 + 0.7 * (1 - ((_ciclo.value - ponto / 3) % 1 * 3).clamp(0, 1)),
                child: PontoDeCor(cor),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// IA ocupada: a pergunta espera a vez, com a contagem e uma barra que enche até sair sozinha.
class _NaFila extends StatelessWidget {
  const _NaFila({required this.segundos, required this.progresso});

  final int segundos;
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.hourglass_top_rounded, size: 18, color: cores.onSurfaceVariant),
          const SizedBox(width: Espaco.pequeno),
          Expanded(
            child: Text(
              'Na fila: sua pergunta sai em $segundos s',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
            ),
          ),
        ]),
        const SizedBox(height: Espaco.pequeno),
        BarraAnimada(fracao: progresso, cor: cores.primary, altura: 6),
      ],
    );
  }
}

class _BalaoDaPessoa extends StatelessWidget {
  const _BalaoDaPessoa(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaco.medio),
      child: LayoutBuilder(
        builder: (context, limites) => Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: limites.maxWidth * 0.85),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cores.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Raio.medio),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espaco.medio, vertical: Espaco.pequeno + 2),
                child: Text(texto, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cores.onSurface)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resposta do consultor como as dicas: parágrafos com os valores em destaque, e linhas "- Nome: R$ 1,00"
/// seguidas viram lista com o valor à direita.
class _RespostaDoConsultor extends StatelessWidget {
  const _RespostaDoConsultor(this.texto);

  final String texto;

  static final _itemDeLista = RegExp(r'^[-•*]\s');

  List<Widget> _blocos() {
    final blocos = <Widget>[];
    var lista = <String>[];
    void fecharLista() {
      if (lista.isEmpty) return;
      final itens = linhasDaDica(lista.join('\n'));
      blocos.addAll(itens.length == 1 ? [TextoDaDica(itens.single.texto)] : itens.map(LinhaDaLista.new));
      lista = [];
    }

    for (final linha in texto.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty)) {
      if (_itemDeLista.hasMatch(linha)) {
        lista.add(linha);
        continue;
      }
      fecharLista();
      blocos.add(Padding(
        padding: EdgeInsets.only(top: blocos.isEmpty ? 0 : Espaco.pequeno),
        child: TextoDaDica(valoresNoPadrao(linha)),
      ));
    }
    fecharLista();
    return blocos;
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Espaco.medio),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocos()),
      );
}
