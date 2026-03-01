#!/usr/bin/env python3
"""
Parses weapon_skill_templates.json (raw wikitext from gbf.wiki) into
a structured weapon_skill_data.json suitable for database seeding.

Usage:
    python3 scripts/parse_weapon_skill_data.py

Input:  data/weapon_skill_templates/weapon_skill_templates.json
Output: data/weapon_skill_data.json
"""

import json
import re
import sys
from pathlib import Path

INPUT_PATH = Path("data/weapon_skill_templates/weapon_skill_templates.json")
OUTPUT_PATH = Path("data/weapon_skill_data.json")

# --- Series normalization ---
SERIES_MAP = {
    "normal": "normal",
    "omega": "omega",
    "normal & omega": "normal_omega",
    "ex": "ex",
    "taboo": "odious",
    "sephira": "sephira",
}

# --- Size normalization ---
SIZE_MAP = {
    "small": "small",
    "medium": "medium",
    "big": "big",
    "big ii": "big_ii",
    "massive": "massive",
    "unworldly": "unworldly",
    "ancestral": "ancestral",
    # Blessing (Seraphic) tiers
    "blessing": "small",
    "blessing ii": "medium",
    "blessing iii": "big",
}

# --- Boost type normalization ---
BOOST_TYPE_MAP = {
    "might": "atk",
    "omega might": "atk",
    "ex might": "atk",
    "ex might sp.": "atk_sp",
    "od might": "atk",
    "hp": "hp",
    "hp (fixed)": "hp_fixed",
    "hp cut": "hp_cut",
    "hp dmg": "hp_dmg",
    "enmity": "enmity",
    "omega enmity": "enmity",
    "ex enmity": "enmity",
    "stamina": "stamina",
    "omega stamina": "stamina",
    "critical": "critical",
    "da rate": "da",
    "ta rate": "ta",
    "c.a. dmg": "ca_dmg",
    "c.a. dmg cap": "ca_dmg_cap",
    "c.a. supp.": "ca_supp",
    "c.a. supp. (sp.)": "ca_supp_sp",
    "c.a. amp. (sp.)": "ca_amp_sp",
    "c.b. dmg": "cb_dmg",
    "c.b. dmg cap": "cb_dmg_cap",
    "c.b. amp.": "cb_amp",
    "sp. c.a. cap": "sp_ca_cap",
    "bonus c.a.": "bonus_ca",
    "def": "def",
    "def ignore": "def_ignore",
    "debuff res.": "debuff_res",
    "dmg cap": "dmg_cap",
    "dmg cap (sp.)": "dmg_cap_sp",
    "dmg cap (arc)": "dmg_cap_arc",
    "dmg amp.": "dmg_amp",
    "dmg amp. (non-elem. foe)": "dmg_amp_non_elem",
    "dmg supp.": "dmg_supp",
    "n.a. dmg cap": "na_dmg_cap",
    "n.a. amp.": "na_amp",
    "n.a. amp. (sp.)": "na_amp_sp",
    "n.a. supp.": "na_supp",
    "n.a. supp. (sp.)": "na_supp_sp",
    "skill dmg cap": "skill_dmg_cap",
    "skill dmg supp.": "skill_dmg_supp",
    "skill amp. (sp.)": "skill_amp_sp",
    "skill cap (sp.)": "skill_cap_sp",
    "skill supp. (sp.)": "skill_supp_sp",
    "fc dmg cap": "fc_dmg_cap",
    "fc amp.": "fc_amp",
    "charge gain": "charge_gain",
    "counter rate": "counter_rate",
    "counter dmg": "counter_dmg",
    "crit. amp.": "crit_amp",
    "elem. reduc.": "elem_reduc",
    "elem. amplify": "elem_amplify",
    "heal cap": "heal_cap",
    "hit to def": "hit_to_def",
    "turn dmg": "turn_dmg",
    "od dmg amp": "od_dmg_amp",
    "e. atk (prog.)": "e_atk_prog",
    "rigor": "rigor",
    "bonus elem. dmg": "bonus_elem_dmg",
    # Element-specific reduction
    "fire reduc.": "fire_reduc",
    "water reduc.": "water_reduc",
    "earth reduc.": "earth_reduc",
    "wind reduc.": "wind_reduc",
    "light reduc.": "light_reduc",
    "dark reduc.": "dark_reduc",
    # Element-specific boosts
    "fire optimus": "fire_optimus",
    "water optimus": "water_optimus",
    "earth optimus": "earth_optimus",
    "wind optimus": "wind_optimus",
    "light optimus": "light_optimus",
    "dark optimus": "dark_optimus",
    "fire omega": "fire_omega",
    "water omega": "water_omega",
    "earth omega": "earth_omega",
    "wind omega": "wind_omega",
    "light omega": "light_omega",
    "dark omega": "dark_omega",
    # Bonus element damage
    "bonus fire dmg": "bonus_fire_dmg",
    "bonus water dmg": "bonus_water_dmg",
    "bonus earth dmg": "bonus_earth_dmg",
    "bonus wind dmg": "bonus_wind_dmg",
    "bonus light dmg": "bonus_light_dmg",
    "bonus dark dmg": "bonus_dark_dmg",
    "bonus des. dmg": "bonus_des_dmg",
    "bonus des. dmg c.a.": "bonus_des_dmg_ca",
}

# Templates with no numerical data (special mechanics, text-only)
SKIP_TEMPLATES = {
    "Betrayal", "Blow", "Hunt",
    "Preemptive Barrier", "Preemptive Blade", "Preemptive Wall",
}

# Templates that use transclusion and have no inline data
# (their data lives in another wiki template we don't have)
TRANSCLUSION_TEMPLATES = {
    "Abandon", "Aramis", "Arts", "Ascendancy", "Athos",
    "Beast Essence", "Chain Force", "Charge", "Convergence", "Craft",
    "Enforcement", "Fortified", "Fortitude", "Frailty",
    "Godblade", "Godflair", "Godheart", "Godshield", "Godstrike",
    "Grand Epic", "Initiation", "Maneuver", "Marvel",
    "Omega Exalto", "Optimus Exalto", "Pact",
    "Persistence", "Quintessence", "Resonator",
    "Scandere Aggressio", "Scandere Arcanum", "Scandere Catena", "Scandere Facultas",
    "Sephira Maxi", "Spectacle", "Strike", "Striking Art",
    "Surge", "Trituration", "True Dragon Barrier", "Valuables",
    "Vivification", "Wrath", "Zenith Art", "Zenith Strike",
}

# Text-only templates (fixed values described in prose, no tables)
TEXT_ONLY_TEMPLATES = {
    "Draconic Barrier", "Draconic Fortitude", "Draconic Magnitude",
    "Fulgor Elatio", "Fulgor Fortis", "Fulgor Impetus", "Fulgor Sanatio",
    "Heed",
}

# Formula-type modifiers
FORMULA_MODIFIERS = {
    "Enmity": "enmity",
    "Stamina": "stamina",
    "Garrison": "garrison",
}


def strip_refs(text):
    """Remove <ref>...</ref> and <ref ... /> tags."""
    text = re.sub(r'<ref[^>]*>.*?</ref>', '', text, flags=re.DOTALL)
    text = re.sub(r'<ref[^/]*/>', '', text)
    return text


def strip_html_comments(text):
    """Remove HTML comments."""
    return re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)


def strip_wiki_markup(text):
    """Remove common wiki markup patterns."""
    text = strip_refs(text)
    text = strip_html_comments(text)
    text = re.sub(r'\{\{[^}]*\}\}', '', text)
    text = re.sub(r'\[\[(?:Category:)?([^|\]]+)(?:\|([^\]]+))?\]\]', lambda m: m.group(2) or m.group(1), text)
    return text.strip()


def parse_wsbox(wikitext):
    """Extract modifier name and aura_boostable from WsBox header."""
    name_match = re.search(r'\|name=\s*(.+?)(?:\s*\n|\s*\|)', wikitext)
    name = name_match.group(1).strip() if name_match else None

    aura_match = re.search(r'\|aura_boostable=(\w+)', wikitext)
    aura_boostable = aura_match.group(1).strip().lower() == "yes" if aura_match else False

    return name, aura_boostable


def normalize_series(title_text):
    """Normalize a table section title to a series key."""
    clean = strip_wiki_markup(title_text).strip()
    clean = re.sub(r'\s+', ' ', clean).lower().strip()
    return SERIES_MAP.get(clean)


def normalize_size(size_text):
    """Normalize a tier/size label."""
    clean = strip_wiki_markup(size_text).strip()
    clean = re.sub(r'\s+', ' ', clean).lower().strip()
    # Handle trailing text like "(at 100% HP)" or footnotes
    clean = re.sub(r'\(.*?\)', '', clean).strip()
    if clean == '-':
        return None
    return SIZE_MAP.get(clean)


def normalize_boost_type(label_text):
    """Normalize a Label boost type to our key."""
    # Strip any trailing annotations like "<br />(At 1% HP)"
    clean = re.sub(r'<br\s*/?>\s*\(.*?\)', '', label_text).strip()
    clean = clean.lower()
    if clean in BOOST_TYPE_MAP:
        return BOOST_TYPE_MAP[clean]
    fallback = re.sub(r'[^a-z0-9]+', '_', clean).strip('_')
    print(f"  WARNING: unmapped boost type '{label_text.strip()}' -> '{fallback}'", file=sys.stderr)
    return fallback


def extract_boost_types_from_stat(stat_text):
    """Extract boost type(s) from a wsmod-stat cell. Returns a list.

    Handles:
    - {{Label|...}} single label
    - {{Label|A}} <br /> {{Label|B}} multiple labels (shared values)
    - {{Label|A}}<br />(annotation) label with note
    - Plain text without Label wrapper
    """
    # Find all Labels in the text
    labels = re.findall(r'\{\{Label\|([^}]+)\}\}', stat_text)

    if labels:
        result = []
        for label in labels:
            bt = normalize_boost_type(label)
            if bt:
                result.append(bt)
        return result if result else None

    # Fallback: use the text directly (strip rowspan and other attributes)
    clean = re.sub(r'rowspan="\d+"\s*\|\s*', '', stat_text)
    clean = strip_wiki_markup(clean).strip()
    # Remove annotations like "(At 1% HP)"
    clean = re.sub(r'\(.*?\)', '', clean).strip()
    if clean:
        bt = normalize_boost_type(clean)
        return [bt] if bt else None
    return None


def parse_percentage(text):
    """Parse a percentage value from text. Returns float or None."""
    clean = strip_html_comments(text).strip().rstrip('%').strip()
    if clean in ('', '-', '–', '—', '?', 'N/A'):
        return None
    try:
        return float(clean)
    except ValueError:
        return None


def parse_horizontal_values(value_text, sl_columns):
    """Parse a horizontal row of || separated percentage values."""
    cells = re.split(r'\|\|', value_text)
    result = {}
    for i, cell in enumerate(cells):
        if i >= len(sl_columns):
            break
        sl = sl_columns[i]
        sl_key = f"sl{sl}"
        result[sl_key] = parse_percentage(cell)
    return result


def parse_wsmod_tables(wikitext, modifier_name, aura_boostable, formula_type="flat"):
    """Parse wsmod-style tables. Returns list of data rows."""
    rows = []

    # Split into table sections by wsmod-wrap divs
    sections = re.split(r'<div class="wsmod-wrap">', wikitext)

    for section in sections[1:]:
        # Extract series from title
        title_match = re.search(r'wsmod-title[^|]*\|\s*(.+?)$', section, re.MULTILINE)
        if title_match:
            series = normalize_series(title_match.group(1))
            if series is None:
                raw = strip_wiki_markup(title_match.group(1))
                print(f"  WARNING: unknown series '{raw}' in {modifier_name}", file=sys.stderr)
                continue
        else:
            # No title: default series based on context
            # EX-only skills (Ars, Parity, etc.) don't have series titles
            series = "ex"

        # Extract SL columns from header
        # Match a line that starts with ! and contains numbers separated by !!
        # Allow trailing non-numeric columns (e.g., "!! Damage Modifier")
        sl_match = re.search(r'^!\s*(\d+\s*(?:!!\s*\d+\s*)*)', section, re.MULTILINE)
        if sl_match:
            raw_sl = sl_match.group(1).strip()
            sl_columns = [int(x.strip()) for x in re.split(r'!!', raw_sl)]
        else:
            # No SL columns found — fixed-value skill (e.g., Blessing)
            # Treat single values as SL1
            sl_columns = [1]

        # Parse data rows
        lines = section.split('\n')
        current_size = None
        current_boost_types = None

        i = 0
        while i < len(lines):
            line = lines[i].strip()

            # Detect size/tier
            tier_match = re.search(r'wsmod-tier[^|]*\|\s*(.+)', line)
            if tier_match:
                raw_tier = tier_match.group(1).strip()
                # Strip rowspan prefix
                raw_tier = re.sub(r'^rowspan="\d+"\s*\|\s*', '', raw_tier)
                # Skip "Skill Level" headers
                if 'skill level' not in raw_tier.lower():
                    new_size = normalize_size(raw_tier)
                    if new_size:
                        current_size = new_size

            # Detect boost type(s) from stat
            stat_match = re.search(r'wsmod-stat[^|]*\|\s*(.+)', line)
            if stat_match:
                bts = extract_boost_types_from_stat(stat_match.group(1))
                if bts:
                    current_boost_types = bts

            # Detect value row: starts with | (not || or !), contains % or || or number
            is_value = (re.match(r'^\|[^|!{}\n]', line) and
                        ('||' in line or '%' in line or re.search(r'\d', line)))
            if is_value and current_boost_types:
                    value_text = line.lstrip('|').strip()
                    values = parse_horizontal_values(value_text, sl_columns)

                    has_data = any(v is not None for v in values.values())
                    if has_data:
                        effective_size = current_size or "big"
                        # Emit a row for each boost type (shared values)
                        for bt in current_boost_types:
                            row = make_row(modifier_name, bt, series,
                                           effective_size, formula_type, values,
                                           aura_boostable=aura_boostable)
                            rows.append(row)

            i += 1

    return rows


def parse_vertical_values(lines, start_idx, sl_columns):
    """Parse vertically-listed values (one per line, as in Progression).
    Returns {slN: value} dict."""
    result = {}
    sl_idx = 0
    i = start_idx

    while i < len(lines) and sl_idx < len(sl_columns):
        line = lines[i].strip()
        # Skip comment-only lines
        if line.startswith('<!--') and '-->' in line and not line.endswith('-->'):
            i += 1
            continue
        if line.startswith('<!--'):
            # Multi-line comment — skip until end
            while i < len(lines) and '-->' not in lines[i]:
                i += 1
            i += 1
            continue

        # Value line starts with |
        if re.match(r'^\|[^|!{]', line):
            val_text = line.lstrip('|').strip()
            val = parse_percentage(val_text)
            sl_key = f"sl{sl_columns[sl_idx]}"
            result[sl_key] = val
            sl_idx += 1
        elif line in ('|-', '|}'):
            break

        i += 1

    return result, i


def parse_progression(wikitext, modifier_name, aura_boostable):
    """Parse Progression-style template with vertical values per SL level.

    Progression templates list one value per line for SL1-25, with HTML comments
    wrapping intermediate SLs (2-9, 11-14, etc.). The uncommented values correspond
    to SL1, SL10, SL15, SL20, SL25. We collect ALL uncommented values in order
    and map them to the SL columns from the header.
    """
    rows = []

    sections = re.split(r'<div class="wsmod-wrap">', wikitext)

    for section in sections[1:]:
        title_match = re.search(r'wsmod-title[^|]*\|\s*(.+?)$', section, re.MULTILINE)
        series = normalize_series(title_match.group(1)) if title_match else "normal_omega"
        if series is None:
            continue

        # Find SL header
        sl_match = re.search(r'^!\s*(\d+\s*(?:!!\s*\d+\s*)*)', section, re.MULTILINE)
        if not sl_match:
            continue
        raw_sl = sl_match.group(1).strip()
        sl_columns = [int(x.strip()) for x in re.split(r'!!', raw_sl)]

        lines = section.split('\n')
        current_size = None
        current_boost_types = None

        i = 0
        while i < len(lines):
            line = lines[i].strip()

            # Detect size
            tier_match = re.search(r'wsmod-tier[^|]*\|\s*(.+)', line)
            if tier_match:
                raw = re.sub(r'^rowspan="\d+"\s*\|\s*', '', tier_match.group(1))
                if 'skill level' not in raw.lower():
                    new_size = normalize_size(raw)
                    if new_size:
                        current_size = new_size

            # Detect boost type
            stat_match = re.search(r'wsmod-stat[^|]*\|\s*(.+)', line)
            if stat_match:
                bts = extract_boost_types_from_stat(stat_match.group(1))
                if bts:
                    current_boost_types = bts

            # For Progression, check if this is a horizontal value row first
            if re.match(r'^\|[^|!{}\n]', line) and '||' in line:
                if current_boost_types and current_size:
                    values = parse_horizontal_values(line.lstrip('|'), sl_columns)
                    has_data = any(v is not None for v in values.values())
                    if has_data:
                        for bt in current_boost_types:
                            row = make_row(modifier_name, bt, series,
                                           current_size, "flat", values,
                                           aura_boostable=aura_boostable)
                            rows.append(row)
                        current_size = None
                i += 1
                continue

            # Otherwise check for vertical value format (one value per line)
            # This starts with a single | value% line after the stat line
            if (current_boost_types and current_size and
                    re.match(r'^\|[^|!{}\n]', line) and '||' not in line):
                # Collect vertical values
                collected_values = []
                j = i
                while j < len(lines):
                    vline = lines[j].strip()

                    if vline.startswith('|-') or vline.startswith('|}'):
                        break
                    if 'wsmod' in vline or (vline.startswith('!') and j > i):
                        break

                    # Skip fully commented lines
                    if vline.startswith('<!--') and '-->' in vline:
                        # Could be multi-line comment start
                        if vline.endswith('-->'):
                            j += 1
                            continue
                        # Multi-line comment block — skip until -->
                        while j < len(lines) and '-->' not in lines[j]:
                            j += 1
                        j += 1
                        continue

                    # Extract value from visible lines
                    visible = strip_html_comments(vline).strip()
                    if re.match(r'^\|', visible):
                        val = parse_percentage(visible.lstrip('|'))
                        collected_values.append(val)

                    j += 1

                # Map collected values to SL columns
                values = {}
                for idx, sl in enumerate(sl_columns):
                    if idx < len(collected_values) and collected_values[idx] is not None:
                        values[f"sl{sl}"] = collected_values[idx]

                has_data = any(v is not None for v in values.values())
                if has_data:
                    for bt in current_boost_types:
                        row = make_row(modifier_name, bt, series,
                                       current_size, "flat", values,
                                       aura_boostable=aura_boostable)
                        rows.append(row)

                current_size = None
                i = j
                continue

            i += 1

    return rows


def parse_revelation(wikitext, modifier_name, aura_boostable):
    """Parse α/β/γ/Δ Revelation templates (plain wikitable, fixed values by tier)."""
    rows = []

    # These have a simple table with columns: Icon, Skill Tier, boost1, boost2, ...
    # The boost types are in the header row as {{label|...}} or {{Label|...}}
    lines = wikitext.split('\n')

    # Find header row with boost types
    boost_types = []
    for line in lines:
        labels = re.findall(r'\{\{[Ll]abel\|([^}]+)\}\}', line)
        if labels:
            boost_types = [normalize_boost_type(l) for l in labels]
            break

    if not boost_types:
        return rows

    # Parse data rows
    for line in lines:
        # Data rows start with | and have || separators
        if re.match(r'^\|\s*\d', line):
            cells = re.split(r'\|\|', line.lstrip('|'))
            if len(cells) >= len(boost_types):
                # This is a value row — but we need the tier name
                # The tier is in a preceding ! row
                pass

    # Alternative: iterate and track tier
    current_tier = None
    for i, line in enumerate(lines):
        stripped = line.strip()

        # Tier/name row (starts with !)
        tier_match = re.search(r'text-align:\s*left[^|]*\|\s*(.+)', stripped)
        if tier_match:
            current_tier = strip_wiki_markup(tier_match.group(1)).strip()

        # Value row
        if re.match(r'^\|\s', stripped) and '||' in stripped:
            cells = re.split(r'\|\|', stripped.lstrip('|'))
            if current_tier and len(cells) >= len(boost_types):
                for j, bt in enumerate(boost_types):
                    val = parse_percentage(cells[j])
                    if val is not None:
                        row = make_row(modifier_name, bt, "normal",
                                       "big", "flat",
                                       {"sl1": val},
                                       aura_boostable=aura_boostable)
                        # Use tier name as a note — these don't really have SL scaling
                        rows.append(row)

    return rows


def parse_stamina_coefficients(wikitext, aura_boostable):
    """Parse the Stamina coefficient table."""
    rows = []
    lines = wikitext.split('\n')

    size_headers = []
    coefficient_values = []

    for i, line in enumerate(lines):
        stripped = line.strip()
        # Size headers: !Small, !Medium<ref...>
        if stripped.startswith('!') and not stripped.startswith('!{') and 'Coefficient' not in stripped and 'Icon' not in stripped:
            text = stripped.lstrip('!').strip()
            size = normalize_size(strip_wiki_markup(text))
            if size:
                size_headers.append(size)

        # Coefficient values
        if stripped == '!Coefficient':
            for j in range(i + 1, min(i + 20, len(lines))):
                val_line = lines[j].strip()
                if val_line.startswith('|}'):
                    break
                if val_line.startswith('|'):
                    try:
                        coefficient_values.append(float(val_line.lstrip('|').strip()))
                    except ValueError:
                        pass

    # Map: first N-2 are Normal sizes, last 2 are Omega
    normal_count = max(0, len(size_headers) - 2)

    for idx, (size, coeff) in enumerate(zip(size_headers, coefficient_values)):
        series = "normal" if idx < normal_count else "omega"
        rows.append(make_row("Stamina", "stamina", series, size, "stamina",
                              {}, coefficient=coeff, aura_boostable=aura_boostable))

    return rows


def parse_garrison_tables(wikitext, aura_boostable):
    """Parse Garrison coefficient tables.

    Garrison uses indented wikitables (:{| ...) with styled value cells.
    Two tables: Normal & Omega, then Taboo.
    """
    rows = []

    # Split on table start markers (:{| or {|)
    table_parts = re.split(r':?\{?\|\s*class="wikitable"', wikitext)

    for part in table_parts[1:]:
        # Find end of this table
        table_end = part.find('|}')
        if table_end >= 0:
            table_text = part[:table_end]
        else:
            table_text = part

        lines = table_text.split('\n')

        # Determine series from title
        is_taboo = any('taboo' in line.lower() for line in lines[:5])
        series = "odious" if is_taboo else "normal_omega"

        # Skip formula calculation tables (they have HP headers)
        if any('HP' in line and 'rowspan' in line for line in lines[:10]):
            continue

        sl_columns = []
        current_size = None
        values = []

        for i, line in enumerate(lines):
            stripped = line.strip()

            # SL header: !1||10||15||20 or !1 !! 10 !! 15
            sl_match = re.match(r'^!\s*(\d+\s*(?:\|\|\s*\d+\s*)*)', stripped)
            if sl_match and 'style' not in stripped and 'colspan' not in stripped:
                sl_columns = [int(x.strip()) for x in re.split(r'\|\|', sl_match.group(1))]
                continue

            # Size: !Small, !Medium<ref...>, !Big<ref...>, or ! style="..." | Big
            size_match = re.search(r'^!\s*(?:style="[^"]*"\s*(?:\|)?\s*)?([A-Z][\w\s]*?)(?:<ref|$|\n)', stripped)
            if size_match:
                candidate = size_match.group(1).strip()
                if candidate.lower() not in ('icons', 'icon', 'garrison modifier', 'skill level'):
                    new_size = normalize_size(candidate)
                    if new_size:
                        if values and current_size and sl_columns:
                            # Flush previous size
                            _flush_garrison_row(rows, series, current_size, sl_columns, values, aura_boostable)
                        current_size = new_size
                        values = []

            # Value cells: | style="font-size: 1.3em;" |3.0  or  | style="..." | 12.5
            val_matches = re.findall(r'\|\s*(?:style="[^"]*"\s*\|)?\s*(-?\s*\d+\.?\d*|-)', stripped)
            if val_matches and current_size:
                for v in val_matches:
                    v = v.strip()
                    if v == '-':
                        values.append(None)
                    else:
                        try:
                            values.append(float(v))
                        except ValueError:
                            pass

            # Row separator
            if stripped == '|-' and values and current_size and sl_columns:
                _flush_garrison_row(rows, series, current_size, sl_columns, values, aura_boostable)
                values = []
                current_size = None

        # Flush any remaining values
        if values and current_size and sl_columns:
            _flush_garrison_row(rows, series, current_size, sl_columns, values, aura_boostable)

    return rows


def _flush_garrison_row(rows, series, size, sl_columns, values, aura_boostable):
    """Helper: create a Garrison row from accumulated values."""
    if len(values) < len(sl_columns):
        return
    sl_vals = {}
    for j, sl in enumerate(sl_columns):
        if j < len(values) and values[j] is not None:
            sl_vals[f"sl{sl}"] = values[j]
    if any(v is not None for v in sl_vals.values()):
        rows.append(make_row("Garrison", "def", series, size,
                              "garrison", sl_vals,
                              aura_boostable=aura_boostable))


def parse_plain_wikitable(wikitext, modifier_name, aura_boostable, formula_type="flat"):
    """Parse templates that use plain wikitable instead of wsmod classes."""
    rows = []
    lines = wikitext.split('\n')

    # These templates have various formats. Try to find:
    # 1. A table with SL columns and size/tier rows
    # 2. Boost types from Labels

    # Find all boost type labels in the template
    all_labels = re.findall(r'\{\{[Ll]abel\|([^}]+)\}\}', wikitext)

    in_table = False
    sl_columns = []
    current_size = None
    current_boost_types = None
    table_series = "normal_omega"  # default for plain tables

    for i, line in enumerate(lines):
        stripped = line.strip()

        if stripped.startswith('{|'):
            in_table = True
        if stripped == '|}':
            in_table = False
            continue

        if not in_table:
            continue

        # Check for series in table title
        if 'colspan' in stripped:
            title_clean = strip_wiki_markup(stripped).lower()
            for key, val in SERIES_MAP.items():
                if key in title_clean:
                    table_series = val
                    break

        # SL columns header
        sl_match = re.match(r'^!\s*(\d+\s*(?:\|\|\s*\d+\s*)*)\s*$', stripped)
        if sl_match:
            sl_columns = [int(x.strip()) for x in re.split(r'\|\|', sl_match.group(1))]

        # Size in header
        for pattern in [r'!\s*(?:style="[^"]*"\s*\|)?\s*(\w[\w\s]*?)(?:<ref|$|\|)']:
            m = re.search(pattern, stripped)
            if m and 'SL' not in stripped and 'Icon' not in stripped and 'HP' not in stripped:
                candidate = m.group(1).strip()
                new_size = normalize_size(candidate)
                if new_size:
                    current_size = new_size

        # Boost type from wsmod-stat or Label
        stat_match = re.search(r'wsmod-stat[^|]*\|\s*(.+)', stripped)
        if stat_match:
            bts = extract_boost_types_from_stat(stat_match.group(1))
            if bts:
                current_boost_types = bts

        # Value row
        if re.match(r'^\|[^|!{]', stripped) and ('||' in stripped or '%' in stripped):
            if sl_columns and current_boost_types:
                values = parse_horizontal_values(stripped.lstrip('|'), sl_columns)
                has_data = any(v is not None for v in values.values())
                if has_data:
                    effective_size = current_size or "big"
                    for bt in current_boost_types:
                        row = make_row(modifier_name, bt, table_series,
                                       effective_size, formula_type, values,
                                       aura_boostable=aura_boostable)
                        rows.append(row)

    return rows


def make_row(modifier, boost_type, series, size, formula_type, values,
             coefficient=None, aura_boostable=False):
    """Create a standardized data row dict."""
    return {
        "modifier": modifier,
        "boost_type": boost_type,
        "series": series,
        "size": size,
        "formula_type": formula_type,
        "sl1": values.get("sl1"),
        "sl10": values.get("sl10"),
        "sl15": values.get("sl15"),
        "sl20": values.get("sl20"),
        "sl25": values.get("sl25"),
        "coefficient": coefficient,
        "aura_boostable": aura_boostable,
    }


def main():
    if not INPUT_PATH.exists():
        print(f"Error: {INPUT_PATH} not found.", file=sys.stderr)
        sys.exit(1)

    with open(INPUT_PATH) as f:
        templates = json.load(f)

    all_rows = []
    stats = {"total": 0, "parsed": 0, "skipped": 0, "transclusion": 0, "text_only": 0, "errors": 0}

    for template_name, wikitext in sorted(templates.items()):
        stats["total"] += 1

        if template_name in SKIP_TEMPLATES:
            stats["skipped"] += 1
            continue

        # Check for transclusion-only templates (no inline data)
        has_transclusion = bool(re.search(r'\{\{Wpn\w+', wikitext))
        has_wsmod = 'wsmod-wrap' in wikitext or 'wsmod-tier' in wikitext
        has_wikitable = 'wikitable' in wikitext

        if template_name in TRANSCLUSION_TEMPLATES and not has_wsmod and not has_wikitable:
            stats["transclusion"] += 1
            continue

        if template_name in TEXT_ONLY_TEMPLATES:
            stats["text_only"] += 1
            continue

        modifier_name, aura_boostable = parse_wsbox(wikitext)
        if not modifier_name:
            modifier_name = template_name

        formula_type = FORMULA_MODIFIERS.get(template_name, "flat")

        try:
            rows = []

            if template_name == "Stamina":
                rows = parse_stamina_coefficients(wikitext, aura_boostable)
            elif template_name == "Garrison":
                rows = parse_garrison_tables(wikitext, aura_boostable)
            elif template_name == "Progression":
                rows = parse_progression(wikitext, modifier_name, aura_boostable)
            elif template_name in ("α Revelation", "β Revelation", "γ Revelation", "Δ Revelation"):
                rows = parse_revelation(wikitext, modifier_name, aura_boostable)
            elif has_wsmod:
                rows = parse_wsmod_tables(wikitext, modifier_name, aura_boostable, formula_type)
            elif has_wikitable:
                rows = parse_plain_wikitable(wikitext, modifier_name, aura_boostable, formula_type)
            else:
                # Check if there's any useful data we're missing
                if '%' in wikitext and '||' in wikitext:
                    print(f"  WARN: {template_name} has data but no recognized table format", file=sys.stderr)
                continue

            if rows:
                all_rows.extend(rows)
                stats["parsed"] += 1
                print(f"  OK: {template_name} -> {len(rows)} rows")
            else:
                print(f"  EMPTY: {template_name} (no extractable values)", file=sys.stderr)

        except Exception as e:
            stats["errors"] += 1
            print(f"  ERROR: {template_name}: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)

    # Deduplicate
    seen = set()
    unique_rows = []
    dupes = 0
    for row in all_rows:
        key = (row["modifier"], row["boost_type"], row["series"], row["size"])
        if key in seen:
            dupes += 1
        else:
            seen.add(key)
            unique_rows.append(row)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, 'w') as f:
        json.dump(unique_rows, f, indent=2)

    print(f"\nDone!")
    print(f"  Total templates: {stats['total']}")
    print(f"  Parsed: {stats['parsed']}")
    print(f"  Skipped: {stats['skipped']} (special mechanics)")
    print(f"  Transclusion: {stats['transclusion']} (data in sub-templates)")
    print(f"  Text-only: {stats['text_only']} (fixed values)")
    print(f"  Errors: {stats['errors']}")
    print(f"  Rows: {len(unique_rows)} unique ({dupes} duplicates removed)")
    print(f"  Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
