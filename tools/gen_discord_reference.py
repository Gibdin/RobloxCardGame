"""Generate the Discord card reference from the game's source files.

The game keeps its in-game text number-free; this reference is where the exact
numbers live for players who want to min-max. Run it after any balance change:

    python tools/gen_discord_reference.py

It reads src/shared/GachaSystem/CardDatabase.lua and CombatConfig.lua and writes
docs/discord/card-reference.md, split into posts that each fit in one Discord
message (2,000-character limit).
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, 'src', 'shared', 'GachaSystem')
OUT = os.path.join(ROOT, 'docs', 'discord', 'card-reference.md')
DISCORD_LIMIT = 1900  # headroom under Discord's 2,000-character message limit

RARITY_ORDER = ['Secret', 'God', 'Mythic', 'Legendary', 'Epic', 'Rare', 'Uncommon', 'Common']


def read(name):
    with open(os.path.join(SHARED, name), encoding='utf-8') as f:
        return f.read()


def block(src, start_marker):
    """Text of a Lua table that starts at `start_marker` (brace-matched)."""
    i = src.index(start_marker)
    j = src.index('{', i)
    depth = 0
    for k in range(j, len(src)):
        if src[k] == '{':
            depth += 1
        elif src[k] == '}':
            depth -= 1
            if depth == 0:
                return src[j:k + 1]
    raise ValueError(start_marker)


def num(text, key):
    m = re.search(r'\b' + re.escape(key) + r'\s*=\s*([\d.]+)', text)
    return float(m.group(1)) if m else None


def pct(x):
    return ('%g' % round(x * 100, 1)) + '%'


# ── combat config ──
cc = read('CombatConfig.lua')
card_stats = block(cc, 'CombatConfig.CardStats')
role_base = {r: (num(block(card_stats, r + ' '), 'atk'), num(block(card_stats, r + ' '), 'hp'))
             for r in ('DPS', 'Tank', 'Support')}
rarity_block = block(card_stats, 'RarityMult')
rarity_mult = {r: num(rarity_block, r) for r in RARITY_ORDER}
sub_block = block(card_stats, 'SubroleMod')
subrole_mod = {}
for name in ('Duelist', 'Skirmisher', 'Vanguard', 'Juggernaut', 'Enchanter', 'Hexer'):
    b = block(sub_block, name)
    subrole_mod[name] = (num(b, 'atk'), num(b, 'hp'))
round_to = num(card_stats, 'RoundTo')
battle = block(cc, 'CombatConfig.Battle')
passives = block(cc, 'CombatConfig.Passives')
counters = block(cc, 'CombatConfig.Counters')
traits = block(cc, 'CombatConfig.Traits')
role_bonus = [float(x) for x in re.findall(r'[\d.]+', block(block(cc, 'CombatConfig.RoleBonuses'), 'DPS'))]


def card_stat(role, rarity, subrole, atk_mod, hp_mod):
    base = role_base[role]
    sm = subrole_mod.get(subrole, (1, 1))
    rm = rarity_mult[rarity]
    r = lambda x: max(round_to, int(x / round_to + 0.5) * round_to)
    return r(base[0] * rm * sm[0] * atk_mod), r(base[1] * rm * sm[1] * hp_mod)


# ── cards ──
db = read('CardDatabase.lua')
cards = []
for m in re.finditer(r'\n\t\{\n\t\tid = (\d+), name = "([^"]+)", rarity = "(\w+)",(.*?)\n\t\},', db, re.S):
    cid, name, rarity, body = int(m.group(1)), m.group(2), m.group(3), m.group(4)
    if 'adminOnly = true' in body:
        continue
    field = lambda k: (re.search(r'\b' + k + r' = "((?:[^"\\]|\\.)*)"', body) or [None, None])[1]
    stat = re.search(r'stat = \{ atk = ([\d.]+), hp = ([\d.]+) \}', body)
    role = field('role')
    sub = field('subrole')
    atk, hp = card_stat(role, rarity, sub, float(stat.group(1)), float(stat.group(2)))
    active = body[body.index('active = {'):]
    cards.append({
        'name': name, 'rarity': rarity, 'role': role, 'subrole': sub,
        'mana': int(re.search(r'mp = (\d+)', body).group(1)), 'atk': atk, 'hp': hp,
        'passive': field('passive'), 'passive_name': field('passive_name'),
        'passive_desc': field('passive_desc'),
        'active_name': re.search(r'name = "([^"]+)"', active).group(1),
        'active_desc': re.search(r'desc = "((?:[^"\\]|\\.)*)"', active).group(1),
    })

# ── build posts ──
posts = []

posts.append('\n'.join([
    '# How battles work',
    '- Teams of up to 5 fight automatically. The frontline is the first living card in line.',
    '- Every round, each card attacks the enemy frontline once. Each hit it lands gives **+1 mana**.',
    '- When a card\'s mana reaches its ability cost (2-5), the ability fires right away. It still attacks as normal.',
    '- Stunned cards skip their attack (and so gain no mana that turn).',
    '- Damage varies by +/-%s. Crits: %s chance, %sx damage.' % (
        pct(1 - num(battle, 'VarianceLo')), pct(num(battle, 'CritChance')), '%g' % num(battle, 'CritMult')),
    '- **Sudden Death:** from round %d, all damage grows by +%s every round, so fights always end.' % (
        num(battle, 'SuddenDeathRound'), pct(num(battle, 'SuddenDeathPerRound'))),
    '- Hard cap: %d rounds. If both teams survive, the team with more total HP %% wins.' % num(battle, 'MaxRounds'),
]))

posts.append('\n'.join([
    '# Roles, counters and team bonuses',
    '**Counter cycle:** Tank > DPS > Support > Tank',
    '- Tanks take %s less damage from DPS.' % pct(num(counters, 'TankVsDPS')),
    '- DPS deal %s more damage to Supports.' % pct(num(counters, 'DPSVsSupport')),
    '- Supports deal %s more damage to Tanks, and their heals/shields/buffs/debuffs are %s stronger while the enemy frontline is a Tank.' % (
        pct(num(counters, 'SupportVsTank')), pct(num(counters, 'SupportEffectVsTankFront'))),
    '- Enemy ATK debuffs can never stack past -%s.' % pct(num(counters, 'HexerAtkDebuffCap')),
    '',
    '**Team role bonus** (per card of the same role: 1 / 2 / 3 / 4 / 5): ' + ' / '.join('+' + pct(x) for x in role_bonus),
    '- DPS: +ATK. Tank: +Max HP. Support: stronger heals, shields, buffs and debuffs.',
    '',
    '**Standard passives**',
    '- Drain: heals %s of damage taken.' % pct(num(block(passives, 'Drain'), 'healPctOfDamageTaken')),
    '- Rage: +%s ATK per hit landed, up to %d stacks.' % (pct(num(block(passives, 'Rage'), 'atkPerStack')), num(block(passives, 'Rage'), 'maxStacks')),
    '- Executioner: +%s damage to targets below %s HP.' % (pct(num(block(passives, 'Executioner'), 'bonusDamage')), pct(num(block(passives, 'Executioner'), 'hpThreshold'))),
    '- Medic: end of every round, heals the lowest-HP ally for %s of their Max HP.' % pct(num(block(passives, 'Medic'), 'healPctLowestAlly')),
    '- Battery: whenever any card dies, allies gain %d mana.' % num(block(passives, 'Battery'), 'manaRestore'),
]))

stat_lines = ['# Card stats formula',
              '**ATK / HP = role base x rarity x subrole x card modifier**, rounded to the nearest %d.' % round_to,
              '- Role base: ' + ', '.join('%s %d / %d' % (r, *role_base[r]) for r in ('DPS', 'Tank', 'Support')),
              '- Rarity: ' + ', '.join('%s x%g' % (r, rarity_mult[r]) for r in reversed(RARITY_ORDER)),
              '- Subrole: ' + ', '.join('%s %gx ATK / %gx HP' % (n, *subrole_mod[n]) for n in subrole_mod)]
posts.append('\n'.join(stat_lines))

def faction_tier(tier_text):
    parts = []
    atk, hp = num(tier_text, 'atkPct'), num(tier_text, 'hpPct')
    if atk:
        parts.append('+%s ATK' % pct(atk))
    if hp:
        parts.append('+%s Max HP' % pct(hp))
    shield = num(tier_text, 'lowHpShieldPct')
    if shield:
        parts.append('the first member to drop below %s HP gets a %s Max HP shield' % (
            pct(num(tier_text, 'lowHpShieldAt')), pct(shield)))
    return ', '.join(parts) + ' (members only)'


faction_lines = ['# Factions (team synergies)']
for fname in ('First Years', 'Best Friends'):
    fb = block(cc, '["%s"]' % fname)
    members = [m.group(1) for m in re.finditer(
        r'id = \d+, name = "([^"]+)".*?series = \{([^}]*)\}', db, re.S) if '"%s"' % fname in m.group(2)]
    faction_lines.append('**%s** - %s' % (fname, ', '.join(members)))
    for t in re.finditer(r'\[(\d+)\] = (\{[^}]*\})', fb):
        faction_lines.append('- %s members: %s' % (t.group(1), faction_tier(t.group(2))))
posts.append('\n'.join(faction_lines))

by_rarity = {}
for c in cards:
    by_rarity.setdefault(c['rarity'], []).append(c)


def card_text(c):
    passive = '**%s:** %s' % (c['passive_name'], c['passive_desc'])
    if c['passive'] == 'Trait':
        passive = 'Trait ' + passive
    else:
        passive = c['passive'] + ' ' + passive
    return '\n'.join([
        '**%s** (%s %s / %s) - %d mana - %d ATK / %d HP' % (
            c['name'], c['rarity'], c['role'], c['subrole'], c['mana'], c['atk'], c['hp']),
        '> ' + passive,
        '> **%s:** %s' % (c['active_name'], c['active_desc']),
    ])


for rarity in RARITY_ORDER:
    group = by_rarity.get(rarity)
    if not group:
        continue
    current = '# %s cards' % rarity
    for c in group:
        text = card_text(c)
        if len(current) + 2 + len(text) > DISCORD_LIMIT:
            posts.append(current)
            current = '# %s cards (cont.)' % rarity
        current += '\n\n' + text
    posts.append(current)

for p in posts:
    assert len(p) <= DISCORD_LIMIT, (len(p), p[:60])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    f.write('<!-- Generated by tools/gen_discord_reference.py. Do not edit by hand. -->\n')
    f.write('<!-- Each section between the "Post N of M" lines is one Discord message (all under 2,000 characters). -->\n\n')
    for i, p in enumerate(posts, 1):
        f.write('<!-- ─── Post %d of %d (%d chars) ─── -->\n\n%s\n\n' % (i, len(posts), len(p), p))
print('wrote %d posts, %d cards -> %s' % (len(posts), len(cards), os.path.relpath(OUT, ROOT)))
