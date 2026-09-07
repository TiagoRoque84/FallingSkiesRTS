# Arquitetura da versão jogável

- main.gd: menus, HUD, entrada, pausa, áudio, opções e partida atual.
- battle.gd: estado de entidades, economia, filas, combate, suporte, domínio, superarmas e conclusão. IDs estáveis e estados explícitos; remoções após atualização.
- battle_map.gd: seis layouts determinísticos, recursos, ocupação, cobertura e AStarGrid2D. Construções bloqueiam células; extremos dos caminhos são ajustados para células livres.
- commander_ai.gd: um controlador por inimigo, com visão e memória próprias, custos e coleta reais. Referência fraca evita ciclo de memória.
- cheats.gd: permissão, flags e histórico. Consultas verificam proprietário e reiniciam por partida.
- battle_view.gd: câmera, minimapa, áreas e seleção. Terreno é montado uma vez; névoa e minimapa usam cache.
- sprite_batch.gd: MultiMesh 2D e um shader simples de amostragem de atlas. Sem luzes 3D ou pós-processamento caro.
- sprite_bank.gd: atlas, coordenadas, direções e ícones.
- settings.gd: ConfigFile em user://.
- catalog.gd e data/*.json: definições e balanceamento.

## Desempenho

Passos de simulação de 50 ms. IA escalonada; visão em rodízio por comandante; índice espacial para vizinhança; cache de construções prontas. Pontos atualizados a cada 250 ms, auras a cada 500 ms.

Teto regular de 270 unidades móveis repartido entre comandantes. Filas reservam vagas e conversões preservam a reserva original. Efeitos limitados a 220 registros. Unidades são registros leves e sprites usam lotes persistentes; não foi necessário pooling genérico de objetos.

## Verificação

rules.gd verifica invariantes; advanced.gd testa captura, conversão, coalizão, superarmas da IA e derrota humana; matches.gd completa partidas com um controlador no lugar do humano apenas no teste. ui_flow.gd percorre menus e entradas do Godot e salva capturas. O jogo normal nunca cria uma IA para o humano.

O modo de diagnóstico --benchmark começa com bases e população preparadas e névoa revelada. Esse cenário de estresse difere da partida normal iniciada pelo menu. Não há conta, servidor ou serviço online.
