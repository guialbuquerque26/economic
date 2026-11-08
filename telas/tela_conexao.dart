import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'estado_financas.dart';
import 'formatacao.dart';
import 'secoes/componentes.dart';
import 'tema.dart';

const _larguraDaTela = 640.0;
const _maximoDeConexoes = 5;
const _campoVazio = 'Preencha este campo.';
final _codigoDeConexao = RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$');

const _passos = [
  (texto: 'Crie sua conta no Meu Pluggy', endereco: 'https://meu.pluggy.ai'),
  (texto: 'Conecte seus bancos e conclua a autorização no site ou aplicativo do banco', endereco: null),
  (texto: 'Crie uma conta no painel da Pluggy, de preferência com o mesmo e-mail', endereco: 'https://dashboard.pluggy.ai'),
  (texto: 'No painel, abra a aplicação de demonstração e copie o Client ID e o Client Secret', endereco: null),
  (
    texto: 'Na página Demo, clique em Conectar Conta, escolha MeuPluggy, entre com sua conta do Meu Pluggy e autorize',
    endereco: null
  ),
  (texto: 'Em Itens Conectados, abra cada conexão e copie o código que aparece acima do nome', endereco: null),
];

/// Pergunta, uma instituição por vez, qual versão das movimentações repetidas continua. Fechar devolve null.
Future<Map<String, String>?> perguntarFonte(BuildContext context, List<Dados> pendentes) async {
  final escolhas = <String, String>{};
  for (final pendente in pendentes) {
    final instituicao = pendente['instituicao'] as String;
    final escolha = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Movimentações repetidas'),
        content: Text(
          'Encontramos ${pendente['quantidade']} movimentações do $instituicao que você já tinha importado por extrato. '
          'Qual versão deve continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, 'extrato'),
            child: const Text('Manter a do extrato'),
          ),
          FilledButton(onPressed: () => Navigator.pop(contexto, 'banco'), child: const Text('Usar a do banco')),
        ],
      ),
    );
    if (escolha == null || !context.mounted) return null;
    escolhas[instituicao] = escolha;
  }
  return escolhas;
}

/// Marca do banco em disco, com o SVG que o serviço entrega; sem imagem, a inicial do nome.
class _LogotipoDoBanco extends StatelessWidget {
  const _LogotipoDoBanco({required this.rotulo, this.imagem});

  static const _tamanho = 40.0;

  final String rotulo;
  final String? imagem;

  @override
  Widget build(BuildContext context) {
    final inicial = Center(
      child: Text(
        rotulo.isEmpty ? '?' : rotulo[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
    return Container(
      width: _tamanho,
      height: _tamanho,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
      child: imagem == null
          ? inicial
          : SvgPicture.string(
              imagem!,
              width: _tamanho,
              height: _tamanho,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => inicial,
              errorBuilder: (_, __, ___) => inicial,
            ),
    );
  }
}

/// Um banco conectado: marca, situação e a chave para receber ou pausar.
class _CartaoDoBanco extends StatelessWidget {
  const _CartaoDoBanco({
    required this.banco,
    required this.ultimaBusca,
    required this.habilitado,
    required this.aoMudar,
  });

  static const _opacidadePausado = 0.45;

  final Dados banco;
  final String? ultimaBusca;
  final bool habilitado;
  final ValueChanged<bool> aoMudar;

  bool get _pausado => banco['pausado'] as bool;
  bool get _semResposta => banco['sem_resposta'] as bool;

  String get _situacao {
    if (_semResposta) return 'Sem resposta do banco · confira no Meu Pluggy';
    if (_pausado) return 'Pausado · histórico continua no painel';
    return ultimaBusca == null
        ? 'Recebendo · nenhuma busca feita ainda'
        : 'Recebendo · última busca em ${formatarData(ultimaBusca!)}';
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final rotulo = banco['rotulo'] as String;
    return Cartao(
      preenchimento: const EdgeInsets.symmetric(horizontal: Espaco.grande, vertical: Espaco.medio),
      filho: Row(
        children: [
          AnimatedOpacity(
            opacity: _pausado ? _opacidadePausado : 1,
            duration: Movimento.de(context, Movimento.rapido),
            child: _LogotipoDoBanco(rotulo: rotulo, imagem: banco['imagem'] as String?),
          ),
          const SizedBox(width: Espaco.pequeno + Espaco.minimo),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rotulo, style: textos.titleSmall),
                Row(
                  children: [
                    if (_semResposta) ...[
                      Icon(Icons.error_outline_rounded, size: 16, color: cores.error),
                      const SizedBox(width: Espaco.minimo),
                    ],
                    Flexible(
                      child: Text(
                        _situacao,
                        style: textos.bodySmall?.copyWith(color: _semResposta ? cores.error : cores.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.pequeno),
          Semantics(
            label: 'Receber movimentações de $rotulo',
            child: Switch(
              value: !_pausado,
              inactiveTrackColor: cores.outline,
              inactiveThumbColor: cores.surface,
              onChanged: habilitado ? aoMudar : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Conexão opcional com o banco: passo a passo para quem ainda não conectou e, depois, a situação da conexão.
class TelaConexao extends StatefulWidget {
  const TelaConexao({super.key, required this.estado});

  final EstadoFinancas estado;

  @override
  State<TelaConexao> createState() => _EstadoTelaConexao();
}

class _EstadoTelaConexao extends State<TelaConexao> {
  final _formulario = GlobalKey<FormState>();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _codigos = TextEditingController();
  final _formularioDoBanco = GlobalKey<FormState>();
  final _codigoNovo = TextEditingController();

  EstadoFinancas get _estado => widget.estado;

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    _codigos.dispose();
    _codigoNovo.dispose();
    super.dispose();
  }

  Future<void> _adicionarBanco() async {
    if (!_formularioDoBanco.currentState!.validate()) return;
    final erro = await _estado.adicionarConexao(_codigoNovo.text.trim());
    if (!mounted) return;
    if (erro != null) {
      await _avisar(Future.value(erro));
      return;
    }
    _codigoNovo.clear();
    await _avisar(_estado.buscarConexao(_perguntar));
  }

  Future<Map<String, String>?> _perguntar(List<Dados> pendentes) async =>
      mounted ? perguntarFonte(context, pendentes) : null;

  Future<void> _avisar(Future<String?> acao) async {
    final mensagem = await acao;
    if (mensagem == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  List<String> get _codigosDigitados =>
      _codigos.text.split('\n').map((linha) => linha.trim()).where((linha) => linha.isNotEmpty).toList();

  String? _validarCodigos(String? _) {
    final codigos = _codigosDigitados;
    if (codigos.isEmpty) return _campoVazio;
    if (codigos.length > _maximoDeConexoes) return 'Use no máximo $_maximoDeConexoes códigos.';
    return codigos.every(_codigoDeConexao.hasMatch) ? null : 'Confira os códigos copiados.';
  }

  Future<void> _conectar() async {
    if (!_formulario.currentState!.validate()) return;
    final erro = await _estado.conectar(_clientId.text.trim(), _clientSecret.text.trim(), _codigosDigitados);
    if (!mounted) return;
    if (erro != null) {
      await _avisar(Future.value(erro));
      return;
    }
    _clientSecret.clear();
    await _avisar(_estado.buscarConexao(_perguntar));
  }

  Future<void> _desconectar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Desconectar do banco?'),
        content: const Text(
          'Seus dados de acesso serão apagados. As movimentações que já estão no Economic continuam salvas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Desconectar')),
        ],
      ),
    );
    if (confirmado == true) await _avisar(_estado.desconectar());
  }

  /// A chave mostra o que veio do serviço: se a escolha não for salva, ela continua onde estava.
  Future<void> _mudarBanco(String nome, bool receber) async {
    final erro = await _estado.pausarBanco(nome, !receber);
    if (!mounted) return;
    if (erro != null) {
      await _avisar(Future.value(erro));
      return;
    }
    await _avisar(_estado.buscarConexao(_perguntar));
  }

  Widget _passo(int numero, String texto, String? endereco) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaco.pequeno),
      child: Row(
        children: [
          SizedBox(width: Espaco.grande, child: Text('$numero.', style: textos.titleSmall)),
          Expanded(child: Text(texto, style: textos.bodyMedium)),
          if (endereco != null)
            MolaAoPressionar(
              child: TextButton(
                onPressed: () => Process.run('explorer', [endereco]), // abre o navegador padrão do Windows
                child: const Text('Abrir site'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController controle, String rotulo, {bool oculto = false}) => TextFormField(
        controller: controle,
        obscureText: oculto,
        enableSuggestions: false,
        autocorrect: false,
        validator: (texto) => texto!.trim().isEmpty ? _campoVazio : null,
        decoration: InputDecoration(labelText: rotulo),
      );

  Widget _passoAPasso(bool ocupado) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return EntradaSuave(
      child: Secao(
        titulo: 'Conecte seu banco',
        filho: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Para quem prefere não importar extratos. Usa uma conta sua no Meu Pluggy, gratuita para uso '
                'pessoal, com até $_maximoDeConexoes bancos no seu nome.',
                style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
              ),
              const SizedBox(height: Espaco.medio),
              for (final (indice, passo) in _passos.indexed) _passo(indice + 1, passo.texto, passo.endereco),
              const SizedBox(height: Espaco.medio),
              _campo(_clientId, 'Client ID'),
              const SizedBox(height: Espaco.medio),
              _campo(_clientSecret, 'Client Secret', oculto: true),
              const SizedBox(height: Espaco.medio),
              TextFormField(
                controller: _codigos,
                maxLines: _maximoDeConexoes,
                minLines: 2,
                autocorrect: false,
                validator: _validarCodigos,
                decoration: const InputDecoration(
                  labelText: 'Códigos das conexões',
                  helperText: 'Um código por linha, até $_maximoDeConexoes.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Espaco.medio),
              Text(
                'Seus dados de acesso ficam protegidos na nuvem e servem apenas para buscar suas movimentações.',
                style: textos.bodySmall?.copyWith(color: cores.onSurfaceVariant),
              ),
              const SizedBox(height: Espaco.grande),
              Align(
                alignment: Alignment.centerRight,
                child: MolaAoPressionar(
                  ativa: !ocupado,
                  child: FilledButton(onPressed: ocupado ? null : _conectar, child: const Text('Conectar')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _situacao(Dados conexao, bool ocupado) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final bancos = List<Dados>.from(conexao['bancos'] as List);
    final meses = List<String>.from(conexao['meses_ignorados'] as List);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (ordem, banco) in bancos.indexed) ...[
          EntradaSuave(
            ordem: ordem,
            child: _CartaoDoBanco(
              banco: banco,
              ultimaBusca: conexao['ultima_busca'] as String?,
              habilitado: !ocupado,
              aoMudar: (receber) => _mudarBanco(banco['nome'] as String, receber),
            ),
          ),
          const SizedBox(height: Espaco.medio),
        ],
        EntradaSuave(
          ordem: bancos.length,
          child: Cartao(
            preenchimento: const EdgeInsets.symmetric(horizontal: Espaco.grande, vertical: Espaco.pequeno),
            filho: Row(
              children: [
                Expanded(
                  child: Text(
                    'Sua conexão com o Meu Pluggy',
                    style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
                  ),
                ),
                MolaAoPressionar(
                  ativa: !ocupado,
                  child: TextButton(onPressed: ocupado ? null : _desconectar, child: const Text('Desconectar tudo')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espaco.medio),
        EntradaSuave(
          ordem: bancos.length + 1,
          child: Secao(
            titulo: 'Adicionar outro banco',
            filho: Form(
              key: _formularioDoBanco,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'No painel da Pluggy, abra a página Demo, clique em Conectar Conta e escolha MeuPluggy. Depois, '
                    'copie o código em Itens Conectados.',
                    style: textos.bodyMedium?.copyWith(color: cores.onSurfaceVariant),
                  ),
                  const SizedBox(height: Espaco.medio),
                  TextFormField(
                    controller: _codigoNovo,
                    autocorrect: false,
                    validator: (texto) =>
                        _codigoDeConexao.hasMatch(texto!.trim()) ? null : 'Confira o código copiado.',
                    decoration: const InputDecoration(labelText: 'Código da conexão'),
                  ),
                  const SizedBox(height: Espaco.medio),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MolaAoPressionar(
                      ativa: !ocupado,
                      child: FilledButton(
                        onPressed: ocupado ? null : _adicionarBanco,
                        child: const Text('Adicionar banco'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (meses.isNotEmpty) ...[
          const SizedBox(height: Espaco.medio),
          EntradaSuave(
            ordem: bancos.length + 2,
            child: Secao(
              titulo: 'Meses que não buscamos',
              filho: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final mes in meses)
                    Row(
                      children: [
                        Expanded(child: Text(formatarMesPorExtenso(mes), style: textos.bodyMedium)),
                        MolaAoPressionar(
                          ativa: !ocupado,
                          child: TextButton(
                            onPressed: ocupado ? null : () => _avisar(_estado.voltarABuscar(mes)),
                            child: const Text('Voltar a buscar'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _estado,
      builder: (context, _) {
        final conexao = _estado.conexao;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Conexão com o banco'),
            bottom: BarraDeCarregamento(ativa: _estado.carregando),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const FundoDeOndas(),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.pequeno, Espaco.grande, Espaco.grande),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _larguraDaTela),
                    child: AnimatedSwitcher(
                      duration: Movimento.de(context, Movimento.medio),
                      layoutBuilder: (atual, anteriores) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...anteriores, if (atual != null) atual],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_estado.conexaoAtiva),
                        child: _estado.conexaoAtiva
                            ? _situacao(conexao!, _estado.carregando)
                            : _passoAPasso(_estado.carregando),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
