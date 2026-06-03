#!/usr/bin/env python3
"""Replace English fallback strings with locale-specific translations."""

from __future__ import annotations

import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from l10n_batches import merged_locale_mapping

ROOT = Path(__file__).resolve().parents[1] / "Sources" / "RawComp" / "Resources"

TRANSLATIONS: dict[str, dict[str, str]] = {
    "de": {
        "adjustments.bypass": "Alle umgehen",
        "adjustments.bypass_hold_hint": "\\\\ gedrückt halten für Originalvorschau.",
        "adjustments.reset_option_hint": "Option-Klick auf Zurücksetzen stellt auch Abschnitts-Schalter wieder her.",
        "inspector.section.histogram": "Histogramm & Ablesung",
        "inspector.section.light": "Licht",
        "inspector.section.toneCurve": "Tonkurve",
        "inspector.section.color": "Farbe",
        "inspector.section.compareMode": "Vergleichsmodi",
        "histogram.display.rgb": "RGB",
        "histogram.display.luma": "Luma",
        "histogram.readout.reference": "Referenz",
        "histogram.readout.active": "Aktiv",
        "color.reset_basic": "Basis zurücksetzen",
        "color.auto_balance": "Auto-Balance",
        "light.auto_tone": "Auto-Ton",
        "tone_curve.channel.master": "Master",
        "tone_curve.channel.red": "Rot",
        "tone_curve.channel.green": "Grün",
        "tone_curve.channel.blue": "Blau",
        "tone_curve.reset_rgb": "RGB zurücksetzen",
        "tone_curve.custom_active": "Eigene Kurve (Punkte ziehen)",
        "toolbar.export_comparison": "Vergleich exportieren",
        "toolbar.open_recent_session": "Letzte Sitzung öffnen",
        "settings.open_last_session": "Letzte Sitzung beim Start öffnen",
        "settings.export_labels": "Bereichsbeschriftungen im Export",
        "optics.flat_field_raw": "Teilt durch eine Unschärfe-Schätzung (stärker bei RAW-Vorschau).",
        "optics.flat_field_standard": "Leichte Flatfield-Korrektur für Vignettierung.",
        "optics.no_lens_profile": "Objektivprofil-Steuerung erfordert Objektiv-EXIF.",
        "optics.lens_profile_estimate": "Schätzt Verzeichnung, Vignettierung und Farbsäume (Schieberegler addieren).",
        "inspector.section.reset_option_hint": "Option+Zurücksetzen aktiviert den Abschnitt wieder.",
        "inspector.section.toneCurve": "Tonkurve",
        "inspector.section.blackAndWhite": "Schwarzweiß",
        "inspector.section.presence": "Präsenz / Details",
        "inspector.section.noise": "Rauschen / Artefakte",
        "inspector.section.optics": "Optik",
        "inspector.section.geometry": "Geometrie",
        "inspector.section.metadata": "Metadaten",
        "presets.name_placeholder": "Voreinstellungsname",
        "presets.load_label": "Voreinstellung laden",
        "status.autosave_restored": "Letzte Vergleichseinstellungen wiederhergestellt.",
    },
    "fr": {
        "adjustments.bypass": "Contourner tout",
        "adjustments.bypass_hold_hint": "Maintenir \\\\ pour prévisualiser l'original.",
        "inspector.section.histogram": "Histogramme et mesure",
        "inspector.section.light": "Lumière",
        "inspector.section.toneCurve": "Courbe tonal",
        "inspector.section.color": "Couleur",
        "inspector.section.compareMode": "Modes de comparaison",
        "histogram.display.rgb": "RVB",
        "histogram.display.luma": "Luma",
        "color.reset_basic": "Réinitialiser base",
        "color.auto_balance": "Balance auto",
        "light.auto_tone": "Ton auto",
        "tone_curve.channel.red": "Rouge",
        "tone_curve.channel.green": "Vert",
        "tone_curve.channel.blue": "Bleu",
        "toolbar.export_comparison": "Exporter la comparaison",
        "settings.open_last_session": "Ouvrir la dernière session au lancement",
        "tone_curve.custom_active": "Courbe personnalisée (faire glisser les points)",
        "optics.lens_profile_estimate": "Correction estimée (barillet, vignettage, franges) ; les curseurs s’ajoutent.",
        "inspector.section.reset_option_hint": "Option+Réinitialiser réactive cette section.",
        "optics.no_lens_profile": "Les contrôles profil nécessitent les EXIF objectif.",
        "presets.name_placeholder": "Nom du préréglage",
        "presets.load_label": "Charger le préréglage",
        "adjustments.gamma": "Gamma",
        "adjustments.saturation": "Saturation",
        "adjustments.vibrance": "Vibrance",
        "adjustments.texture": "Texture",
        "adjustments.reset_option_hint": "Option+Réinitialiser restaure aussi les sections activées par défaut.",
        "tone_curve.channel.master": "Principal",
        "tone_curve.reset_rgb": "Réinitialiser RVB",
    },
    "zh-Hans": {
        "adjustments.bypass": "绕过全部",
        "adjustments.bypass_hold_hint": "按住 \\\\ 预览原图。",
        "inspector.section.histogram": "直方图与读数",
        "inspector.section.light": "光线",
        "inspector.section.toneCurve": "色调曲线",
        "inspector.section.color": "颜色",
        "inspector.section.compareMode": "比较模式",
        "histogram.display.rgb": "RGB",
        "histogram.display.luma": "亮度",
        "color.reset_basic": "重置基础",
        "color.auto_balance": "自动白平衡",
        "light.auto_tone": "自动色调",
        "tone_curve.channel.master": "主曲线",
        "tone_curve.channel.red": "红",
        "tone_curve.channel.green": "绿",
        "tone_curve.channel.blue": "蓝",
        "toolbar.export_comparison": "导出比较布局",
        "settings.open_last_session": "启动时打开最近会话",
        "status.autosave_restored": "已恢复上次的比较调整设置。",
        "tone_curve.custom_active": "自定义曲线（拖动手柄）",
        "optics.lens_profile_estimate": "估计桶形、暗角与色边校正（滑块可叠加）。",
        "inspector.section.reset_option_hint": "按住 Option 点重置可重新启用该分区。",
        "optics.no_lens_profile": "镜头配置文件控件需要镜头 EXIF 元数据。",
        "presets.name_placeholder": "预设名称",
        "presets.load_label": "加载预设",
    },
    "ja": {
        "adjustments.bypass": "すべてバイパス",
        "inspector.section.histogram": "ヒストグラムと読み取り",
        "inspector.section.light": "ライト",
        "inspector.section.toneCurve": "トーンカーブ",
        "color.auto_balance": "自動ホワイトバランス",
        "light.auto_tone": "自動トーン",
        "toolbar.export_comparison": "比較レイアウトを書き出し",
        "tone_curve.custom_active": "カスタムカーブ（ハンドルをドラッグ）",
        "optics.lens_profile_estimate": "樽型・ビネット・フリンジの推定補正（スライダーは加算）。",
        "inspector.section.reset_option_hint": "Option+リセットでセクションを再有効化。",
        "optics.no_lens_profile": "レンズプロファイルにはレンズEXIFが必要です。",
        "presets.name_placeholder": "プリセット名",
        "presets.load_label": "プリセットを読み込む",
    },
    "es": {
        "adjustments.bypass": "Omitir todo",
        "inspector.section.histogram": "Histograma y lectura",
        "inspector.section.light": "Luz",
        "inspector.section.toneCurve": "Curva de tono",
        "color.auto_balance": "Balance automático",
        "light.auto_tone": "Tono automático",
        "toolbar.export_comparison": "Exportar comparación",
        "tone_curve.custom_active": "Curva personalizada (arrastrar puntos)",
        "optics.lens_profile_estimate": "Corrección estimada (barrel, viñeta, franjas); los controles se suman.",
        "inspector.section.reset_option_hint": "Opción+Restablecer vuelve a activar la sección.",
        "optics.no_lens_profile": "El perfil de lente requiere metadatos EXIF del objetivo.",
        "presets.name_placeholder": "Nombre del ajuste",
        "presets.load_label": "Cargar ajuste",
    },
    "it": {
        "adjustments.bypass": "Ignora tutto",
        "adjustments.bypass_hold_hint": "Tieni premuto \\\\ per l'anteprima originale.",
        "inspector.section.histogram": "Istogramma e lettura",
        "inspector.section.light": "Luce",
        "inspector.section.toneCurve": "Curva tonale",
        "inspector.section.color": "Colore",
        "inspector.section.compareMode": "Modalità confronto",
        "histogram.display.rgb": "RGB",
        "histogram.display.luma": "Luma",
        "color.reset_basic": "Reimposta base",
        "color.auto_balance": "Bilanciamento auto",
        "light.auto_tone": "Tono auto",
        "tone_curve.channel.master": "Master",
        "tone_curve.channel.red": "Rosso",
        "tone_curve.channel.green": "Verde",
        "tone_curve.channel.blue": "Blu",
        "tone_curve.reset_rgb": "Reimposta RGB",
        "tone_curve.custom_active": "Curva personalizzata (trascina i punti)",
        "toolbar.export_comparison": "Esporta confronto",
        "settings.open_last_session": "Apri ultima sessione all'avvio",
        "status.autosave_restored": "Ripristinate le ultime impostazioni di confronto.",
        "optics.lens_profile_estimate": "Correzione stimata (barile, vignettatura, frange); i cursori si sommano.",
        "inspector.section.reset_option_hint": "Opzione+Reimposta riattiva la sezione.",
        "optics.no_lens_profile": "Il profilo obiettivo richiede metadati EXIF dell'obiettivo.",
        "presets.name_placeholder": "Nome preset",
        "presets.load_label": "Carica preset",
    },
    "ko": {
        "adjustments.bypass": "모두 우회",
        "adjustments.bypass_hold_hint": "\\\\ 키를 누르고 있으면 원본 미리보기.",
        "inspector.section.histogram": "히스토그램 및 읽기",
        "inspector.section.light": "라이트",
        "inspector.section.toneCurve": "톤 커브",
        "inspector.section.color": "색상",
        "inspector.section.compareMode": "비교 모드",
        "histogram.display.rgb": "RGB",
        "histogram.display.luma": "휘도",
        "color.reset_basic": "기본 재설정",
        "color.auto_balance": "자동 밸런스",
        "light.auto_tone": "자동 톤",
        "tone_curve.channel.master": "마스터",
        "tone_curve.channel.red": "빨강",
        "tone_curve.channel.green": "초록",
        "tone_curve.channel.blue": "파랑",
        "tone_curve.reset_rgb": "RGB 재설정",
        "tone_curve.custom_active": "사용자 곡선 (핸들 드래그)",
        "toolbar.export_comparison": "비교보내기",
        "settings.open_last_session": "시작 시 마지막 세션 열기",
        "status.autosave_restored": "이전 비교 조정 설정을 복원했습니다.",
        "optics.lens_profile_estimate": "배럴·비네팅·색번짐 추정 보정(슬라이더는 추가 적용).",
        "inspector.section.reset_option_hint": "Option+재설정으로 섹션을 다시 켭니다.",
        "optics.no_lens_profile": "렌즈 프로필에는 렌즈 EXIF 메타데이터가 필요합니다.",
        "presets.name_placeholder": "프리셋 이름",
        "presets.load_label": "프리셋 불러오기",
    },
    "pt": {
        "adjustments.bypass": "Ignorar tudo",
        "adjustments.bypass_hold_hint": "Segure \\\\ para pré-visualizar o original.",
        "inspector.section.histogram": "Histograma e leitura",
        "inspector.section.light": "Luz",
        "inspector.section.toneCurve": "Curva de tom",
        "inspector.section.color": "Cor",
        "inspector.section.compareMode": "Modos de comparação",
        "histogram.display.rgb": "RGB",
        "histogram.display.luma": "Luma",
        "color.reset_basic": "Repor base",
        "color.auto_balance": "Balanço automático",
        "light.auto_tone": "Tom automático",
        "tone_curve.channel.master": "Mestre",
        "tone_curve.channel.red": "Vermelho",
        "tone_curve.channel.green": "Verde",
        "tone_curve.channel.blue": "Azul",
        "tone_curve.reset_rgb": "Repor RGB",
        "tone_curve.custom_active": "Curva personalizada (arrastar pontos)",
        "toolbar.export_comparison": "Exportar comparação",
        "settings.open_last_session": "Abrir última sessão ao iniciar",
        "status.autosave_restored": "Restauradas as últimas definições de comparação.",
        "optics.lens_profile_estimate": "Correção estimada (barrel, vinheta, franjas); os controlos somam-se.",
        "inspector.section.reset_option_hint": "Opção+Repor reativa a secção.",
        "optics.no_lens_profile": "O perfil de lente requer metadados EXIF da objetiva.",
        "presets.name_placeholder": "Nome da predefinição",
        "presets.load_label": "Carregar predefinição",
    },
}


def patch_locale(locale: str, mapping: dict[str, str]) -> int:
    path = ROOT / f"{locale}.lproj" / "Localizable.strings"
    if not path.exists():
        return 0

    text = path.read_text()
    updated = 0
    for key, value in mapping.items():
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        pattern = rf'"{re.escape(key)}"\s*=\s*"(?:\\.|[^"\\])*"\s*;'
        replacement = f'"{key}" = "{escaped}";'
        new_text, count = re.subn(pattern, replacement, text, count=1)
        if count:
            text = new_text
            updated += 1
        else:
            text = text.rstrip() + f'\n"{key}" = "{escaped}";\n'
            updated += 1
    path.write_text(text)
    return updated


def main() -> None:
    locale_map = {
        "de": "de",
        "fr": "fr",
        "zh-Hans": "zh-Hans",
        "ja": "ja",
        "es": "es",
        "it": "it",
        "ko": "ko",
        "pt": "pt",
    }
    for folder, locale in locale_map.items():
        mapping = merged_locale_mapping(locale, TRANSLATIONS.get(locale, {}))
        if mapping:
            count = patch_locale(folder, mapping)
            print(f"{folder}: updated {count} keys")


if __name__ == "__main__":
    main()
