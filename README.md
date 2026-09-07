# Falling Skies: Guerra pela Terra

RTS de fã para uso pessoal, gratuito e offline, em português brasileiro.

## Estado atual

**Etapa 0: preparação. Ainda não há jogo executável ou partida jogável.**

O projeto foi iniciado a partir de `../Prompt_Mestre_Falling_Skies_RTS.md`. A especificação é a referência de produto; requisitos e tarefas pendentes estão em `docs/PLANO.md`.

Godot não foi encontrado no PATH ou nas pastas comuns verificadas. O download da ferramenta e dos modelos de exportação depende da autorização solicitada ao usuário. Git 2.49.0, Python e Node estão disponíveis; apenas Godot e Git serão necessários ao desenvolvimento regular.

## Organização

- `docs/PLANO.md`: etapas, critérios e dependências.
- `docs/DESIGN.md`: regras e arquitetura inicial.
- `data/maps.json`: catálogo dos seis mapas previstos, com limites de adversários.
- `data/ai.json`: parâmetros iniciais das dificuldades; ainda não balanceados.
- `src/`: scripts GDScript, a implementar.
- `scenes/`: cenas Godot, a implementar.
- `assets/`: arte e áudio originais, a produzir.
- `tests/`: testes de mecânicas e partidas automatizadas, a implementar.
- `tools/`: futura cópia portátil do Godot, excluída do Git.
- `builds/`: futuros executáveis Windows, excluídos do Git.

## Como abrir neste momento

Abra os documentos de `docs/` para revisar a preparação. Não há ainda `project.godot` ou `.exe`; instruções de execução, controles e exportação serão acrescentadas depois de implementadas e testadas.

## Recursos e licenças

Nenhum recurso externo de arte, música, voz ou modelo foi incorporado. Nomes e referências à série são usados como tema do projeto pessoal de fã; isso não atribui direitos sobre a propriedade intelectual original. O código e os recursos produzidos serão próprios. As licenças das dependências efetivamente distribuídas deverão acompanhar a versão final, incluindo a licença MIT do Godot e seus avisos de terceiros.

## Limitações atuais

Todas as mecânicas, artes, áudio, executáveis e testes de desempenho ainda estão pendentes. Os arquivos JSON são propostas de configuração, não evidência de conteúdo jogável. Não houve alteração de configurações do sistema, instalação ou publicação remota.
