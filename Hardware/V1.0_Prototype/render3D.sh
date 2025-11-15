#!/bin/bash
# ==========================================================
# Script : génération automatique des exports KiCad
# - Génère le PDF du schéma (.kicad_sch)
# - Génère les vues 3D (.png) à partir du PCB (.kicad_pcb)
# - Place tout dans un dossier "_export/"
# - Déplace Top.png dans ../../img
# - Soulève un warning si plusieurs schémas à la racine
# ==========================================================

set -e  # Arrêt en cas d’erreur critique

# --- Recherche des fichiers KiCad ---
sch_files=($(ls *.kicad_sch 2>/dev/null))
pcb_file=$(ls *.kicad_pcb 2>/dev/null | head -n 1)

# --- Vérification des fichiers trouvés ---
if [ ${#sch_files[@]} -eq 0 ] && [ -z "$pcb_file" ]; then
    echo "❌ Aucun fichier .kicad_sch ni .kicad_pcb trouvé dans le répertoire courant."
    exit 1
fi

echo "🧩 Fichiers détectés :"
[ ${#sch_files[@]} -gt 0 ] && for f in "${sch_files[@]}"; do echo "   • Schéma : $f"; done
[ -n "$pcb_file" ] && echo "   • PCB : $pcb_file"
echo

# --- Warning si plusieurs schémas ---
if [ ${#sch_files[@]} -gt 1 ]; then
    echo "🟠 ATTENTION : plusieurs fichiers schéma détectés à la racine !"
    for f in "${sch_files[@]}"; do
        echo "   - $f"
    done
    echo
fi

# --- Préparation du dossier d'export ---
EXPORT_DIR="_export"
GALLERY_DIR="$EXPORT_DIR/3D_Gallery"
mkdir -p "$GALLERY_DIR"

# --- Génération du PDF pour chaque schéma ---
if [ ${#sch_files[@]} -ge 1 ]; then
    for sch_file in "${sch_files[@]}"; do
        pdf_name="${sch_file%.kicad_sch}.pdf"
        pdf_path="$EXPORT_DIR/$pdf_name"
        echo "🧾 Génération du PDF → $pdf_path"
        if kicad-cli sch export pdf "$sch_file" -o "$pdf_path"; then
            echo "   ✅ PDF généré avec succès"
        else
            echo "   ❌ Erreur lors de la génération du PDF pour $sch_file"
        fi
        echo
    done
fi

# --- Génération des rendus 3D ---
if [ -n "$pcb_file" ]; then
    echo "🎥 Génération des rendus 3D..."
    declare -A views=(
        [Top]="0,0,0"
        [Bottom]="180,0,0"
        [Side]="270,0,0"
        [Left]="270,0,90"
        [Right]="270,0,-90"
        [Front]="270,0,180"
        [Iso_1]="315,0,45"
        [Iso_2]="225,0,45"
        [Iso_3]="135,0,45"
        [Iso_4]="45,0,45"
    )

    for name in "${!views[@]}"; do
        output_file="${GALLERY_DIR}/${name}.png"
        rotation="${views[$name]}"
        echo "   🖼️  Vue $name..."
        if kicad-cli pcb render --floor --quality high --zoom 1.0 --rotate "$rotation" -o "$output_file" "$pcb_file"; then
            echo "      ✅ $output_file"
        else
            echo "      ❌ Erreur lors du rendu $name"
        fi
    done
    echo

    # --- Déplacer Top.png dans ../../img ---
    IMG_DIR=".img"
    mkdir -p "$IMG_DIR"
    if [ -f "$GALLERY_DIR/Top.png" ]; then
        cp "$GALLERY_DIR/Top.png" "$IMG_DIR/"
        echo "📦 Top.png copié dans $IMG_DIR"
    else
        echo "⚠️ Top.png introuvable, impossible de copier"
    fi
fi

echo "🏁 Terminé ! Tous les exports sont disponibles dans : $EXPORT_DIR"
