# Plano de execução

Atualização: 7 de setembro de 2026. Estado: preparação concluída, download de dependências aguardando autorização.

## Preparação executada

- [x] Ler a especificação original sem modificar o arquivo.
- [x] Inspecionar a pasta de trabalho: continha somente o documento original.
- [x] Verificar ferramentas no PATH e procurar Godot nas pastas comuns de programas, Downloads, Desktop e projeto.
- [x] Confirmar Git 2.49.0.windows.1, Python e Node disponíveis.
- [x] Criar pasta exclusiva `D:/COMMAND E CONQUER FALLING SKIES/FallingSkiesRTS`.
- [x] Definir arquitetura e parâmetros iniciais em arquivos separados.
- [ ] Obter autorização para baixar e extrair Godot e modelos de exportação.
- [ ] Confirmar versão executável, importar projeto e testar renderização Compatibility.

## Dependências propostas

1. Godot 4.7.2 estável, edição Standard Windows x86_64, com GDScript. A página oficial de Windows consultada em 07/09/2026 oferece essa versão. Não usar edição .NET.
2. Modelos de exportação da **mesma versão**, necessários para gerar um executável que funciona sem o editor.

Fonte: https://godotengine.org/download/windows/
Exportação: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html

Proposta de operação: baixar os arquivos oficiais, conferir os checksums publicados quando disponíveis e extrair em `FallingSkiesRTS/tools/`. Usar modo autocontido para manter os dados do editor no projeto. Não instalar serviços, alterar PATH, registro, drivers ou políticas do Windows. Não exigir privilégios administrativos. Nenhum download foi realizado nesta etapa.

Reserva estimada: **3 GB** para downloads, extração, projeto, cache de importação e primeiros executáveis. É margem de planejamento, não uma medição dos pacotes. O pacote de modelos contém plataformas adicionais; conservar apenas o necessário à exportação Windows após validação. O jogo final deverá ocupar muito menos, com tamanho efetivo registrado na entrega.

## Etapa 1 — Núcleo jogável

- [ ] Criar projeto Godot 2D, Compatibility/OpenGL, janela redimensionável.
- [ ] Arena, câmera, seleção por clique e caixa, ordens e navegação por grade.
- [ ] Comando implantável, geração de energia, construção e filas com custos.
- [ ] Coletor: depósito finito → carga → refinaria → crédito de suprimentos.
- [ ] Combate, destruição, vitória e derrota.
- [ ] Testar custos, dano, bloqueios e conclusão da partida no motor.

## Etapa 2 — Partida completa 1 × 1

- [ ] Ruínas de Boston; Resistência contra Espheni.
- [ ] Menu inicial, configuração, opções salvas e dicas contextuais.
- [ ] Névoa, minimapa, alertas, pontos de encontro e grupos de controle.
- [ ] IA Casual com economia real e conhecimento limitado à visão.
- [ ] Exportar Windows e executar sem editor.

## Etapa 3 — Conteúdo e sistemas

- [ ] Três facções assimétricas com estruturas, unidades e herói principal único.
- [ ] Quatro mapas iniciais: Escola, Boston, Estrada e Torre; adicionar os outros dois após estabilidade.
- [ ] Um jogador humano e 1–8 comandantes independentes; facções, cores, coalizão ou todos contra todos.
- [ ] Dificuldades, recursos iniciais, velocidade, vitória territorial, ameaças neutras e regeneração configuráveis.
- [ ] Tecnologias, patrulha, atacar-mover, parar, guardar, cobertura e ocupação de edifícios.
- [ ] Três superarmas distintas, estrutura, energia, recarga, aviso e área persistente.
- [ ] Cheats centralizados: recursos, invencibilidade, superarma instantânea e revelar mapa; remapeamento e reset por partida.
- [ ] Pausa, reinício, abandono e placar completo.

## Etapa 4 — Qualidade e desempenho

- [ ] Substituir formas provisórias por arte original consistente e áudio original.
- [ ] Volumes separados, escala de interface e controles em português.
- [ ] Testar cada mapa: acessibilidade das bases, recursos, rotas e expansões.
- [ ] Partidas automatizadas com sementes repetíveis nas duas dificuldades.
- [ ] Medir FPS e tempo de quadro em execução gráfica no computador disponível.
- [ ] Estresse gigante com oito IAs e população máxima; registrar p50/p95 dos quadros, duração e ambiente real.
- [ ] Corrigir concentração de decisões da IA, navegação e efeitos antes de reduzir conteúdo.

## Etapa 5 — Entrega

- [ ] Jogo Windows offline exportado e testado fora do editor.
- [ ] Partida Casual e Difícil completas, incluindo possibilidade real de derrota.
- [ ] Cheats individualmente e combinados; validar invencibilidade contra superarmas e proteção contra conversão.
- [ ] Validar que cheats não beneficiam inimigos e não persistem na partida seguinte.
- [ ] Validar limites de mapas, população, facções, heróis e superarmas.
- [ ] README de execução, controles, edição e exportação; licenças e limitações reais.
- [ ] Histórico Git local e relatório final de testes.

Não marcar uma etapa jogável nem prometer FPS com base apenas em inspeção de código ou simulação sem renderização. Após cada etapa registrar arquivos, teste executado, resultado e pendências neste documento.
