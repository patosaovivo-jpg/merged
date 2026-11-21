# AnimLab — Arena de Animações + Criador de Personagem (Godot 4.7.2)

## Recado para o Claude (orquestrador)
> **Não reanalise o diretório inteiro.** Este README + os arquivos listados abaixo são a fonte de verdade do estado atual. Foque apenas neles ao sugerir mudanças.

### Estado atual (atualizado em 2026-11-20)
- Projeto Godot 4.7.2 em `C:\0-BASE` (raiz: `project.godot`, `lab/`, `characters/`, `weapons/`, `animations/`).
- Git: `main`. Import headless OK; cena `res://lab/anim_lab.tscn` roda sem SCRIPT ERROR.
- Lab funcional: arena de animações (corpo dividido, combos, root motion), criador de personagem, loadouts, HUD de debug, mira TPS, projéteis procedurais e lock-on.
- Cache do banco em `user://lab_anim_cache_v4.res`; ele se reconstrói quando a lista/mtime dos FBXs muda.

### Implementações recentes
1. **Seek automático + pose offset nos combos** (`lab/combo_seek.gd`, `lab/pose_offset.gd`).
2. **Root motion** em ações "só cima" (X/Z, Y=0) e correção de locomoção em "só cima".
3. **Dodge/backflip** com deslocamento na velocidade de corrida (+ dodge lateral com lock-on).
4. **Câmera TPS over-the-shoulder** (`aim_shoulder_offset`, modo FPS opcional em `fps_mode`).
5. **Mira** (`lab/aim_system.gd`): crosshair procedural desenhado por `_draw()` no centro exato da tela; ray a partir do centro da viewport, com o RID do jogador excluído do raycast; ray aponta para o alvo em lock-on.
6. **Projéteis** (`lab/projectile.gd`, `lab/projectile_spawner.gd`): nascem na mão e a trajetória **converge para o `aim_point`** (o ponto sob o crosshair) — o tiro chega exatamente na mira mesmo com a mão se movendo; em lock-on convergem para o alvo. Pistola/rifle/arco com spread 0 (tiros repetidos caem no mesmo ponto); arco recebe compensação balística de gravidade. Impacto com partículas, anel, decal procedural e flash de luz. Cooldown e delay de spawn por arma.
7. **Lock-on estilo Dark Souls** (`lab/lock_on.gd`): botão do meio alterna; indicador 3D procedural (anel + marca). Movimento forte do mouse quebra o lock.
8. **Calibração de armas na mão** (`lab/weapon_debug.gd`): F9 liga um overlay grande com pos/rot da arma atual. Posição I/K (Y), J/L (X), U/O (Z); rotação T/G (rx), V/M (ry), B/N (rz); Shift = passo grande; 0 copia o código pronto para a área de transferência; Home restaura; ajustes salvos automaticamente em `weapon_overrides` no config.
9. **Locomoção em 4 direções** (`lab/loadouts.gd`, `lab/anim_db.gd`, `lab/lab_player.gd`): frente/trás/esquerda/direita. O banco classifica os clipes só nas 4 cardinais; clipes diagonais (`exact_dir = false`) são **descartados** na resolução dos slots. Se faltar um cardinal para a classe, o fallback usa outra cardinal (inclusive invertida) — nunca toca diagonal. Também evita clipes `arc`/`curve` (andam em curva). O runtime escolhe o slot em passos de 90° (sem histerese de 45° do esquema antigo) e esquerda/direita estão mapeados corretamente. Slots `walk_f/l/b/r` e `run_f/l/b/r`.
10. **Pistola e rifle alinhados ao cano real** (`lab/loadouts.gd`): pistola usa os ossos internos `Slide/Slide_end`; rifle usa o eixo longo da malha. Ambos apontam para o centro da mira e ficam em pé na pose de idle das armas.
11. **Pistola com animações próprias** (`lab/loadouts.gd`): o loadout `pistol` usa os clipes `pistol *` do pacote de armas **e** os clipes da raiz `animations/Pistol *` (idle, run, shooting, super shot). O `Pistol Run` é in-place e recebe velocidade nominal de 4 m/s. O botão direito dispara `animations/Pistol Shooting`; `animations/Pistol Super Shot` fica num dos especiais (teclas 1-8). O rifle exclui todos os clipes `pistol *` e usa os genéricos/`rifle *`.

### Controles principais
- WASD mover | Shift correr | Espaço pular | Q rolamento | F bloquear (segurar)
- Botão direito: ataque (melee) ou disparo (armas de distância)
- Botão do meio: lock-on | Esc: libera o mouse | Clique esquerdo na cena: captura o mouse
- F9: calibração de arma (I/K Y, J/L X, U/O Z; T/G rx, V/M ry, B/N rz; Shift passo grande; 0 copia; Home restaura)

### Arquivos-chave (leia estes)
- `lab/lab_player.gd` — player, física, combos, câmera, mira, disparo, lock-on.
- `lab/lab_rig.gd` — rig, AnimationTree, `play_action(..., seek_to)`.
- `lab/lab_ui.gd` — UI (abas Equipar/Visual/Teclas/Combo/Locomoção).
- `lab/anim_lab.gd` — orquestração, save/load de config.
- `lab/loadouts.gd` — loadouts, includes e transform base das armas (`WEAPONS`).
- `lab/aim_system.gd` — crosshair procedural, ray de mira, lock target.
- `lab/projectile.gd`, `lab/projectile_spawner.gd` — projéteis e FX.
- `lab/lock_on.gd` — lock-on e indicador.
- `lab/weapon_debug.gd` — calibração ao vivo de armas.
- `lab/combo_seek.gd`, `lab/pose_offset.gd` — seek/offset.
- `lab/anim_db.gd` — classificação de clipes (não alterar sem necessidade).
- `TESTAR_LAB.bat` — importa e abre o lab.

### Como testar
```bat
TESTAR_LAB.bat
```
Ou headless:
```bat
C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\0-BASE --quit-after 300 res://lab/anim_lab.tscn
```

### Restrições para sugestões
- Godot 4.7.2, GDScript.
- Não editar `anim_db.gd`, `lab_rig.gd`, `look*.gd`, `look_body.gdshader` sem necessidade explícita.
- FX sempre procedurais (sem PNG/SVG externos).
- Mudanças pequenas e testáveis com `TESTAR_LAB.bat`.
