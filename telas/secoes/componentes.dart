import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../tema.dart';

/// Superfície branca com cantos grandes e sombra macia. Um assunto por cartão, nunca um cartão dentro do outro.
class Cartao extends StatelessWidget {
  const Cartao({super.key, required this.filho, this.preenchimento = const EdgeInsets.all(Espaco.grande), this.cor});

  final Widget filho;
  final EdgeInsets preenchimento;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cor ?? tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(Raio.grande),
        border: Border.all(color: tema.colorScheme.outlineVariant),
        boxShadow: sombraDoCartao(tema.brightness),
      ),
      child: Padding(padding: preenchimento, child: filho),
    );
  }
}

/// Cartão com título usado por todas as seções do painel.
class Secao extends StatelessWidget {
  const Secao({super.key, required this.titulo, required this.filho, this.acoes = const []});

  final String titulo;
  final Widget filho;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    return Cartao(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Altura fixa: títulos de seções vizinhas ficam alinhados, com ou sem botão ao lado.
          SizedBox(
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: Text(titulo,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                ),
                ...acoes,
              ],
            ),
          ),
          const SizedBox(height: Espaco.pequeno + Espaco.minimo),
          filho,
        ],
      ),
    );
  }
}

/// Logotipo do app: a carteira do ícone do instalador, ao lado do nome.
class Marca extends StatelessWidget {
  const Marca({super.key, this.tamanho = 32, this.estilo, this.comNome = true});

  final double tamanho;
  final TextStyle? estilo;
  final bool comNome;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size.square(tamanho), painter: _Carteira(cores.primary, cores.onPrimary)),
        if (comNome) ...[SizedBox(width: tamanho * 0.3), Text('Economic', style: estilo)],
      ],
    );
  }
}

/// Quadrado coral com a silhueta da carteira. Frações do lado iguais às de instalador/gerar_imagens.py.
class _Carteira extends CustomPainter {
  _Carteira(this.fundo, this.desenho);

  final Color fundo;
  final Color desenho;

  @override
  void paint(Canvas canvas, Size tamanho) {
    canvas.scale(tamanho.shortestSide);
    void bloco(double esquerda, double topo, double direita, double base, double raio, Color cor) =>
        canvas.drawRRect(RRect.fromLTRBR(esquerda, topo, direita, base, Radius.circular(raio)), Paint()..color = cor);
    bloco(0, 0, 1, 1, 0.3, fundo);
    bloco(0.24, 0.24, 0.70, 0.40, 0.06, desenho); // verso
    bloco(0.18, 0.32, 0.82, 0.78, 0.12, desenho); // corpo
    bloco(0.56, 0.46, 0.90, 0.64, 0.09, fundo); // fecho, recortando o corpo
    canvas.drawCircle(const Offset(0.68, 0.55), 0.045, Paint()..color = desenho);
  }

  @override
  bool shouldRepaint(_Carteira antiga) => antiga.fundo != fundo || antiga.desenho != desenho;
}

/// Mola suave ao pressionar: o botão afunda um pouco e volta. Não anima na entrada.
class MolaAoPressionar extends StatefulWidget {
  const MolaAoPressionar({super.key, this.ativa = true, required this.child});

  /// Botão desabilitado não afunda.
  final bool ativa;
  final Widget child;

  @override
  State<MolaAoPressionar> createState() => _EstadoMolaAoPressionar();
}

class _EstadoMolaAoPressionar extends State<MolaAoPressionar> {
  bool _pressionado = false;

  void _marcar(bool pressionado) => setState(() => _pressionado = pressionado);

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _marcar(true),
        onPointerUp: (_) => _marcar(false),
        onPointerCancel: (_) => _marcar(false),
        child: AnimatedScale(
          scale: _pressionado && widget.ativa ? 0.96 : 1,
          duration: Movimento.de(context, Movimento.rapido),
          curve: _pressionado ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

/// Sobe e aparece uma única vez; [ordem] atrasa um pouco cada item de uma lista.
class EntradaSuave extends StatelessWidget {
  const EntradaSuave({super.key, this.ordem = 0, required this.child});

  final int ordem;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final atraso = Movimento.de(context, Duration(milliseconds: 70 * ordem));
    final total = atraso + Movimento.de(context, Movimento.medio);
    final inicio = total == Duration.zero ? 0.0 : atraso.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, valor, filho) => Opacity(
        opacity: valor,
        child: Transform.translate(offset: Offset(0, (1 - valor) * 10), child: filho),
      ),
    );
  }
}

/// Ícone em disco neutro: a cor de categoria fica só nas bolinhas e barras.
class IconeEmCaixa extends StatelessWidget {
  const IconeEmCaixa(this.icone, {super.key, this.tamanho = 32});

  final IconData icone;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: cores.surfaceContainerHigh, shape: BoxShape.circle),
      child: Icon(icone, size: tamanho * 0.56, color: cores.onSurface),
    );
  }
}

/// Círculo com a inicial do nome da pessoa; sem nome, mostra um ícone.
class AvatarDaPessoa extends StatelessWidget {
  const AvatarDaPessoa({super.key, this.nome, this.raio = 20});

  final String? nome;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final inicial = nome == null || nome!.isEmpty ? null : nome![0].toUpperCase();
    return CircleAvatar(
      radius: raio,
      backgroundColor: cores.primaryContainer,
      foregroundColor: cores.onPrimaryContainer,
      child: inicial == null
          ? Icon(Icons.person_rounded, size: raio * 1.1)
          : Text(inicial, style: TextStyle(fontWeight: FontWeight.w800, fontSize: raio * 0.9)),
    );
  }
}

/// Bolinha com a cor da categoria.
class PontoDeCor extends StatelessWidget {
  const PontoDeCor(this.cor, {super.key});

  final Color cor;

  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle));
}

/// Valor em reais com algarismos alinhados; colorido em verde ou vermelho se pedido.
class TextoValor extends StatelessWidget {
  const TextoValor(this.valor, {super.key, this.colorido = false, this.estilo});

  final num valor;
  final bool colorido;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final base = (estilo ?? DefaultTextStyle.of(context).style).copyWith(fontFeatures: algarismosAlinhados);
    return Text(formatarReais(valor),
        style: colorido ? base.copyWith(color: context.coresFinanceiras.doValor(valor)) : base);
  }
}

/// Valor que rola até o número novo quando muda; na primeira vez já aparece pronto.
class ValorAnimado extends StatelessWidget {
  const ValorAnimado(this.valor, {super.key, this.colorido = false, this.estilo});

  final num valor;
  final bool colorido;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: valor.toDouble()),
        duration: Movimento.de(context, Movimento.lento),
        curve: Movimento.saida,
        builder: (context, atual, _) => TextoValor(atual, colorido: colorido, estilo: estilo),
      );
}

/// Barra arredondada que cresce até [fracao] (de 0 a 1) e se acomoda quando o valor muda.
class BarraAnimada extends StatelessWidget {
  const BarraAnimada({super.key, required this.fracao, required this.cor, this.altura = 8});

  final double fracao;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final canto = BorderRadius.circular(Raio.pilula);
    return Container(
      height: altura,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: canto),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fracao.clamp(0, 1)),
        duration: Movimento.de(context, Movimento.lento),
        curve: Movimento.saida,
        builder: (context, atual, _) => FractionallySizedBox(
          widthFactor: atual,
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(color: cor, borderRadius: canto)),
        ),
      ),
    );
  }
}

/// Lista "nome → valor". Em categorias, cada linha ganha a cor da categoria, a parte do total e uma barra.
class ListaValores extends StatelessWidget {
  const ListaValores({super.key, required this.valores, this.deCategorias = false});

  final Dados valores;
  final bool deCategorias;

  @override
  Widget build(BuildContext context) {
    if (valores.isEmpty) return const SizedBox();
    final textos = Theme.of(context).textTheme;
    final secundario = textos.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final absolutos = valores.values.map((v) => (v as num).abs());
    final maior = absolutos.reduce((a, b) => a > b ? a : b);
    final total = absolutos.fold<num>(0, (a, b) => a + b);
    return Column(
      children: [
        for (final item in valores.entries) ...[
          Row(
            children: [
              if (deCategorias) ...[
                PontoDeCor(visualDaCategoria(item.key).cor),
                const SizedBox(width: Espaco.pequeno + Espaco.minimo),
              ],
              Expanded(
                child: Text(deCategorias ? item.key : nomeLegivel(item.key),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: textos.titleSmall),
              ),
              if (deCategorias && total > 0)
                SizedBox(
                  width: 44,
                  child: Text('${((item.value as num).abs() / total * 100).round()}%',
                      textAlign: TextAlign.right, style: secundario),
                ),
              const SizedBox(width: Espaco.pequeno),
              SizedBox(
                width: larguraDoValor,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ValorAnimado(item.value as num, estilo: textos.titleSmall),
                ),
              ),
            ],
          ),
          if (deCategorias)
            Padding(
              padding: const EdgeInsets.only(top: Espaco.pequeno, bottom: Espaco.medio),
              child: BarraAnimada(
                fracao: maior == 0 ? 0 : (item.value as num).abs() / maior,
                cor: visualDaCategoria(item.key).cor,
              ),
            )
          else
            const SizedBox(height: Espaco.pequeno),
        ],
      ],
    );
  }
}

/// Lembrete fixo de que os extratos não saem do computador.
class AvisoDePrivacidade extends StatelessWidget {
  const AvisoDePrivacidade({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Para gerar dicas, enviamos à IA os totais do mês, os saldos e os nomes das lojas.',
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Espaco.minimo + 2,
        children: [
          Icon(Icons.lock_rounded, size: 16, color: cores.onSurfaceVariant),
          Text('Seus extratos ficam neste computador',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cores.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Linha fina sob a barra do topo enquanto o app trabalha. Guarda o espaço para a tela não pular.
class BarraDeCarregamento extends StatelessWidget implements PreferredSizeWidget {
  const BarraDeCarregamento({super.key, required this.ativa});

  final bool ativa;

  @override
  Size get preferredSize => const Size.fromHeight(3);

  @override
  Widget build(BuildContext context) => SizedBox(height: 3, child: ativa ? const LinearProgressIndicator() : null);
}

/// Duas ondas lentas na base da janela, lembrando a linha de um saldo. Paradas se as animações estiverem desligadas.
class FundoDeOndas extends StatefulWidget {
  const FundoDeOndas({super.key});

  @override
  State<FundoDeOndas> createState() => _EstadoFundoDeOndas();
}

class _EstadoFundoDeOndas extends State<FundoDeOndas> with SingleTickerProviderStateMixin {
  late final _tempo = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _tempo.stop();
    } else if (!_tempo.isAnimating) {
      _tempo.repeat();
    }
  }

  @override
  void dispose() {
    _tempo.dispose();
    super.dispose();
  }

  // O limite de pintura poupa o conteúdo da tela de ser redesenhado a cada quadro.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(painter: _PintorDeOndas(_tempo, coresDasOndas(Theme.of(context).brightness))),
      );
}

class _PintorDeOndas extends CustomPainter {
  _PintorDeOndas(this.tempo, this.cores) : super(repaint: tempo);

  final Animation<double> tempo;
  final (Color, Color) cores;

  /// Voltas inteiras por ciclo: o fim emenda no começo sem salto.
  void _pintarOnda(Canvas canvas, Size tamanho, Color cor, double altura, int voltas, double desvio) {
    final fase = tempo.value * 2 * math.pi * voltas + desvio;
    final onda = Path()..moveTo(0, tamanho.height);
    for (var x = 0.0; x <= tamanho.width + 4; x += 4) {
      final posicao = x / tamanho.width;
      final y = altura + tamanho.height * (0.04 * math.sin(posicao * 5 + fase) + 0.02 * math.sin(posicao * 11 - fase));
      onda.lineTo(x, y);
    }
    onda
      ..lineTo(tamanho.width + 4, tamanho.height)
      ..close();
    canvas.drawPath(onda, Paint()..color = cor);
  }

  @override
  void paint(Canvas canvas, Size tamanho) {
    final (atras, frente) = cores;
    _pintarOnda(canvas, tamanho, atras, tamanho.height * 0.64, 1, 0);
    _pintarOnda(canvas, tamanho, frente, tamanho.height * 0.78, 2, 2);
  }

  @override
  bool shouldRepaint(_PintorDeOndas antigo) => antigo.cores != cores;
}

/// Largura da coluna de valores: etiquetas e porcentagens ficam alinhadas seja qual for o número.
const larguraDoValor = 104.0;

/// Rolagem lateral que também funciona com mouse comum: barra sempre à vista e arraste.
class RolagemHorizontal extends StatefulWidget {
  const RolagemHorizontal({super.key, required this.child, this.controle});

  final Widget child;

  /// Para quem precisa mover a rolagem (o giro dos investimentos); sem ele, a rolagem cria e descarta o próprio.
  final ScrollController? controle;

  @override
  State<RolagemHorizontal> createState() => _EstadoRolagemHorizontal();
}

class _EstadoRolagemHorizontal extends State<RolagemHorizontal> {
  final _proprio = ScrollController();

  ScrollController get _controle => widget.controle ?? _proprio;

  @override
  void dispose() {
    _proprio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: Scrollbar(
          controller: _controle,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controle,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: Espaco.medio),
            child: widget.child,
          ),
        ),
      );
}
