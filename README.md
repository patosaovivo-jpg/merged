# AnimLab — Arena de Animações + Criador de Personagem (Godot 4.7.2)

## Recado para o Claude (orquestrador)
> **Não reanalise o diretório inteiro.** Este README + os arquivos listados abaixo são a fonte de verdade do estado atual. Foque apenas neles ao sugerir mudanças.

### Estado atual (atualizado em 2026-11-13)
- Projeto Godot 4.7.2 em `C:\0-BASE` (raiz: `project.godot`, `lab/`, `characters/`, `weapons/`, `ANIMATIONS/`).
- Git: `main`. Import headless OK; cena `res://lab/anim_lab.tscn` roda sem SCRIPT ERROR.
- Lab funcional: arena de animações (corpo dividido, combos, root motion), criador de personagem, loadouts, HUD de debug, mira TPS, projéteis procedurais e lock-on.

### Implementações recentes
1. **Seek automático + pose offset nos combos** (`lab/combo_seek.gd`, `lab/pose_offset.gd`).
2. **Root motion** em ações "só cima" (X/Z, Y=0) e correção de locomoção em "só cima".
3. **Dodge/backflip** com deslocamento na velocidade de corrida (+ dodge lateral com lock-on).
4. **Câmera TPS over-the-shoulder** (`aim_shoulder_offset`, modo FPS opcional em `fps_mode`).
5. **Mira** (`lab/aim_system.gd`): crosshair procedural desenhado por `_draw()` no centro exato da tela; ray a partir do centro da viewport, com o RID do jogador excluído do raycast; ray aponta para o alvo em lock-on.
6. **Projéteis** (`lab/projectile.gd`, `lab/projectile_spawner.gd`): nascem na mão, mas a direção de voo segue o ray da câmera (centro da tela) — trajetória estável mesmo com a mão se movendo; em lock-on convergem para o alvo. Impacto com partículas, anel, decal procedural e flash de luz. Cooldown e delay de spawn por arma.
7. **Lock-on estilo Dark Souls** (`lab/lock_on.gd`): botão do meio alterna; indicador 3D procedural (anel + marca). Movimento forte do mouse quebra o lock.
8. **Calibração de armas na mão** (`lab/weapon_debug.gd`): F9 liga o modo; numpad ajusta pos/rot da arma atual; KP_0 imprime os valores; overrides persistidos em `weapon_overrides` no config.

### Controles principais
- WASD mover | Shift correr | Espaço pular | Q rolamento | F bloquear (segurar)
- Botão direito: ataque (melee) ou disparo (armas de distância)
- Botão do meio: lock-on | Esc: libera o mouse | Clique esquerdo na cena: captura o mouse
- F9: calibração de arma (numpad 8/2/4/6 pos, PgUp/PgDn pos.z, 7/9 rot.z, 1/3 rot.x, +/- rot.y, 0 imprime)

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
