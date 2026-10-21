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
