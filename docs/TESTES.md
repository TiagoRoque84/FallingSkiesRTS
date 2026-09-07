# Testes da versão 1.0

Validação em 7 de setembro de 2026, no computador do usuário. Executável final: **122.735.552 bytes** (117,05 MiB). SHA256:

    13716D18128517B631B611E51BF8592646C54BE3B8D4AB7F4E5E00F503CFA52D

## Ambiente

Windows, Intel Core i3-7100 (2 núcleos/4 threads), aproximadamente 16 GB de RAM, Intel HD Graphics 630. Godot 4.7.2 Standard, GDScript, renderizador Compatibility. O motor selecionou automaticamente ANGLE/Direct3D 11, driver reportado 31.0.101.2140, após aviso sobre o suporte OpenGL. Nenhum driver ou configuração de sistema foi alterado.

As execuções gráficas usaram janela de 1280 × 800, desenho 2D, sem iluminação 3D. O jogo exportado foi executado diretamente, sem editor. Arte final inclui edifícios de três facções, tropas e utilitários direcionais, ambiente, texturas e fundo do menu.

## Verificações automáticas

| Suíte | Resultado | Evidência |
| --- | --- | --- |
| Regras: economia, energia, filas, custos, população, heróis, cheats, superarmas, mapas e resultados | 124 passaram, 0 falhas | tests/rules_report.json |
| Captura, conversão temporária, coalizão, superarmas da IA e derrota humana | 13 passaram, 0 falhas | tests/advanced_report.json |
| Menu, início, implantação, construção, seleção, grupos, ordens, pausa, cheats, reinício e placar | 25 passaram, 0 falhas | tests/ui_report.json |

**162 verificações passaram.** Os testes de interface acionam sinais de botões e eventos de entrada dentro do Godot; não são testes manuais de cliques no Windows. As capturas produzidas foram inspecionadas visualmente. As suítes de lógica usam execução headless; seus tempos não representam desempenho gráfico.

Foram corrigidos durante o desenvolvimento: manutenção da ordem de ocupação, alcance de captura do engenheiro, restauração de unidades convertidas, reserva de população em filas/conversões, reembolso com cheat de recursos, soma territorial da coalizão, ciclo de referência da IA, áudio no modo headless e inversão vertical de UV nos sprites.

## Partidas completas sem cheats

tests/matches.gd usa a simulação normal com um controlador automatizado no lugar do humano exclusivamente no teste. O jogo distribuído mantém o humano no controle do comandante zero.

| Dificuldade | Duração simulada | Resultado do lado humano automatizado | Recursos coletados, lados 0/1 | Unidades produzidas, lados 0/1 |
| --- | ---: | --- | ---: | ---: |
| Casual | 496,8 s | Derrota | 27.840 / 31.140 | 94 / 80 |
| Difícil | 417,1 s | Vitória | 25.830 / 18.600 | 77 / 63 |

As duas partidas terminaram por regras normais, com coleta e gastos efetivos. Relatório completo: tests/matches_report.json. Esses dois resultados não provam equilíbrio estatístico entre facções ou dificuldades.

No cenário adicional de humano passivo, a IA venceu aos **155,7 segundos simulados**, coletando 11.070 suprimentos e produzindo 33 unidades. Cenários separados confirmaram que a IA não dispara a superarma contra um alvo desconhecido e consegue disparar quando o alvo fica visível, nas duas dificuldades.

## Desempenho do executável final

| Cenário preparado | Duração medida | Quadros | FPS médio | Mediana do quadro | Percentil 95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ruínas de Boston, 1 × 1, bases e tropas preparadas | 45,01 s | 2.604 | **57,9** | 16,67 ms | 20,00 ms |
| Torre Espheni gigante, oito IAs Difíceis, 270 unidades regulares iniciais, neutros e mapa revelado | 45,01 s | 1.915 | **42,5** | 20,10 ms | 33,33 ms |

FPS médio = quadros / segundos registrados. Percentil 95 é tempo de quadro: 95% das amostras ficaram nesse valor ou abaixo. Não é FPS mínimo. A medida usa o delta de quadro informado pelo motor.

O estresse começa com população preparada e tropas enviadas ao centro; há perdas durante o teste. O campo legado "units" dos JSON registra **todas as entidades restantes, incluindo prédios**: 56 no 1 × 1 e 209 no estresse. Não representa população inicial nem pico.

Relatórios finais:
- tests/release_normal/graphics_report.json
- tests/release_giant/graphics_report.json

Cada pasta também contém gameplay_capture.png. Os relatórios graphics_report.json fora dessas duas pastas são medições intermediárias e não os números finais. Os logs locais registram o aviso de seleção do ANGLE, sem erro de script nas execuções finais.

Essas janelas curtas confirmam funcionamento gráfico e um patamar inicial de desempenho. Não garantem 60 FPS, ausência de quedas em batalhas longas, desempenho idêntico em tela cheia ou estabilidade de horas. Uma partida normal começa com comando móvel e poucas tropas, diferentemente dos cenários preparados.

## Reproduzir

Execute as suítes listadas no README. Para medir o executável, crie antes a pasta de relatório e use um caminho absoluto:

    ./builds/FallingSkies.exe -- --benchmark --report-dir=D:/caminho/absoluto/relatorio

Troque --benchmark por --qa para o cenário 1 × 1. Ambos encerram automaticamente após 45 segundos; --bench-seconds=60 altera a duração. Esses argumentos são de diagnóstico e não são necessários para jogar.

## Limites conhecidos

Não há bloqueador conhecido nos cenários testados. O balanceamento foi validado por partidas determinísticas e precisa de mais experiência humana para ajuste fino. Infantarias especializadas compartilham modelos-base; movimento usa oito orientações e oscilação leve. Os mapas são layouts por regras, com visual 2D/2.5D. Não há campanha, multiplayer ou salvamento de partidas. O objetivo gráfico entregue é uma estética detalhada de RTS clássico, sem promessa de identidade visual exata com Command & Conquer ou fotorrealismo.
