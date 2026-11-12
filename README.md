# AnimLab — Arena de Animações + Criador de Personagem (Godot 4.7.2)

## Recado para o Claude (orquestrador)
> **Não reanalise o diretório inteiro.** Este README + os arquivos listados abaixo são a fonte de verdade do estado atual. Foque apenas neles ao sugerir mudanças.

### Estado atual (atualizado em 2026-11-12)
- Projeto Godot 4.7.2 em `C:\0-BASE` (raiz: `project.godot`, `lab/`, `characters/`, `weapons/`, `ANIMATIONS/`).
- Git: `main` sincronizado com `origin/main` (commit `67582db`).
- Import Godot headless: OK. Abertura da cena `res://lab/anim_lab.tscn`: sem SCRIPT ERROR.
- Lab funcional: arena de animações (corpo dividido, combos, root motion), criador de personagem (shader + peças procedurais), loadouts, HUD de debug.

### Implementações recentes (Tarefas 1–6)
1. **Seek automático + pose offset nos combos** (`lab/combo_seek.gd`, `lab/pose_offset.gd`): pré-cálculo de seek por par da chain; disparo com seek; offset de pose com decay.
2. **Root motion em OSU**: aplicado em X/Z (Y=0) para ações “só cima”.
3. **“Só cima” não trava locomoção**: `locked_full` separa travamento de pernas vs cancelamento/rm.
4. **Dodge/backflip com velocidade real**: `max(cur_speed, run_speed)`, direção frente (em movimento) ou trás (parado).
5. **Config persistente**: `use_combo_seek`, `combo_seek_decay` salvos/carregados.
6. **HUD debug**: linha de seek no `debug_text()`.

### Arquivos-chave (leia estes)
- `lab/lab_player.gd` — player, física, combos, trigger de ações, `_act_frac()`.
- `lab/lab_rig.gd` — rig, AnimationTree, `play_action(..., seek_to)`.
- `lab/lab_ui.gd` — UI (aba Combo, toggles de seek/pose offset).
- `lab/anim_lab.gd` — orquestração, save/load de config.
- `lab/loadouts.gd` — loadouts, includes corrigidos para packs existentes.
- `lab/combo_seek.gd`, `lab/pose_offset.gd` — seek/offset.
- `lab/anim_db.gd` — classificação de clipes (não alterar sem necessidade).
- `TESTAR_LAB.bat` — importa e abre o lab.

### Como testar
```bat
TESTAR_LAB.bat
```
Ou headless:
```bat
C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\0-BASE res://lab/anim_lab.tscn
```

### Restrições para sugestões
- Godot 4.7.2, GDScript.
- Não editar `anim_db.gd`, `lab_rig.gd`, `look*.gd`, `look_body.gdshader` sem necessidade explícita.
- Mudanças pequenas e testáveis com `TESTAR_LAB.bat`.
- Formato preferido: arquivo → localização → ação → código → critério de sucesso.