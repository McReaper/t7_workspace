# Heli Intro Cinematic — Handoff / Plan de reprise

> Portage de l'IGC d'intro BO1 **`quag_b05_repeltomacv`** (mission S.O.G. — rappel depuis un Huey, puis crash)
> dans la usermap zombies **`zm_rainy_d2om`**. Cinématique première personne : le joueur rappelle
> depuis l'hélico avec 2 alliés (Woods + un soldat), cordes animées visibles, puis crash.
>
> **Ce fichier est un handoff pour reprendre avec une session fraîche.** Lis-le en entier avant d'agir.
> Les **inconnus non testés** sont marqués `⚠️ UNKNOWN`.

---

## 0. TL;DR — où on en est

- ✅ **Hélico + intérieur + matériaux** compilés, anim de vol/descente en jeu.
- ✅ **Caméra 1ère personne** = **XCam** `rappel_cam` (pas la scene view-lock, qui est SP-only). FOV piloté par le **`flen`** de l'xcam, pas `fov`.
- ✅ **Corps 1ère personne** du joueur (`use_firstperson_player 1` sur l'xcam) + **tête cachée** (tuck de `j_neck`/`j_head` dans le torse via translate, fait en Maya).
- ✅ **Look bodycam** (fisheye postfx) gardé volontairement pendant l'intro.
- ✅ **La corde** (`fxanim_quag_rappelcrash02`) : **RÉSOLU** — s'anime et suit l'hélico. Voir §3 pour le mécanisme réel (spoiler : `AnimScripted`, PAS scene::play ni un fxanim bundle).
- ⏳ **La 3e corde** (`crash01`, 1 corde) : à ajouter (même méthode).
- ⏳ **Les 2 PNJ** (soldat + barnes) + **le mousqueton** : pas encore faits (mousqueton en partie déjà dans le mesh crash02).

---

## 1. Vision finale

Descente en rappel depuis le Huey, vue 1ère personne, avec :
1. Le **joueur** qui rappelle (corps 1ère pers. + sa corde).
2. **Woods** (allié PNJ) qui rappelle à côté, avec sa corde.
3. Un **soldat** (allié PNJ) qui rappelle, avec sa corde.
4. Chaque rappelleur a son **mousqueton** (carabiner) qui l'accroche à la corde.
5. L'hélico suit son parcours puis **crashe** (les cordes ont une anim de crash).

**3 descentes = 3 cordes** (réparties dans 2 assets fxanim, voir §3).

---

## 2. Emplacements & fichiers clés

### Extraction BO1 (source, vérité terrain pour les noms d'assets)
```
D:\SteamLibrary\steamapps\common\Call of Duty Black Ops III\_extract_assets\Greyhound\exported_files\black_ops_1\
  ├─ xanims\   (*.cast + *.seanim)   ← anims BO1
  └─ xmodels\  (<name>\<name>_LOD0.cast / .semodel / .XMODEL_EXPORT)  ← modèles BO1
```
Format d'import Maya = **Cast** (plugin castplugin.py). Les `.cast` anim sont **courbes seules** :
**importer le modèle d'abord**, puis l'anim par-dessus.

### Fichiers du projet (déjà en place, à faire évoluer)
| Fichier | Rôle | État |
|---|---|---|
| `usermaps/zm_rainy_d2om/scripts/zm/_heli_test.gsc` | Dev script serveur. Console `heli_test 1` (via `ModVar`, pas dvar) rejoue l'intro. Spawn heli+interior+cam_body+rope_align, joue les scenes. | actif |
| `usermaps/zm_rainy_d2om/scripts/zm/_heli_test.csc` | Client. Enregistre le clientfield `heli_xcam` (toplayer) → joue l'xcam `rappel_cam`. | actif |
| `source_data/_reapy/heli.gdt` | Tous les assets : xmodels, matériaux, images, xanims, xcam, scene bundles. | actif |
| `usermaps/zm_rainy_d2om/zone_source/heli.zpkg` | Liste de zone (ce qui est linké). | actif |
| `share/raw/animtrees/all_player.atr` (+ `gen/animtrees/all_player.atr`) | animtree — contient les anims perso ajoutées. | actif |
| `zm_rainy_d2om.gsc` / `.csc` | Doivent `#using scripts\zm\_heli_test;` (sinon REGISTER_SYSTEM ne tourne pas). | fait |

### Scene bundles actuels (dans `heli.gdt`)
| Bundle | sceneType | object1_Model | object1_MainAnim | InitAnimLoop | Notes |
|---|---|---|---|---|---|
| `cin_heli_test` | scene | `t5_veh_helo_huey` | `v_quag_b05_repeltomacv_huey` | — | l'hélico |
| `cin_rappel_fp` | scene | `c_zom_der_dempsey_viewbody` | `int_quag_b05_repeltomacv_player` | — | joueur 1ère pers. `cameraSwitcher=rappel_cam` |
| `cin_rappel_test` | scene | `c_t7_ally_fb` | `ch_quag_b05_repeltomacv_player` | — | test PNJ (modèle placeholder) |
| `cin_rope` | **fxanim** | `anim_jun_rappel_rope` ❌ | "" | `o_hue_b02_rope_bowman_a` ❌ | **à repointer** vers le bon fxanim (§5) |

`rappel_cam` (xcam) : `use_firstperson_player 1`, `parentScene`=cin_rappel_fp, sous-caméra `""` (vide, comme la campagne). **FOV = `flen`** dans `xanim_export/_reapy/heli/rappel_cam.xcam_export` (aperture `FOCAL_LENGTH` ; `fov`/`cg_fov` sont ignorés — piège vérifié).

---

## 3bis. LA SOLUTION QUI MARCHE (à lire en premier)

Après beaucoup d'essais, voici ce qui anime la corde ET la fait suivre l'hélico :

```gsc
rope = Spawn("script_model", origin);          // origin/angles = struct heli_intro_spawn
rope SetModel("fxanim_quag_rappelcrash02_mod");
rope NotSolid();
rope UseAnimTree(#animtree);                    // #using_animtree("all_player") dans le header
rope AnimScripted("rope_deploy", origin, angles, %fxanim_quag_rappelcrash02_anim);
```

**Pourquoi ça marche (et pourquoi le reste échouait) :**
- **`AnimScripted`** est le bon verbe : il joue une anim scriptée sur le squelette **propre** du modèle et l'avance image par image. `scene::play` (MainAnim) et `SetAnim` laissaient les os **figés** sur ce modèle.
- **Pas besoin d'attacher à l'hélico.** L'anim n'a aucun mouvement racine (tag_origin fixe) MAIS ses **os** portent tout le déplacement monde (PART 1 va de Z -117 à -1680). Comme l'anim corde est authored sur la **même origine de scène** que l'anim hélico, la jouer à cette même origine la rend spatialement cohérente → elle « suit » l'hélico gratuitement. LinkTo / AlignTargetTag / scene::play sur l'hélico = **inutiles et nuisibles** (on a tout cassé avec).
- L'anim est dans `all_player.atr` (les 2 copies) ; `#using_animtree("all_player")` + `UseAnimTree(#animtree)`.
- Le bundle `cin_rope` n'est **plus utilisé** (le modèle + l'anim sont linkés directement via la zone). À nettoyer.

Pour les cordes suivantes (`crash01`, etc.) : **même recette**, un `AnimScripted` par corde, à la même origine.

## 3. LE MÉCANISME DE LA CORDE (historique de recherche — gardé pour contexte)

La corde BO3 = un **scene bundle `scenetype: "fxanim"`** (PAS `"scene"`), pas un prop scene classique.
Référence shippée : `p7_fxanim_cp_sgen_rappel_rope_bundle` (t7kb, reliability 0.95). Sa structure :
- `sceneType: "fxanim"`
- objet type `prop` avec **`initAnimLoop`** (anim en boucle) — **pas** MainAnim
- **`spawnOnInit: 1`** (auto-spawn du mesh)
- modèle `_smod` + anim `_sanim` (paire fxanim dédiée)

**Pourquoi nos essais précédents échouaient** : on pilotait le modèle `anim_jun_rappel_rope`
(os `jnt_rope_*`) avec une anim `o_hue_b02_*` d'une **autre mission** → **squelettes incompatibles**
→ aucune animation visible. **C'était ça le bug de fond**, pas le slot d'anim.

### La bonne paire modèle+anim (vérifiée dans l'extraction)
Chaque fxanim BO1 = paire **`_mod` (mesh) + `_anim`**, squelette partagé `rope0X_NN_jnt` :

| Modèle | Anim | Os | Cordes | Rôle |
|---|---|---|---|---|
| `fxanim_quag_rappelcrash01_mod` | `fxanim_quag_rappelcrash01_anim` | 67 | **1** (`rope01_*`) | 1 corde |
| `fxanim_quag_rappelcrash02_mod` | `fxanim_quag_rappelcrash02_anim` | 134 | **2** (`rope02_*`) | 2 cordes |
| *(pas de `_mod` extrait)* | `fxanim_quag_rappelfix_anim` | — | — | corde « fixe » (réutilise un mesh crash) `⚠️ UNKNOWN` |
| `fxanim_gp_distant_rappel_mod` | *(générique)* | 67 | 1 | version décor lointaine — **écarté** |
| `anim_jun_rappel_rope` | *(aucune qui matche)* | 41 | 1 (`jnt_rope_*`) | générique — **écarté** (mauvais squelette) |

→ **1 + 2 = 3 cordes**, une par rappelleur. Les positions de chaque corde sont **authored dans l'anim**
(pas besoin de deviner « quelle corde pour qui » : jouer crash01 + crash02 alignés sur l'hélico place les 3 cordes).

**À jeter** : `anim_jun_rappel_rope` et tous les `o_hue_b02_rope_*`.

---

## 4. Casting complet de l'IGC `quag_b05_repeltomacv`

Anims présentes dans l'extraction (`xanims/`) :

| Asset (anim) | Rôle | Modèle à utiliser |
|---|---|---|
| `int_quag_b05_repeltomacv_player` | Joueur, corps **1ère personne** | `c_zom_der_dempsey_viewbody` (ou skin du perso joué) ✅ en jeu |
| `ch_quag_b05_repeltomacv_player` | Joueur, anim **monde** (3e pers.) | modèle joueur |
| `ch_quag_b05_repeltomacv_barnes` | **Allié nommé** (= le « Woods » visé) | `c_usa_jungmar_barnes_fb` (dispo) ou modèle Woods `⚠️ à extraire` |
| `ch_quag_b05_repeltomacv_soldier` | **Allié soldat** générique | `c_usa_jungmar_body_drab` / `c_usa_blackops_body2_fb` `⚠️ à confirmer` |
| `ch_quag_b05_repeltomacv_nva1/2/3` | Ennemis NVA au sol | `c_vtn_nva1/2/3_body` (dispo) — optionnel |
| `v_quag_b05_repeltomacv_huey` | Hélico | `t5_veh_helo_huey` ✅ |
| `p_quag_b05_repeltomacv_carabiner` | **Mousqueton** (accroche à la corde) | `anim_jun_carabiner` (dispo) |
| `p_quag_b05_repeltomacv_gun` | Arme dans la scène | (optionnel) |
| `fxanim_quag_rappelcrash01_anim` | Corde ×1 | `fxanim_quag_rappelcrash01_mod` |
| `fxanim_quag_rappelcrash02_anim` | Cordes ×2 | `fxanim_quag_rappelcrash02_mod` |

> **Note nommage** : l'anim allié s'appelle `_barnes`, pas `_woods`. Peu importe — on joue l'anim `_barnes`
> sur le **modèle** Woods et visuellement c'est Woods. (Aucun `_woods` dans CETTE IGC ; Woods n'existe qu'en b02.)

---

## 5. PLAN D'EXÉCUTION — étape par étape

### Pipeline générique (rappel, pour chaque asset)
```
Cast (Maya, importer MODÈLE puis ANIM) 
  → CoD Tools: Export XModel / Export XAnim (sélection = Select > Hierarchy, PAS juste la racine)
  → .xmodel_export / .xanim_export (format TEXTE)
  → exportxbin.exe (single-arg, depuis le dossier du fichier)  → _BIN
  → APE: asset xmodel (type animated) / xanim (type delta, Use Bones, Model File renseigné)
  → heli.gdt (asset) + heli.zpkg (ligne de zone) → Link
```
**Réglages Maya critiques** (pièges vérifiés — voir skills `t7kb:animation`/`assets`) :
- FPS scène = **30 (`ntsc`)** : `currentUnit -time ntsc;` (New Scene remet 24 → resample).
- Champ **Quality = 0** (c'est un multiplicateur `2^q` de frames, pas une qualité).
- Sauver en **`.xanim_export`** (pas `.xanim_bin` — Maya écrit un binaire que le linker refuse).
- **Notetracks : NE PAS baker en Maya** (le converter choke). Les ajouter dans APE après.
- Anim xmodel : **Model File OBLIGATOIRE** sur l'asset xanim (sinon `model was not specified`).
- Vérifier le bin : header `*LZ4*` + `55 c3 … Export filename:`. Mauvais = commence par `//` (`2f2f`).

---

### ÉTAPE 1 — Valider la corde avec le VRAI asset (mécanisme)
**But** : prouver que le fxanim bundle déploie la vraie corde, accrochée à l'hélico qui bouge.

> **AVANCEMENT (session du 2026-07-15)** : tout est fait SAUF l'anim. Reste **uniquement** le point 3.

1. ✅ **Modèle bin** : converti **sans Maya** — le `XMODEL_EXPORT` (VERSION 6 Wraith) de l'extraction passe direct
   dans `bin/exportxbin.exe` (single-arg depuis le dossier). Résultat :
   `model_export/_reapy/heli/fxanim_quag_rappelcrash02_mod_LOD0.xmodel_bin` (header `*LZ4* … 55 c3` OK).
2. ✅ **Matériaux + images + asset xmodel** : écrits dans `heli.gdt` :
   - images copiées vers `model_export/_reapy/heli/_images/{global_rope_fast,mtl_anim_jun_carabiner}/`
   - assets image : `i_global_rope_fast_c/_n`, `i_mtl_anim_jun_carabiner_c/_n`
   - matériaux : `global_rope_fast` + `mtl_anim_jun_carabiner` (le modèle en a **2** : corde + **mousqueton déjà dans le mesh !**)
     (`⚠️` surfaceType hérité = `cloth` pour les deux ; le mousqueton devrait être métal — cosmétique, à affiner)
   - asset xmodel `fxanim_quag_rappelcrash02_mod` (type animated) pointant sur le bin.
3. ⏳ **RESTE À FAIRE — l'anim (Maya obligatoire)** : le `.cast`/`.seanim` binaire ne se convertit pas comme le
   modèle. Étapes Maya :
   - `currentUnit -time ntsc;` (30 fps), New Scene.
   - Importer **le modèle d'abord** : `_extract_assets/…/xmodels/fxanim_quag_rappelcrash02_mod/fxanim_quag_rappelcrash02_mod_LOD0.cast`
   - Importer l'anim par-dessus : `_extract_assets/…/xanims/fxanim_quag_rappelcrash02_anim.cast`
   - Vérifier que les 2 cordes se déploient/crashent.
   - **Export XAnim** (Select > Hierarchy), **Quality 0**, sauver en `.xanim_export` →
     `xanim_export/_reapy/heli/fxanim_quag_rappelcrash02_anim.xanim_export`
   - Convertir : depuis ce dossier, `export2bin.exe fxanim_quag_rappelcrash02_anim.xanim_export` (single-arg).
   - **APE** : asset `xanim` `fxanim_quag_rappelcrash02_anim`, Anim File = le bin, **Model File = `fxanim_quag_rappelcrash02_mod`**,
     Type **delta**, Use Bones ✓. (Pas besoin d'animtree — joué via scene bundle Prop.)
4. ✅ **Bundle `cin_rope`** repointé : `object1_Model=fxanim_quag_rappelcrash02_mod`,
   `object1_InitAnimLoop=fxanim_quag_rappelcrash02_anim`, SpawnOnInit=1, Type=Prop.
   `⚠️ tester MainAnim vs InitAnimLoop` (anim one-shot descente+crash, pas une boucle → MainAnim peut-être plus juste).
5. ✅ **`heli.zpkg`** : lignes remplacées (`xmodel,fxanim_quag_rappelcrash02_mod` + `xanim,fxanim_quag_rappelcrash02_anim`).
6. ✅ **GSC** : tag d'accroche corrigé (`tag_origin` au lieu de `tag_fastrope_ri`).
7. **GSC `_heli_test.gsc`** : déjà câblé — `rope_align` est spawné, `LinkTo(heli, ...)`,
   puis `rope_align thread scene::play("cin_rope");`.
   **⚠️ IMPORTANT — corriger le tag d'accroche** : le code actuel utilise `tag_fastrope_ri`, mais le Huey n'a
   que **2 tags fastrope** (`tag_fastrope_le`/`_ri`) pour **3 cordes**. Les 3 cordes sont **authored dans
   l'anim relativement à `tag_origin`** → il faut aligner sur l'**origine de l'hélico**, pas un tag fastrope
   (sinon les 3 cordes sont décalées sur un seul point). **Remplacer** `LinkTo(heli, "tag_fastrope_ri", ...)`
   par `LinkTo(heli, "tag_origin", (0,0,0), (0,0,0))` **ou** jouer `cin_rope` directement sur le même `align`
   que l'hélico (origine de scène commune → alignement auto des 3 cordes). Préférer l'align commun.
8. **Link** (script/asset — pas de recompile map). Test `heli_test 1`.
   - **Attendu** : 2 cordes qui se déploient et suivent l'hélico.
   - Si statique → tester MainAnim au lieu d'InitAnimLoop ; vérifier que le squelette anim matche le mod ;
     vérifier que l'anim est bien type `delta` + Use Bones.

### ÉTAPE 2 — La 3e corde
Idem étape 1 avec `fxanim_quag_rappelcrash01_mod` + `_anim` (1 corde). Créer un **2e bundle fxanim**
(ex. `cin_rope2`) ou ajouter un `object2` au bundle `cin_rope`. `⚠️ UNKNOWN` : un seul bundle avec 2 objets
fxanim vs 2 bundles séparés — préférer **2 bundles** joués sur le même align (plus simple, testé partiellement).

### ÉTAPE 3 — Les 2 PNJ (Woods + soldat)
Pour **chaque** PNJ :
1. **Modèle** : compiler le modèle perso BO1 (`c_usa_jungmar_barnes_fb` pour Woods `⚠️ ou vrai modèle Woods`,
   un modèle US pour le soldat) OU réutiliser un modèle allié BO3 existant si le rig matche `⚠️`.
2. **Anim** : `ch_quag_b05_repeltomacv_barnes` / `_soldier` → pipeline xanim.
   - **HumanIK retarget nécessaire** si le rig BO1 ≠ rig du modèle BO3 utilisé (voir skill `bo3-anim-retarget` :
     characterize les 2 rigs, **Lock en bind pose AVANT d'importer l'anim**, bake, export `Type delta` Use Bones).
   - Ajouter chaque `ch_*` à **`all_player.atr`** (les 2 copies : `share/raw/` ET `gen/`) si joué via animtree,
     ou jouer via scene bundle `Prop` (pas besoin d'animtree). Préférer scene bundle Prop.
3. **Bundle** : un scene bundle `scene` par PNJ (comme `cin_rappel_test`), model = modèle PNJ,
   MainAnim = le `ch_*`. Jouer sur le même `align` que le joueur (même origine de scène → alignement auto).
4. **Zone** + Link + test.

### ÉTAPE 4 — Le mousqueton (carabiner)
1. **Modèle** : `anim_jun_carabiner` → pipeline xmodel (type animated).
2. **Anim** : `p_quag_b05_repeltomacv_carabiner` → pipeline xanim (Model File = `anim_jun_carabiner`).
3. **Attache** : le mousqueton est un prop qui suit la corde/le perso. `⚠️ UNKNOWN` : accroché à un tag de la
   corde ou joué comme objet aligné dans le bundle. Option simple : `object2` dans le bundle corde, ou
   `LinkTo` sur un tag du perso. À expérimenter — commencer par jouer son anim aligné sur l'align de scène.
4. Un mousqueton **par rappelleur** (3 au total) si on veut le détail complet ; sinon juste celui du joueur
   (le plus visible en 1ère personne).

### ÉTAPE 5 — Synchro & polish
- Synchroniser le timing hélico ↔ joueur ↔ cordes ↔ PNJ (toutes les scenes jouées sur le **même align**,
  au **même moment**, pour rester alignées — les IGC BO1 sont authored sur une origine commune).
- **Notetracks crash** → FX + son (ajoutés dans APE sur les xanims, déclenchés via `waittill` en GSC). `⚠️`
- Décalage manuel du début d'une corde : baker des frames de hold en Maya (pas de param runtime propre). `⚠️`
- Nettoyer les assets morts (`anim_jun_rappel_rope`, `o_hue_b02_*`, bundle `cin_rope` si renommé).
- **Commit toute la chaîne** (les binaires sont gitignored → `git add -f`).

---

## 6. Inconnus / non expérimentés (récap `⚠️`)
- **MainAnim vs InitAnimLoop** pour une corde fxanim one-shot (descente+crash) vs boucle. Tester les deux.
- ~~**Tag d'accroche exact** des cordes~~ **RÉSOLU** : aligner le fxanim sur `tag_origin`/l'align de scène
  (les 3 cordes sont authored relativement à l'origine). Tags Huey utiles : `tag_fastrope_le`, `tag_fastrope_ri`
  (2 seulement), `tag_guy0/1/2/4/6/7/8` (positions rappelleurs/passagers), `tag_player`, `tag_passenger*`,
  `tag_interior`, `tag_body`, `tag_origin`.
- **1 bundle multi-objets fxanim vs plusieurs bundles** pour les 3 cordes.
- **Matériaux BO1 exacts** des mesh fxanim corde (on a `mtl_anim_rus_rappel_belay_rope_dark` sous la main).
- **Modèle Woods** : pas extrait ; `c_usa_jungmar_barnes_fb` dispo comme substitut.
- **Rig des PNJ** : besoin ou non d'un HumanIK retarget selon le modèle cible.
- **Attache du mousqueton** (tag corde vs tag perso vs objet de bundle).
- **`fxanim_quag_rappelfix_mod`** absent — la corde « fixe » (pré-crash) réutilise quel mesh ?
  (on part sur `rappelcrash02` qui contient la séquence complète, donc probablement inutile).

---

## 7. Commandes utiles

Lister les tags corde/fastrope du Huey (dans l'extraction) :
```bash
cd "D:/SteamLibrary/steamapps/common/Call of Duty Black Ops III/_extract_assets/Greyhound/exported_files/black_ops_1"
grep -iE 'BONE [0-9]+ .*(fastrope|rope|rappel|tag_)' xmodels/*huey*/*_LOD0.XMODEL_EXPORT
```
Vérifier un bin d'anim (header attendu `55 c3 … Export filename`) :
```bash
xxd fichier.xanim_bin | head    # doit montrer *LZ4* puis 55 c3 ; PAS 2f 2f (//)
```
Rejouer l'intro en jeu : console → `heli_test 1` (ModVar, settable à runtime en usermap).

---

## 8. Sources / références
- Mécanisme fxanim : t7kb `p7_fxanim_cp_sgen_rappel_rope_bundle` (+ `p7_fxanim_cp_biodomes_rope_*`,
  `p7_fxanim_zm_castle_tram_*` en ZM). reliability 0.95.
- Pipeline anim/modèle & pièges : skills `t7kb:animation`, `t7kb:assets`, `bo3-anim-retarget`.
- XCam FOV = `flen` : documenté dans `KNOWLEDGE.md` (section « First-person cinematic camera (XCam) »)
  et le skill `bo3-anim-retarget`.
</content>
</invoke>
