# ANIM LAB — arena de animações Mixamo + CRIADOR DE PERSONAGEM (Godot 4)

## Como usar
1. Extraia esta pasta `lab/` na RAIZ do projeto (ao lado de `characters/`, `weapons/`, `ANIMATIONS/`).
2. Abra o projeto no Godot, espere o editor reconhecer os scripts.
3. Abra `res://lab/anim_lab.tscn` e aperte **F6** (ou defina como Cena Principal e aperte F5).

A 1ª abertura varre `res://ANIMATIONS` (todas as subpastas) e classifica os clipes; depois fica em cache
(`user://lab_anim_cache_v2.res`). Se adicionar FBX novos, o cache se refaz sozinho (ou botão "Recarregar animações").

## Controles
| Entrada | Ação |
|---|---|
| WASD | mover (relativo à câmera) |
| Shift | correr (sem Shift = andar) |
| Mouse | câmera (clique esquerdo na cena captura; Esc libera p/ usar o menu) |
| Botão direito | ataque / combo (clique de novo durante o golpe p/ encadear) |
| 1 … 8 | animações escolhidas nos dropdowns (aba **Teclas**) |
| Q | rolamento/esquiva (corpo todo) |
| Espaço | pular |
| F (segurar) | bloquear (pose só na parte de cima) |
| Alt (segurar) | corpo mira p/ câmera (strafe temporário) |
| R | parar a ação atual |
| Roda do mouse | zoom da câmera |

## Corpo dividido
- Pernas = locomoção. Parte de cima = locomoção até uma ação tocar.
- Modo **Auto** de cada tecla: movendo → só a parte de cima (pernas continuam); parado → corpo todo.
- Pulo, rolamento, dano e morte sempre usam o corpo todo (com root motion quando o clipe tem).
- Cada tecla pode ser forçada em "Só cima" ou "Corpo todo". Ponto de divisão ajustável (cintura/peito/ombros).

## Rolamento
O pacote atual NÃO tem clipe de rolamento: Q usa "jump forward" como esquiva. Coloque um FBX do Mixamo com
`roll`, `dodge`, `dive` ou `flip` no nome em `ANIMATIONS/` e ele é detectado e usado automaticamente
(ou escolha manualmente na aba Teclas → [Q] rolamento).

## Arquivos
- `anim_db.gd`   varre/classifica clipes (idle, locomoção + direção + velocidade, ataque, etc.) e trava root motion
- `loadouts.gd`  armas, combos, teclas padrão e resolução automática dos slots de locomoção
- `lab_rig.gd`   personagem + AnimationTree com filtro de ossos (cima/baixo) + armas nas mãos
- `lab_player.gd` movimento, câmera, combos, bindings
- `lab_ui.gd`    menu lateral
- `anim_lab.gd/.tscn` arena + salvar configurações (`user://anim_lab_config.cfg`)
- `lab_dummy.gd` boneco de treino

## Ajustes finos
- Encaixe das armas: `WEAPONS` em `loadouts.gd` (scale, pos, rot por arma).
- Combos/teclas padrão de cada arma: lista `all()` em `loadouts.gd` (chain / specials).


---
# Criador de personagem (aba "Visual")

Usa os SEUS corpos (macho.fbx / femea.fbx, malha única) e mantém todo o sistema de animação, armas e combos.
Como os corpos não têm peças separadas, o visual é montado assim:

| O que | Como funciona |
|---|---|
| Camisa, calça, calçado, luvas, cinto, acabamento | **Shader por região** (`look_body.gdshader`): pinta e dá volume à própria malha. Dá para ajustar manga, barra, decote, comprimento da calça, cano da bota, cano da luva, altura do cinto |
| Pele / cor / rugosidade / metal | uniforms do shader (1 material, 1 draw call no corpo) |
| Cabelo (10 estilos), chapéus (6), barba (4), olhos, sobrancelhas, boca, nariz, orelhas, óculos, ombreiras, mochila/capa/aljava, bolsas, cachecol/colar | **peças lowpoly procedurais** presas aos ossos (`look_parts.gd`), posicionadas a partir da medida da cabeça de cada corpo |
| Altura, peito/ombros, braços, pernas, cabeça | escala de ossos (as animações não têm tracks de escala, então funcionam com tudo) |
| Aleatório, salvar, carregar, resetar | `look.gd`; salva JSON em `res://lab/personagens/*.char.json` (no editor) ou `user://personagens/` |

Câmera de vitrine: ao abrir a aba Visual a câmera foca no personagem (botões Corpo / Rosto / Costas / Pés,
arraste com o botão esquerdo para girar, roda do mouse dá zoom, "Girar sozinho"). Você pode andar, atacar e
usar as teclas 1-8 com a aba aberta para ver o visual em movimento.

## Escala da fêmea (padrão único)
O `femea.fbx` vem exatamente 100x menor que o `macho.fbx`. O arquivo `characters/femea.fbx.import` desta pasta já
define `Root Scale = 100`: o Godot reimporta e as duas ficam com 2,00 m. (Manual: selecione `femea.fbx` →
aba Importar → Root Scale = 100 → Reimportar.) O laboratório ainda tem um ajuste automático de reserva.

## Arquivos novos
`look.gd` (configuração/aplicar/aleatório/salvar), `look_body.gd` + `look_body.gdshader` (corpo vestível),
`look_parts.gd` (catálogo de peças), `lab_ui_visual.gd` (aba Visual).

## Para adicionar mais estilos
- Novo estilo de cabelo/chapéu/etc.: adicione o nome na lista de `look_parts.gd` e um `case` no builder correspondente.
- Novas cores de paleta: listas `SKIN`, `HAIR_COL`, `CLOTH_COL`... em `look.gd`.
