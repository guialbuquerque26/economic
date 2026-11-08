import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../preferencias.dart';
import '../tema.dart';

const _nome = 'Conversar com o consultor';
const _nomeDoX = 'Esconder o pin do consultor';

/// Ciclo da vida do mascote: respira ao longo dele e pisca no fim. Pensando, a moedinha pula enquanto ele roda.
const _duracaoDoCiclo = Duration(seconds: 4);

/// Como o pin sai de cena: abrindo o consultor (a aba abre, 420 ms) ou pelo X (acena tchau, 800 ms).
enum _Saida { abrir, tchau }

/// Mascote do consultor: uma carteirinha coral com olhinhos, bochechas e sorriso, desenhada no app.
/// - Aparece subindo e crescendo um pouco além do ponto, com uma piscadinha de "oi" (800 ms).
/// - Parada, respira e pisca. Pensando (ou na fila), olha para os lados e uma moedinha pula de dentro dela.
/// - Com o mouse em cima, inclina, a aba abre um tiquinho e um X discreto aparece no canto de cima.
/// - Clicada, a aba abre antes de o consultor abrir. Pelo X, acena tchau antes de sumir.
/// - [quiques] muda quando a pessoa solta o pin depois de arrastar: ele quica ao grudar na borda.
/// Com as animações desligadas no Windows, fica parado e as ações acontecem na hora.
class PinDoConsultor extends StatefulWidget {
  const PinDoConsultor({
    super.key,
    required this.pensando,
    required this.aoAbrir,
    this.aoEsconder,
    this.tamanho = 64,
    this.quiques = 0,
  });

  /// Espaço a mais em cima e à direita do desenho, onde o X aparece: fica dentro da área que recebe cliques.
  static const folgaDoX = 8.0;

  final bool pensando;
  final VoidCallback aoAbrir;
  final VoidCallback? aoEsconder;
  final double tamanho;
  final int quiques;

  @override
  State<PinDoConsultor> createState() => _EstadoPinDoConsultor();
}

class _EstadoPinDoConsultor extends State<PinDoConsultor> with TickerProviderStateMixin {
  late final _ciclo = AnimationController(vsync: this, duration: _duracaoDoCiclo);
  late final _entrada = AnimationController(vsync: this, duration: Movimento.lento);
  late final _mouse = AnimationController(vsync: this, duration: Movimento.rapido);
  late final _saida = AnimationController(vsync: this);

  /// Primeira parte: o pin desliza até a borda; segunda: quica.
  late final _quique = AnimationController(vsync: this, duration: Movimento.lento);
  _Saida? _tipoDaSaida;
  bool _semAnimacao = false;
  bool _focado = false;
  bool _mouseEmCima = false;
  bool _focoDentro = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _semAnimacao = Movimento.de(context, Movimento.medio) == Duration.zero;
    if (_semAnimacao) {
      _ciclo.stop();
      _entrada.value = 1;
    } else {
      if (!_ciclo.isAnimating) _ciclo.repeat();
      if (_entrada.isDismissed) _entrada.forward();
    }
  }

  @override
  void didUpdateWidget(PinDoConsultor antigo) {
    super.didUpdateWidget(antigo);
    if (widget.quiques != antigo.quiques && !_semAnimacao) _quique.forward(from: 0);
  }

  @override
  void dispose() {
    for (final controle in [_ciclo, _entrada, _mouse, _saida, _quique]) {
      controle.dispose();
    }
    super.dispose();
  }

  void _mudarMouse(bool emCima) {
    setState(() => _mouseEmCima = emCima);
    emCima ? _mouse.forward() : _mouse.reverse();
  }

  /// Toca a animação de saída e só depois chama [depois]. Sem animações, chama na hora.
  void _sair(_Saida tipo, VoidCallback depois) {
    if (_semAnimacao) return depois();
    if (_saida.isAnimating) return;
    setState(() => _tipoDaSaida = tipo);
    _saida.duration = tipo == _Saida.abrir ? Movimento.medio : Movimento.lento;
    _saida.forward(from: 0).whenComplete(() {
      if (mounted) depois();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrarX = widget.aoEsconder != null && (_mouseEmCima || _focoDentro) && _tipoDaSaida == null;
    final caixa = widget.tamanho + PinDoConsultor.folgaDoX;
    return MouseRegion(
      onEnter: (_) => _mudarMouse(true),
      onExit: (_) => _mudarMouse(false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (dentro) => setState(() => _focoDentro = dentro),
        child: SizedBox(
          width: caixa,
          height: caixa,
          child: Stack(children: [
            Positioned(left: 0, bottom: 0, child: _carteira(context)),
            if (mostrarX) Positioned(top: 0, right: 0, child: _x(context)),
          ]),
        ),
      ),
    );
  }

  /// X discreto: círculo de 22 na cor Cartão, com a borda do app e o X na Tinta Secundária.
  Widget _x(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final esconder = widget.aoEsconder;
    return Semantics(
      button: true,
      label: _nomeDoX,
      child: Tooltip(
        message: _nomeDoX,
        excludeFromSemantics: true,
        child: Material(
          color: cores.surface,
          shape: CircleBorder(side: BorderSide(color: cores.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: esconder == null ? null : () => _sair(_Saida.tchau, esconder),
            child: SizedBox.square(
              dimension: 22,
              child: Icon(Icons.close_rounded, size: 14, color: cores.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _carteira(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final canto = BorderRadius.circular(widget.tamanho * 0.2);
    return Semantics(
      button: true,
      label: _nome,
      child: Tooltip(
        message: _nome,
        excludeFromSemantics: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([_ciclo, _entrada, _mouse, _saida, _quique]),
          builder: (context, _) {
            final t = _ciclo.value;
            final entrada = _Entrada(_entrada.value);
            final mouse = Curves.easeOutExpo.transform(_mouse.value);
            final saida = _Momento(_tipoDaSaida, _saida.value);
            final quique = _escalaDoQuique(_quique.value);
            final respiro = 1 + 0.03 * (1 - math.cos(2 * math.pi * t)) / 2;
            final balanco = widget.pensando ? 2 * math.sin(4 * math.pi * t) : 0.0;
            return Opacity(
              key: const ValueKey('pin: opacidade'),
              opacity: (entrada.opacidade * saida.opacidade).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(saida.deslocamentoX, entrada.deslocamentoY + balanco),
                child: Transform.rotate(
                  angle: -5 * math.pi / 180 * mouse + saida.giro,
                  child: Transform(
                    key: const ValueKey('pin: quique'),
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(quique.dx, quique.dy, 1),
                    child: Transform.scale(
                      scale: respiro * entrada.escala * (1 + 0.05 * mouse) * saida.escala,
                      child: Container(
                        width: widget.tamanho,
                        height: widget.tamanho,
                        decoration: BoxDecoration(
                          borderRadius: canto,
                          // Anel de foco por teclado, como nos botões: 2 na cor Tinta.
                          border: _focado ? Border.all(color: cores.onSurface, width: 2) : null,
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: RoundedRectangleBorder(borderRadius: canto),
                            // Sem fundo ao passar o mouse ou clicar: a própria carteirinha já reage (inclina, abre a
                            // aba). O foco por teclado continua com o anel em volta.
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            onTap: () => _sair(_Saida.abrir, widget.aoAbrir),
                            onFocusChange: (focado) => setState(() => _focado = focado),
                            child: CustomPaint(
                              painter: _Carteira(
                                abertura: math.min(_abertura(t), entrada.abertura),
                                olhar: widget.pensando ? math.sin(4 * math.pi * t) : 0,
                                aba: -8 * math.pi / 180 * mouse + saida.aba,
                                moeda: widget.pensando && !_semAnimacao ? (t * 2.5) % 1 : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Olhos abertos (1) quase o tempo todo; fecham e abrem rápido no fim do ciclo.
  static double _abertura(double t) => t < 0.94 ? 1 : ((t - 0.97).abs() / 0.03).clamp(0.1, 1.0);

  /// Depois de soltar: na primeira parte o pin desliza até a borda; depois achata e estica até parar.
  static ({double dx, double dy}) _escalaDoQuique(double q) {
    final p = ((q - 0.45) / 0.55).clamp(0.0, 1.0);
    if (p == 0 || p == 1) return (dx: 1, dy: 1);
    final dx = 1 + 0.1 * (1 - p) * math.cos(p * 3 * math.pi);
    return (dx: dx, dy: 2 - dx);
  }
}

/// Aparecer: sobe 40, cresce de 50% até passar um pouco do ponto (108%) e assenta; pisca perto do fim.
class _Entrada {
  _Entrada(double v)
      : opacidade = (v / 0.55).clamp(0.0, 1.0),
        escala = v < 0.55
            ? 0.5 + 0.58 * Curves.easeOut.transform(v / 0.55)
            : 1.08 - 0.08 * Curves.easeOut.transform((v - 0.55) / 0.45),
        deslocamentoY = v < 0.55
            ? 40 - 46 * Curves.easeOut.transform(v / 0.55)
            : -6 + 6 * Curves.easeOut.transform((v - 0.55) / 0.45),
        abertura = v > 0.7 && v < 0.9 ? 0.1 + 0.9 * ((v - 0.8).abs() / 0.1) : 1;

  final double opacidade;
  final double escala;
  final double deslocamentoY;
  final double abertura;
}

/// Saída em andamento: abrir (a aba gira até 28° e o pin encolhe e some) ou tchau (acena e encolhe até zero).
class _Momento {
  factory _Momento(_Saida? tipo, double s) {
    if (tipo == null || s == 0) return const _Momento._();
    if (tipo == _Saida.abrir) {
      final e = Curves.easeOutExpo.transform(s);
      return _Momento._(aba: -28 * math.pi / 180 * e, escala: 1 - 0.3 * s, opacidade: 1 - s, deslocamentoX: 12 * s);
    }
    if (s < 0.45) {
      final onda = s / 0.45;
      return _Momento._(giro: math.sin(onda * 3 * math.pi) * (14 - 8 * onda) * math.pi / 180);
    }
    final some = 1 - (s - 0.45) / 0.55;
    return _Momento._(escala: some, opacidade: some);
  }

  const _Momento._({this.aba = 0, this.giro = 0, this.escala = 1, this.opacidade = 1, this.deslocamentoX = 0});

  final double aba;
  final double giro;
  final double escala;
  final double opacidade;
  final double deslocamentoX;
}

/// A carteirinha, num quadro de 96 unidades: corpo coral, aba que abre, fecho, olhos, bochechas e sorriso.
/// Pensando, uma moedinha sobe de dentro dela e volta.
class _Carteira extends CustomPainter {
  _Carteira({required this.abertura, required this.olhar, required this.aba, this.moeda});

  /// 1 = olhos abertos; perto de 0 = piscando.
  final double abertura;

  /// De -1 a 1: para onde os olhos olham (pensando).
  final double olhar;

  /// Giro da aba, em radianos (negativo abre).
  final double aba;

  /// Fase da moedinha (0 a 1) enquanto pensa; null sem moedinha.
  final double? moeda;

  @override
  void paint(Canvas canvas, Size tamanho) {
    canvas.scale(tamanho.shortestSide / 96);
    if (moeda case final fase?) _moedinha(canvas, fase);
    final corpo = RRect.fromRectAndRadius(const Rect.fromLTWH(12, 24, 72, 54), const Radius.circular(14));
    canvas.drawShadow(Path()..addRRect(corpo), const Color(0xFF5A3A1E), 4, false);
    canvas.drawRRect(corpo, Paint()..color = CoresDoPin.corpo);
    canvas.save();
    canvas.translate(48, 24);
    canvas.rotate(aba);
    canvas.translate(-48, -24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 38)
        ..quadraticBezierTo(12, 24, 26, 24)
        ..lineTo(70, 24)
        ..quadraticBezierTo(84, 24, 84, 38)
        ..lineTo(84, 44)
        ..lineTo(12, 44)
        ..close(),
      Paint()..color = CoresDoPin.aba,
    );
    canvas.restore();
    canvas.drawRRect(RRect.fromLTRBR(64, 34, 84, 50, const Radius.circular(6)), Paint()..color = CoresDoPin.fecho);
    canvas.drawCircle(const Offset(72, 42), 3, Paint()..color = CoresDoPin.creme);
    final tinta = Paint()..color = CoresDoPin.tinta;
    for (final x in [32.0, 52.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 3 * olhar, 57), width: 8, height: 11 * abertura), tinta);
    }
    final rosado = Paint()..color = CoresDoPin.rosado;
    canvas.drawCircle(const Offset(24, 66), 3.5, rosado);
    canvas.drawCircle(const Offset(60, 66), 3.5, rosado);
    canvas.drawPath(
      Path()
        ..moveTo(35, 66)
        ..quadraticBezierTo(42, 72, 49, 66),
      Paint()
        ..color = CoresDoPin.tinta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Sobe de dentro da carteira, para no alto e volta; some ao entrar.
  void _moedinha(Canvas canvas, double fase) {
    final (subida, opacidade) = switch (fase) {
      < 0.3 => (14 - 30 * Curves.easeOut.transform(fase / 0.3), fase / 0.3),
      < 0.6 => (-16 + 6 * (fase - 0.3) / 0.3, 1.0),
      _ => (-10 + 24 * (fase - 0.6) / 0.4, 1 - (fase - 0.6) / 0.4),
    };
    final centro = Offset(48, 22 + subida);
    canvas.drawCircle(centro, 9, Paint()..color = CoresDoPin.rosado.withValues(alpha: opacidade));
    canvas.drawCircle(
      centro,
      9,
      Paint()
        ..color = CoresDoPin.fecho.withValues(alpha: opacidade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_Carteira antigo) =>
      antigo.abertura != abertura || antigo.olhar != olhar || antigo.aba != aba || antigo.moeda != moeda;
}

/// Camada por cima do painel com o pin. Arrastar leva o pin para qualquer lugar; ao soltar, ele desliza até a
/// borda mais próxima e o lugar fica guardado. Clicar abre o consultor. Fora do pin, cliques passam para o painel.
class CamadaDoPin extends StatefulWidget {
  const CamadaDoPin({super.key, required this.lugar, required this.pensando, required this.aoAbrir});

  final PreferenciaLugarDoPin lugar;
  final bool pensando;
  final VoidCallback aoAbrir;

  @override
  State<CamadaDoPin> createState() => _EstadoCamadaDoPin();
}

class _EstadoCamadaDoPin extends State<CamadaDoPin> {
  /// Canto superior esquerdo do pin enquanto ele é arrastado; null quando está parado.
  Offset? _arrastando;

  /// Muda a cada vez que a pessoa solta o pin, para ele quicar ao grudar na borda.
  int _quiques = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, limites) {
      final tamanho = limites.maxWidth < Largura.media ? 56.0 : 64.0;
      final caixa = tamanho + PinDoConsultor.folgaDoX;
      const margem = Espaco.medio;
      final maximoX = math.max(margem, limites.maxWidth - caixa - margem);
      final livreY = math.max(0.0, limites.maxHeight - caixa - 2 * margem);
      final lugar = widget.lugar.value;
      final repouso = Offset(lugar.direita ? maximoX : margem, margem + lugar.altura * livreY);
      final posicao = _arrastando ?? repouso;
      return Stack(children: [
        AnimatedPositioned(
          // Arrastando, o pin segue o ponteiro; ao soltar, desliza até a borda.
          duration: _arrastando != null ? Duration.zero : Movimento.de(context, Movimento.medio),
          curve: Movimento.saida,
          left: posicao.dx,
          top: posicao.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _arrastando = repouso),
            onPanUpdate: (detalhes) => setState(() {
              final novo = _arrastando! + detalhes.delta;
              _arrastando = Offset(novo.dx.clamp(margem, maximoX), novo.dy.clamp(margem, margem + livreY));
            }),
            onPanEnd: (_) {
              final solto = _arrastando!;
              setState(() {
                _arrastando = null;
                _quiques++;
              });
              widget.lugar.guardar((
                direita: solto.dx + caixa / 2 > limites.maxWidth / 2,
                altura: livreY == 0 ? 1.0 : ((solto.dy - margem) / livreY).clamp(0.0, 1.0),
              ));
            },
            child: PinDoConsultor(
              pensando: widget.pensando,
              aoAbrir: widget.aoAbrir,
              aoEsconder: () => widget.lugar.esconder(true),
              tamanho: tamanho,
              quiques: _quiques,
            ),
          ),
        ),
      ]);
    });
  }
}
