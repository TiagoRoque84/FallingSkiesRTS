# Plano executado — versão 1.0

Atualização: 7 de setembro de 2026. Estado: implementação e exportação concluídas; evidências em [TESTES.md](TESTES.md).

## Etapa 0 — Preparação

- [x] Documento original lido e preservado fora da pasta exclusiva do projeto.
- [x] Hardware conferido: Core i3-7100, 16 GB de RAM, Intel HD Graphics 630.
- [x] Projeto e Git local criados; design inicial registrado.
- [x] Usuário autorizou seguir com todas as etapas e pediu maior realismo compatível com a máquina.
- [x] Godot 4.7.2 Standard e templates Windows oficiais baixados e verificados por SHA512.
- [x] Motor portátil em tools/, sem instalação de serviços ou mudanças de drivers/PATH.

## Etapas 1 e 2 — Núcleo e Skirmish

- [x] Arena, câmera, seleção por clique/caixa, grupos e navegação AStar.
- [x] Comando implantável, construção, energia, filas e reembolso.
- [x] Coletores transportam suprimentos até a refinaria; depósitos finitos e regeneração opcional.
- [x] Combate, cobertura, ocupação, minimapa, visão por comandante e alertas.
- [x] Menu, configuração, opções persistentes, dicas, pausa, reinício, vitória/derrota e placar.
- [x] IA com economia real, reconhecimento, produção, expansão, ataques e recuo.
- [x] Executável Windows aberto e renderizado sem o editor.

## Etapa 3 — Conteúdo

- [x] Três facções com atributos, nomes, edifícios, veículos e heróis próprios.
- [x] Seis mapas determinísticos, cobrindo os quatro tamanhos.
- [x] Um humano contra 1–8 IAs conforme limite do mapa; facções, cores, FFA e coalizão.
- [x] Casual e Difícil parametrizados; recursos, velocidade, domínio, neutros e regeneração configuráveis.
- [x] Pesquisa, habilidades, reparos, captura, conversão e cura.
- [x] Três superarmas com requisitos, energia, recarga, aviso e efeitos persistentes.
- [x] Quatro cheats independentes, remapeáveis, exclusivos do humano e reiniciados por partida.

## Etapa 4 — Arte, desempenho e validação

- [x] Formas provisórias substituídas por atlas originais de edifícios, tropas, veículos e cenário.
- [x] Arte com aparência pré-renderizada, oito direções, texturas e áudio sintetizado original.
- [x] MultiMesh para sprites, cache de terreno/minimapa, visão em rodízio, índice espacial e cache de construções.
- [x] Teto de 270 unidades regulares e decisões de IA distribuídas.
- [x] 124 verificações de regras, 13 avançadas e 25 de interface passaram.
- [x] Partidas completas Casual e Difícil, sem cheats, terminaram nos testes automatizados.
- [x] Cenário adicional confirmou que a IA derrota um humano passivo.
- [x] Capturas revisadas; orientação vertical dos atlas corrigida e coletores diferenciados.
- [x] Executável final medido graficamente em 1 × 1 e mapa gigante com oito IAs. Valores e limites em TESTES.md.

## Etapa 5 — Entrega

- [x] Executável offline e código-fonte organizados.
- [x] README em português com controles, edição, exportação e limitações.
- [x] Licenças do motor e terceiros, créditos e prompts de arte preservados.
- [x] Atalho JOGAR.cmd, pacote portátil ZIP e histórico Git local.
- [x] Relatórios e capturas incluídos em tests/.

## Escopo efetivo

A primeira versão é um RTS 2D/2.5D jogável. As unidades sugeridas no documento foram consolidadas em arquétipos comuns com variações por facção; não há modelo exclusivo para cada especialização de infantaria. Não se promete reprodução visual idêntica a Command & Conquer ou fotorrealismo 3D. Não há campanha, multiplayer ou salvamento de partida.

As partidas de validação foram automatizadas no motor; não equivalem a sessões longas de teste humano. O teste gráfico mede janelas de 45 segundos e não garante FPS constante durante toda partida. Não há erro bloqueador conhecido após os testes registrados.
