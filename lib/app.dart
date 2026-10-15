import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'configuration.dart';

class App extends StatelessWidget {
  const App({super.key, this.configuration});

  final Configuration? configuration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEADPE — Novos Convertidos',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1e3a5f),
          foregroundColor: Colors.white,
        ),
      ),
      home: _BootstrapScreen(configuration: configuration),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen({this.configuration});
  final Configuration? configuration;

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late Configuration _configuration;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _configuration = widget.configuration ?? Configuration.fromEnvironment();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IEADPE')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.church, size: 48, color: Color(0xff1e3a5f)),
                  const SizedBox(height: 16),
                  Text(
                    'Novos Convertidos',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _configuration.isValid
                        ? 'Aplicativo em preparação'
                        : 'Serviço indisponível',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _configuration.isValid
                        ? 'O acesso ainda está em preparação. Procure a liderança para orientações.'
                        : 'Não foi possível disponibilizar o acesso. Tente novamente ou procure a liderança para obter ajuda.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
