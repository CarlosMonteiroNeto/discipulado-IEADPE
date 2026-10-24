# Passagem para build Android e continuação em outro PC

Data: 2026-10-24

Repositório: `CarlosMonteiroNeto/discipulado-IEADPE`

Branch: `codex/ministry-production-completion`

Commit no remoto: `2a76185` (`fix: normalize ministry phones and imported identifiers`)

## Prompt para a próxima sessão

Continue o trabalho neste repositório, no branch `codex/ministry-production-completion`, começando pelo commit `2a76185` ou por commit posterior já enviado ao mesmo branch. Leia as instruções `AGENTS.md` aplicáveis (se estiverem disponíveis no checkout/ambiente), `docs/superpowers/plans/2026-10-22-phase1-closure-plan.md`, este documento e os relatórios de verificação citados abaixo antes de agir. Não instale Android Studio. Este computador pode ser reiniciado para concluir a instalação do Docker, se o instalador solicitar. Faça o build de debug do Android com a configuração Supabase aprovada e instale-o no aparelho via ADB. Preserve os dados existentes do app (`adb install -r`; não limpe dados nem faça logout). Faça uma validação de leitura no aparelho, sem criar/editar/finalizar registros de produção. Depois prossiga com os gates locais que dependem do Docker e documente evidências e bloqueios reais. Não publique, assine para release, altere produção nem rode migrações sem autorização específica.

## Estado confirmado

- O branch foi enviado ao GitHub e estava sincronizado, sem mudanças locais, após o push do commit `2a76185`.
- A suíte Flutter completa passou: `flutter test --no-pub --concurrency=1` — **565/565**.
- `flutter analyze --no-pub` passou sem issues; `dart format --output=none --set-exit-if-changed` nas 17 fontes Dart alteradas não encontrou mudanças; `git diff --check` passou.
- O PostgreSQL 17.11 local usado nos testes foi encerrado. Ele não é requisito para o build Android.
- O último APK instalado no Xiaomi `2109119DG` é antigo, construído em 2026-10-22, antes das alterações agora enviadas. A tentativa de compilar a fonte atual foi interrompida por falta severa de memória; não produziu APK nem instalou nada. O código atual ainda precisa ser validado em runtime nesse aparelho.
- O PC anterior tem cerca de 4 GB de RAM. O processo Gradle chegou a deixar apenas cerca de 9 MB livres; por isso o próximo build deve ser feito no outro PC, sem paralelizar builds.
- Docker Desktop e a pilha local Supabase Auth/PostgREST/Storage ainda não foram executados nesta etapa. T11, integração completa no navegador, aceitação hospedada e gates de release continuam abertos.
- O pareamento ADB anterior usou Wi-Fi debugging e Tailscale, mas os endpoints/códigos são temporários e não devem ser reutilizados a partir deste documento.

## Mudanças incluídas no branch

- O formulário exige os 11 dígitos nacionais brasileiros. O aplicativo acrescenta `+55` ao persistir ou preparar o telefone para WhatsApp.
- A validação de identificadores importados aceita o formato estrutural UUID do PostgreSQL sem exigir bits de versão/variante RFC, mantendo a rejeição de valores fora do formato.
- A tela Discipulado não mostra simultaneamente o erro de carregamento e o estado de diretório vazio.
- Foram adicionados testes para telefones, UUIDs importados e estado vazio/erro. Não houve backfill ou alteração de dados de produção.

## Retomar no outro PC

1. Obtenha o repositório, atualize a referência e confirme o branch e o estado limpo:

   ```powershell
   git fetch origin
   git switch codex/ministry-production-completion
   git pull --ff-only origin codex/ministry-production-completion
   git status -sb
   git log -1 --oneline
   ```

   Se o branch local não existir, crie-o a partir de `origin/codex/ministry-production-completion`. Não descarte alterações locais sem examiná-las.

2. Instale/configure as ferramentas de linha de comando necessárias, sem Android Studio: Flutter **3.47.7**, Android SDK command-line tools, `platform-tools` (ADB), Android SDK Platform/Build Tools compatíveis com a versão do Flutter e Java 17. Confirme `flutter doctor -v`, aceite as licenças Android necessárias e deixe o Flutter apontar para o SDK. O projeto usa Gradle Kotlin DSL e Java 17.

3. Use a configuração Supabase legítima e aprovada para o app. Não use `example.invalid`, valores sintéticos, chaves de service role nem credenciais de produção copiadas de logs. Se for necessário criar um arquivo de Dart defines, mantenha-o fora do repositório, com acesso restrito, contendo `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`; não o faça commit. Construa apenas o APK de debug:

   ```powershell
   flutter pub get
   flutter build apk --debug --no-pub --target-platform android-arm64 `
     --dart-define-from-file="$env:USERPROFILE\.config\ieadpe\dart-defines.json"
   ```

   Ajuste o caminho do arquivo externo conforme a instalação aprovada. Não imprima os valores no terminal ou no relatório. O artefato esperado é `build\app\outputs\flutter-apk\app-debug.apk`. Registre tamanho, SHA-256, versão do Flutter, configuração usada (sem valores) e saída do build. O build de debug não é um artefato de release.

4. No aparelho, abra **Opções do desenvolvedor → Depuração por Wi-Fi** e gere o pareamento atual. Confirme que o PC e o aparelho estão alcançáveis pela rede/Tailscale configurada. Use o endereço, porta e código que estiverem na tela naquele momento:

   ```powershell
   adb pair <IP_DO_APARELHO>:<PORTA_DE_PAREAMENTO>
   adb connect <IP_DO_APARELHO>:<PORTA_ADB>
   adb devices -l
   ```

   O código de seis dígitos expira; não o registre em arquivos, commits ou mensagens persistentes. Se a conexão não funcionar pelo Tailscale, diagnostique primeiro a conectividade e o estado atual de Wi-Fi debugging, sem inventar portas.

5. Instale sem apagar os dados já existentes e confirme a inicialização:

   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-debug.apk
   adb shell am force-stop br.org.ieadpe.ieadpe_converts
   adb shell monkey -p br.org.ieadpe.ieadpe_converts 1
   adb logcat -d -s flutter supabase.supabase_flutter AndroidRuntime
   ```

   Use dumps da hierarquia de UI e logcat filtrado para inspeção; não dependa de screenshots. Registre apenas o necessário e remova tokens, dados pessoais, códigos temporários e conteúdo de payload dos registros compartilhados.

6. Faça a validação de leitura: abertura a frio, inicialização do Supabase, `Início`, `Convertidos`, `Discipulado` e `Alunos` após seleção autorizada. Confira também o campo de telefone e que a tela não apresenta simultaneamente erro de congregações e diretório vazio. Não envie formulários nem execute comandos de escrita de produção. Se Discipulado falhar, guarde o texto visível e a exceção/status HTTP/RPC sanitizados; diferencie falha do servidor de rejeição do cliente.

7. Para a continuação dependente de Docker, instale Docker Desktop neste outro PC e reinicie-o somente se o instalador/Windows solicitar. Depois confira `docker version`, `docker info` e `supabase --version`; leia os passos e variáveis exigidas por `docs/superpowers/plans/2026-10-22-phase1-closure-plan.md`, `docs/verification/ministry-corrective-local-report.md` e `scripts/run_unified_journey.py` antes de iniciar a pilha ou qualquer gate. Use apenas dados locais/sintéticos para esses testes. Não trate um teste parcial como T11 completo.

## Fontes do projeto

- [Plano de fechamento da Fase 1](../../superpowers/plans/2026-10-22-phase1-closure-plan.md)
- [Verificação de formulário e navegação](../2026-10-22-phase1-form-ux.md)
- [Relatório de verificação local do Discipulado](../ministry-corrective-local-report.md)
- [Plano de conclusão de produção do Ministério](../../superpowers/plans/2026-10-18-ministry-production-completion-plan.md)

Os relatórios anteriores são cronológicos e alguns trechos descrevem estados que foram corrigidos depois. Para o estado do código, prefira este handoff e o branch atualizado; mantenha bloqueios de runtime/release como abertos até obter nova evidência no outro PC.
