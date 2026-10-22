# Cartas — Reinos do Destino (Godot)

Primeira base jogável para celulares, em **Godot 4.3+**, orientação retrato.

## Abrir
1. Instale Godot 4.3 ou mais recente.
2. Importe a pasta `godot/` como projeto (arquivo `project.godot`).
3. Abra `scenes/Main.tscn` e pressione **F6**, ou pressione **F5** para executar o projeto.
4. Use a configuração de janela vertical; a cena se adapta à área disponível.

## Jogabilidade
- Selecione uma carta na mão.
- Toque em um herói aliado para escolher o atacante/usuário da carta.
- Toque em um herói inimigo para escolhê-lo como alvo.
- Utilize **Jogar carta**, **Atacar**, **Ás** ou **Encerrar**.
- O adversário executa um turno simples automaticamente.

## Estado
**Protótipo inicial**, ainda não pronto para lojas. Cartas exibidas como painéis provisórios, sem as artes aprovadas. Coringas e algumas habilidades especiais estão simplificados. Ainda são necessários: testes de compilação no Godot, implementação fiel de todas as regras, revisão da interface mobile, integração das artes, efeitos e áudio.

A versão web permanece em `/index.html` e não foi alterada.

## Correção de artes e interação

O catálogo `scripts/card_art.gd` identifica visualmente todas as 48 imagens originais.
Inclui os 12 personagens, 4 Ases, 30 cartas numeradas de Copas/Espadas/Paus e 2 Coringas.
As imagens numeradas de Ouros não foram fornecidas: suas cartas mantêm a representação textual, sem usar arte de outro naipe. Os valores 1 ficam no catálogo; o baralho jogável continua de 2 a 10, conforme as regras.

Selecione um herói, escolha uma carta e um alvo e toque Jogar, ou arraste a carta da mão até um alvo compatível. As informações de vida, defesa, escudo e custo ficam sobre as artes. A interface usa colunas flexíveis e rolagem de segurança para telas baixas; a mão possui rolagem horizontal.

Teste de regressão (Godot 4.3):
`godot --headless --path godot --script res://tests/smoke.gd`

Verifica as 48 texturas, os seis heróis, larguras de 320 a 1024, alvos, energia, dano, cura, animação, descarte e retorno do turno da IA. A publicação Web só prossegue se esse teste passar.

## Atualização: habilidades e combate estilo duelo de cartas
- **Tocar ou arrastar:** arraste uma carta da mão sobre um herói, ou arraste um herói seu sobre um inimigo para atacar. Também funciona por toque: toque no alvo e toque de novo para confirmar.
- **Alvos brilham:** verde para aliados válidos e vermelho para inimigos válidos. O herói ativo fica com borda verde.
- **Painel de habilidades:** mostra o efeito da carta escolhida, as passivas e o Ás do herói, e uma prévia do dano.
- **Habilidades implementadas:** as 4 cartas de naipe (afinidade +1), os 4 Ases, Coringa Vermelho (Adaptabilidade) e Coringa Azul (Transformação, com escolha de naipe), passivas K♣, J♠, J♣, Q♦ e a Guarda do K♥, além de escudos, perfuração e limite de mão.
- **Defender:** troca o ataque do turno por +2 escudos no herói ativo.
- **Efeitos:** avanço ao atacar, números flutuantes, brilho e tremor ao receber dano, cristais de energia e faixa de turno.
- **Rival:** joga Ás, carta e ataque em etapas visíveis.
- A fonte padrão não tem símbolos de naipe; a interface usa só texto e formas desenhadas.
