# Regulamento de testes v1.1

**Status:** protótipo, sujeito a balanceamento.

## Objetivo
Primeiro a 12 Pontos de Glória ou eliminação de todos os heróis rivais.

## Cartas
12 figuras (4 Reis, 4 Rainhas, 4 Valetes), 4 Ases, 36 numeradas (2 a 10), 2 Coringas. Numeradas e Coringas compõem baralho de compra de 38 cartas.

## Preparação
Dois jogadores, três heróis cada. Três cartas iniciais por jogador. Energia inicial 3 (máximo 6). Vida/ATQ/DEF: Rei 14/4/3; Rainha 11/2/2; Valete 9/3/1.

## Turno
Receba 2 Energia; compre uma carta (exceto primeiro turno do primeiro jogador); jogue no máximo uma carta numerada ou Coringa; ative até um Ás; ataque uma vez; descarte excedentes acima de cinco cartas.

## Cartas numeradas
2–4: custo 1, potência 1. 5–7: custo 2, potência 2. 8–10: custo 3, potência 3. Herói do mesmo naipe: +1 potência.
- Copas: cura 1 + potência.
- Ouros: gera potência em Energia e concede 1 + potência escudos.
- Espadas: +potência no ataque e ignora 1 DEF.
- Paus: +potência no ataque e 1 escudo.

## Ases
Custo 2, herói vivo do mesmo naipe; máximo um por turno. Copas: cura 3 e escudo 1; Ouros: Energia 3; Espadas: compra 2 e descarta 1; Paus: +2 ATQ no próximo ataque.

## Coringas
Custo 3, contam como a carta do turno. Vermelho: Adaptabilidade, imita efeito básico de carta numerada nível 8 sem afinidade. Azul: Transformação, muda naipe de carta da mão (custo da carta transformada ainda pago) ou redireciona efeito válido. **A interface inicial utiliza simplificações temporárias dessas habilidades.**

## Combate
Dano inicial = máximo(1, ATQ + bônus − DEF efetiva). Reduções de dano antes de escudos, depois dano à Vida. Escudos (máximo 4) expiram no início do próximo turno de seu proprietário.

## Glória
+1 PG se causar pelo menos 3 PV de dano à Vida em um turno; +2 por derrotar Valete; +2 por derrotar Rainha; +3 por derrotar Rei; +2 se todos os três heróis sobreviverem até o fim da quinta rodada. Bônus por dano no máximo uma vez por turno.

## Fim do baralho
Reembaralhe o descarte uma vez. No segundo esgotamento, conclua a rodada e compare Glória, Vida total e Energia.

## Nota
A versão digital inicial implementa um subconjunto operacional destas regras. Consulte README para as diferenças conhecidas; não use o protótipo como validação definitiva do balanceamento.
