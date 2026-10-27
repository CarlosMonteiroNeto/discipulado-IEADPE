# Simplificação do cadastro de convertidos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplificar cadastro e edição de convertidos sem apagar dados pessoais compartilhados com o discipulado.

**Architecture:** Manter endereço estruturado; Endereço altera somente `person.address.street`. Permitir culto nulo na persistência e em todos os consumidores; preservar nascimento e componentes ocultos na edição. Reutilizar o formulário, calendário, controle de salvamento e RPCs existentes.

**Tech Stack:** Flutter/Dart, Supabase/PostgreSQL, testes Flutter e SQL com runner Python existente; nenhuma dependência nova.

**Spec:** [Desenho aprovado](../specs/2026-10-27-convert-registration-simplification-design.md).

## Global Constraints

- Retirar nascimento apenas do formulário de convertidos; manter a coluna e seu uso pelo discipulado.
- Endereço permanece opcional e grava em Logradouro; preservar bairro, cidade, CEP e UF existentes.
- Hoje usa `BusinessCalendar` em `America/Sao_Paulo`; data obrigatória, alterável e não futura. Edição conserva a data existente.
- Ausência de culto é `null`; “Não informado” é somente apresentação. Preservar valores de culto existentes e backups anteriores.
- Não alterar acesso, isolamento de congregações, revisões, recibos de idempotência, fotos ou contadores semanais.
- Sem implementação, publicação, push ou migração hospedada nesta fase documental. Execução externa continua sujeita às autorizações vigentes.
- Preservar o protocolo vigente: implementação native Luna Medium e revisão independente native Sol 6.1 low. Executar tarefas em sequência por compartilharem contratos. Confirmar disponibilidade no início da execução; não substituir modelos silenciosamente.

## Review Focus

1. Pessoa compartilhada com nascimento e endereço completo: editar convertido não pode apagar campos ocultos (T2).
2. Virada de data em UTC e cadastro reiniciado: usar o dia de São Paulo calculado ao abrir cada formulário (T2).
3. Culto nulo vindo do servidor: não bloquear toda a listagem nem produzir erro no cartão (T1/T3).
4. Backup com célula de culto vazia: restaurar como ausência, preservando os cultos antigos (T1/T3).
5. Falha seguida de nova tentativa ou perda de acesso: conservar o rascunho e os controles de idempotência sem vazar dados de sessão anterior (T2/T3).

## Mapa de arquivos e responsabilidades

| Arquivos | Responsabilidade |
|---|---|
| `lib/domain/models.dart`, `lib/data/convert_repository.dart` | Tipo de culto e decodificação de leitura |
| `lib/data/supabase_gateway.dart` | Validação de comando e importação |
| `lib/features/converts/convert_form.dart` | Campos, inicialização, preservação e payload |
| `lib/features/people/person_fields.dart` | Componente compartilhado: manter comportamento completo do discipulado; só introduzir configuração se indispensável |
| `lib/features/converts/convert_card.dart` | Apresentação de culto ausente |
| `lib/features/reports/reports_repository.dart` | Agrupamento de ausência em “Não informado”, já existente |
| `lib/features/backup/backup_codec.dart`, `backup_repository.dart` no mesmo diretório | Exportação/importação e compatibilidade |
| Nova migração gerada pelo CLI | Nulabilidade e comandos de escrita/importação; não editar migrações aplicadas |
| Testes citados abaixo | Regressões observáveis |

## T0 — Confirmar ambiente e acesso efetivo

**Interfaces:** consome o desenho aprovado e os limites de execução vigentes; produz checkout isolado e registro de recursos verificados, sem segredos.

- [ ] Confirmar repositório `discipulado-IEADPE`, instruções aplicáveis, HEAD, status e histórico recente. Preparar isolamento conforme `using-git-worktrees` antes de implementar; usar branch `codex/convert-registration-simplification` se disponível.
- [ ] Registrar versões/caminhos de Flutter, Python, PostgreSQL e Supabase CLI. Consultar `supabase --help`, `supabase migration --help` e `supabase migration new --help` antes de gerar a migração. Conferir documentação atual relevante antes de implementar Supabase e carregar os skills de banco exigidos.
- [ ] Inspecionar `scripts/test_database.py` e configuração local: provar que o alvo de testes é um PostgreSQL descartável de loopback pertencente ao executor. Não usar banco hospedado para testes com escrita nem impor Docker quando o runner existente usa PostgreSQL nativo.
- [ ] Registrar neste plano: runtime disponível, acesso local ao banco verificado por operação, recursos ausentes e eventual alvo hospedado apenas identificado. Leitura de configuração não prova autorização DDL. Acesso hospedado não verificado permanece adiado e não bloqueia trabalho Flutter independente.
- [ ] Executar os testes focados existentes antes da mudança. Investigar qualquer falha, rastrear sua causa e registrar a classificação; não aceitar falha de baseline sem investigação. Confirmar o protocolo de modelos vigente antes de delegar implementação/revisão.

**Estado na autoria:** leitura do código verificada; HEAD documental `06a6d96`; acesso ao runtime e banco de testes não verificado; banco hospedado não consultado. Nenhum login, segredo ou decisão adicional é necessário para este plano.

## T1 — Culto opcional de ponta a ponta

**Files:** modificar modelos, repositório, gateway, cartão e codec do mapa; criar `supabase/tests/database/optional_worship_test.sql`; ampliar `test/data/supabase_gateway_convert_contract_test.dart`, `test/features/backup/backup_codec_test.dart` e `test/features/converts/list_test.dart`. Criar migração com o nome lógico `convert_optional_worship` pelo CLI; o timestamp será atribuído pelo comando, não inventado neste plano.

**Interfaces:** `ConvertRecord.worshipType` e `ConvertDraft.worshipType` passam a `String?`; manter os nomes dos parâmetros. `ConvertDraft.payload()` continua `Map<String, Object?>`, com a chave `convert.worship_type` presente e nula quando não escolhida. Manter envelopes e assinaturas dos RPCs existentes. Ausência via JSON deve ser nula; string vazia ou só espaços não é um culto válido.

- [ ] Escrever casos de regressão nos testes indicados: cadastro e edição aceitam culto nulo; string válida antiga é preservada; valor numérico, vazio e espaços são rejeitados; a leitura e o cartão aceitam nulo. No codec, célula vazia importa como nulo e nulo exporta como célula vazia, mantendo versões/colunas existentes.
- [ ] Executar os testes novos contra a implementação atual. RED válido é a rejeição/erro na nova asserção que demonstra o contrato obrigatório atual; erro de compilação ao passar nulo a um parâmetro ainda não anulável não basta. Usar payload JSON no RED inicial, antes da atualização tipada.
- [ ] Gerar migração forward: remover `NOT NULL` de `public.converts.worship_type`; manter a restrição de texto válido quando presente. Atualizar as definições vigentes de escrita em `202610190002_ministry_student_registration.sql` e importação em `202610200001_import_revision_compatibility.sql` por substituição na nova migração. Revisar também o caminho legado `private.convert_command`: permitir nulo sem alterar autorização, recibos, revisões e contadores. Preservar assinaturas e grants; não editar os arquivos históricos.
- [ ] Implementar os tipos anuláveis e validações condicionais no Dart, a representação de backup e a apresentação “Não informado” no cartão. Atualizar apenas consumidores identificados pelo analisador/busca do campo; manter o agrupamento de relatório já existente.
- [ ] Executar `python scripts/test_database.py optional_worship_test.sql`, `python scripts/test_database.py convert_commands_test.sql` e `python scripts/test_database.py import_test.sql`: esperar saída 0 e nenhuma asserção SQL falha. Executar `flutter test test/data/supabase_gateway_convert_contract_test.dart test/features/backup/backup_codec_test.dart test/features/converts/list_test.dart`: esperar todos passarem. Confirmar diferenças e segurança da nova migração.
- [ ] Revisar a unidade pelo protocolo vigente e criar commit local somente após GREEN.

## T2 — Simplificar o formulário e preservar identidade

**Files:** modificar `lib/features/converts/convert_form.dart`; ampliar `test/features/converts/form_test.dart`, `save_test.dart` e `stale_save_test.dart` no mesmo diretório de testes. Modificar `person_fields.dart` somente se necessário, preservando seu padrão atual para os demais chamadores.

**Interfaces:** manter `ConvertForm(initial, onSubmit, now, ...)`, `ConvertDraft.payload()` e `ConvertSaveController.save(ConvertDraft draft) -> Future<String>`. Consumir o culto anulável de T1. O formulário continua proprietário do estado; não criar estado global nem nova dependência. Nascimento oculto vem da identidade inicial; componentes de endereço ocultos vêm do objeto inicial, não de controles vazios.

- [ ] Adicionar testes com asserções: não existem controles Nascimento/Bairro/Cidade/CEP/UF; existe Endereço; culto não escolhido produz nulo; novo cadastro produz nascimento nulo e apenas street preenchido. Fixar o relógio em `2026-10-28T01:30:00Z` e esperar `2026-10-27`; remontar com `2026-10-28T03:30:00Z` e esperar `2026-10-28`.
- [ ] Adicionar caso com nascimento e endereço completo: alterar Endereço e esperar o mesmo nascimento, bairro, cidade, CEP e UF, com somente street modificado. Cobrir endereço canônico nulo, texto legado e data de conversão antiga. Não habilitar edição de registro legado cujo salvamento já exige vínculo de pessoa; preservar essa proteção.
- [ ] Adicionar casos de data manual não futura aceita e futura rejeitada; falha de salvamento conserva os valores; repetir o envio não altera a operação retida; perda de contexto rejeita conclusão antiga. Confirmar RED nas novas asserções antes de implementar.
- [ ] Remover controles desnecessários do formulário de convertidos, preservar os dados iniciais no draft e rotular o controle de rua como Endereço. Inicializar data com `BusinessCalendar().today(widget.now())` somente quando `initial == null`. Retirar obrigatoriedade e permitir limpar culto no controle atual. Manter obrigatoriedade/validação dos demais campos e feedback existente.
- [ ] Executar `flutter test test/features/converts/form_test.dart test/features/converts/save_test.dart test/features/converts/stale_save_test.dart`: esperar todos passarem. Verificar teclado, semântica, texto ampliado e contraste; manter preferências de movimento reduzido. Sem novos gestos/animações, requisitos de mola, momentum e rastreamento 1:1 permanecem inaplicáveis.
- [ ] Revisar a unidade pelo protocolo vigente e criar commit local após GREEN.

## T3 — Integração e aceitação final

**Files:** ampliar `test/features/reports/conversion_repository_test.dart` e `supabase/tests/database/optional_worship_test.sql`; registrar evidências em `docs/verification/2026-10-27-convert-registration-simplification.md`.

**Interfaces:** consumir os contratos de T1/T2 sem novas assinaturas públicas. O cadastro de alunos mantém seus campos e lê o mesmo endereço canônico.

- [ ] Verificar por teste integrado que uma alteração em street pelo fluxo de convertido aparece como Logradouro na leitura do aluno vinculado, com nascimento e demais componentes preservados. Verificar que conversões com culto nulo continuam nas contagens e aparecem em “Não informado”. Confirmar backup/exportação/importação com ausência e valores antigos sem perda de registros.
- [ ] Executar `python scripts/test_database.py optional_worship_test.sql`, `python scripts/test_database.py ministry_student_registration_test.sql` e `python scripts/test_database.py import_revision_compatibility_test.sql`: esperar código 0 e todas as asserções aprovadas. Confirmar aplicação da migração sobre dados antigos em instância descartável, sem excluir/reescrever valores existentes.
- [ ] Executar `powershell -NoProfile -File scripts/check.ps1`: esperar análise sem problemas e todos os testes Flutter aprovados. Executar `git diff --check`: esperar código 0. Investigar falhas antes de alterar código, testes ou declarar limitação externa; repetir primeiro o check estreito e depois o pertinente mais amplo.
- [ ] Registrar comandos, códigos de saída, candidato revisado, teste de migração, checklist POUR e limitações reais. A sequência UML do desenho deve corresponder ao comportamento final; gate de elaboração termina com contratos comprovados. Não alegar verificação hospedada ou dispositivo real usando evidência sintética.
- [ ] Obter revisão independente do conjunto conforme protocolo vigente; corrigir achados e repetir somente verificações afetadas. Fazer commit local do resultado e atualizar o estado deste plano. Push, migração hospedada e publicação permanecem separados.

## Autorrevisão e entrega

Cobertura conferida: quatro mudanças em T1/T2; preservação, legado, fuso e retries em T2; banco, leitura compartilhada, relatórios, importação e aceitação em T1/T3; dependências e isolamento em T0. Limites de objetos, sequência UML, gate UP, fidelidade textual e critérios POUR vêm do desenho aprovado e estão vinculados a T2/T3. Não há novos controles de gesto ou animação. Não foram executados testes de produto durante a elaboração do plano.

Plano pronto para revisão do usuário. Após confirmação, usar o método de execução vigente, sem reabrir decisões já aprovadas. Este documento é o plano do incremento; planos históricos de release continuam sendo referência para restrições e protocolo, não uma fila concorrente de trabalho.
