# Design e arquitetura inicial

Documento de planejamento preservado. A implementação final e suas responsabilidades estão em [ARQUITETURA_FINAL.md](ARQUITETURA_FINAL.md); funcionalidades e limites entregues estão no [README](../README.md). As propostas abaixo registram a intenção inicial e não são uma lista de arquivos existentes.

## Experiência

RTS 2D com aparência 2.5D, câmera superior inclinada e silhuetas claras. Uma partida local terá exatamente um jogador humano. Núcleo: implantar comando, explorar, coletar, construir, produzir, disputar território e destruir comandos inimigos. O modo territorial exigirá maioria dos pontos por um período configurável. Não haverá campanha nem rede.

Suprimentos são finitos por depósito, com regeneração opcional. Coletores transportam carga até uma refinaria; a renda ocorre na entrega. Energia é capacidade menos consumo: déficit reduz produção e desliga defesa/superarma conforme regra visível. Custos são debitados ao entrar na fila, com reembolso explícito por cancelamento.

Resistência: tropas combinadas, cura e recuperação tecnológica. Espheni: máquinas caras, controle e força tardia. Berserkers: mobilidade, saque, explosivos e menor durabilidade. Herói principal limitado a um por comandante, com recuperação e novo custo ao morrer. Unidade, estrutura, habilidade e tecnologia terão definições em dados, não regras espalhadas pela interface.

## Responsabilidades propostas

| Pasta ou sistema | Responsabilidade |
| --- | --- |
| `src/core/match.gd` | Relógio, comandantes, regras, início/fim e estatísticas |
| `src/core/catalog.gd` | Leitura e validação dos dados |
| `src/core/settings.gd` | ConfigFile em user://, opções, volumes e teclas |
| `src/systems/economy.gd` | Saldos, capacidade de energia, gasto/reembolso |
| `src/systems/production.gd` | Filas, requisitos, população e ponto de encontro |
| `src/systems/navigation.gd` | Grade, AStarGrid2D, recálculo limitado e formação |
| `src/systems/vision.gd` | Visível/explorado por comandante e último contato |
| `src/systems/combat.gd` | Aquisição por índice espacial, dano, cura e conversão |
| `src/systems/superweapons.gd` | Estrutura, recarga, avisos, impactos e áreas |
| `src/systems/cheats.gd` | Quatro opções, escopo humano, reset e indicador |
| `src/entities/` | Componentes e estados de unidades/construções |
| `src/ai/commander.gd` | Planejamento econômico, reconhecimento e esquadrões |
| `src/ui/` | Menu, HUD, minimapa, pausa, cheats e resultado |
| `data/` | Facções, unidades, construções, mapas e balanceamento |
| `tests/` | Cenários determinísticos, invariantes e relatórios |

Estados explícitos: ocioso, movendo, atacando, coletando, retornando, construindo, guarnecido e destruído. Ordens usam identificadores e posições; não referenciam elementos de interface. Seleção não altera simulação. A UI consulta os mesmos custos e requisitos usados na validação da ordem.

## Visibilidade e IA

Cada comandante possui economia, produção, visão e memória próprias. Uma API de consulta filtrada entrega somente entidades visíveis e posições anteriormente observadas. A IA explora setores desconhecidos; não recebe posições inimigas atuais através de acesso irrestrito ao mundo. Coalizão define relações de hostilidade explicitamente. Todas as IAs pagam os mesmos custos do jogador.

Casual terá reação mais lenta, reconhecimento menos frequente e grupos menores. Difícil investirá e reagirá mais cedo, comporá tropas contra ameaças observadas, usará rotas alternativas e recuará feridos. Não haverá bônus oculto de recursos, vida ou dano. Os tempos de `data/ai.json` são hipóteses iniciais que precisam de testes.

## Orçamento de desempenho

Renderização Compatibility; sem luzes dinâmicas ou shaders pesados. Física e movimento separados de decisões econômicas. Limitar consultas de combate com grade espacial; distribuir IA e visão ao longo dos quadros. Reutilizar efeitos/projéteis de alta frequência quando medições justificarem. Não empregar busca global de todas as unidades contra todas a cada quadro.

Proposta inicial de população: `min(60, floor(270 / número_de_comandantes))` por comandante, contando humano e IAs. Com oito adversários: 30 por comandante, até 270 unidades móveis no total. Estruturas e efeitos têm limites próprios; mostrar teto na configuração. Valores sujeitos a medição real.

Mapas maiores ganham setores com recursos e pontos disputáveis, rotas alternativas e edifícios ocupáveis. Posições iniciais distribuídas em anel ou setores, com depósito seguro próximo e distância mínima validada. Catálogo não substitui autoria e teste dos mapas.

## Superarmas e cheats

Nuclear: dano radial decrescente e radiação. Nêutrons: dano biológico, interrupção tecnológica e dano estrutural moderado. Termobárica: dispersão, explosão e fogo persistente. Todas têm aviso anterior ao impacto, marca no minimapa, recarga e possibilidade de fuga.

Cheats começam desligados e só estão disponíveis se autorizados na configuração da partida. Recursos infinitos interceptam gastos do jogador; invencibilidade bloqueia dano e conversão; superarma instantânea respeita a facção; revelação altera somente a visão humana. Toda ativação marca o placar. Desligar revelação restaura visibilidade dinâmica, preservando somente o terreno explorado. Separar permissão de superarmas normais do desbloqueio explícito via cheat e informar isso na UI.

## Estratégia de verificação

Testes de invariantes para recursos, filas, limites, energia e ciclo de heróis. Cenários com unidades atrás da névoa para detectar informação indevida na IA. Partidas com semente fixa para vitória, derrota e modos territoriais. Combinações de cheats contra combate e conversão. Testes visuais de seleção, minimapa, escala, efeitos e avisos no executável Windows. Registrar desempenho gráfico separadamente de testes headless.
