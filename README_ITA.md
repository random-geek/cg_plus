# Crafting Guide Plus

![screenshot](screenshot.png)

Crafting Guide Plus è una mod semplice e intuitiva per Minetest che fa da guida di assemblaggio e auto-assemblaggio.
CGP è compatibile con Minetest Game e qualsiasi altro gioco che usa sfinv.
È stata fatta per la maggior parte da zero, con qualche ispirazione dal mod di jp così come da Unified Inventory.

## Caratteristiche:

- Auto-assemblaggio "intelligente", o piuttosto, preparazione automatica dell'assemblaggio. Questa caratteristica può essere disabilitata se non è desiderata.
- Supporto gruppi, inclusa la ricerca di gruppi e supporto per ricette di assemblaggio che richiedono oggetti in gruppi multipli.
- Anteprima delle ricette di assemblaggio con forma o senza forma di qualsiasi dimensione.
- Ricette di combustibile e cottura, inclusi sostitutivi dei combustibili e tempi di combustione/cottura.
- Anteprime di scavo e probabilità di scavo (rilascio oggetti).

## Problemi noti:

- L'algoritmo di auto-assemblaggio non è *perfetto*. Per le ricette di assemblaggio che richiedono oggetti in un gruppo, sarà utilizzato solamente l'oggetto con l'ammontare maggiore nell'inventario del giocatore.
- Gli oggetti in gruppi multipli non verranno sempre mostrati correttamente nella visuale d'assemblaggio.

## Licenza

Il codice sorgente è rilasciato sotto la licenza GNU LGPL v3.0. Le immagini e gli altri file multimediali sono rilasciati sotto licenza CC BY-SA 4.0 a meno che dichiarato diversamente.

Le immagini seguenti provengono da Minetest Game, e gli si applicano le loro rispettive licenze:

```
cg_plus_icon_autocrafting.png           Basato su default_tool_stonepick.png
cg_plus_icon_clear.png                  Da creative_clear_icon.png
cg_plus_icon_cooking.png                Da default_furnace_front_active.png
cg_plus_icon_digging.png                Da default_tool_stonepick.png
cg_plus_icon_fuel.png                   Da default_furnace_fire_fg.png
cg_plus_icon_next.png                   Da creative_next_icon.png
cg_plus_icon_prev.png                   Da creative_prev_icon.png
cg_plus_icon_search.png                 Da creative_search_icon.png
```
