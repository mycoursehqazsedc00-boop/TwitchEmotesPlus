#!/usr/bin/env python3
"""Build the Yahoo Messenger emoticon packs for TwitchEmotes+.

Reads folders of Yahoo emoticon GIFs (numbered 1.gif .. 115.gif; the classic set
also has pirate_2.gif and transformer.gif), converts every GIF into a WoW 1.12
sprite sheet (32-bit uncompressed TGA, power-of-two size) and writes
Data/Yahoo.lua (codes, English names, containers, sheet layout for each style).

    python tools/build_yahoo_pack.py CLASSIC_DIR [ADVANCED_DIR]

  CLASSIC_DIR   the original 18 px emoticon pack      -> Emotes/Yahoo/
  ADVANCED_DIR  the Yahoo Messenger 9.0 beta advanced -> Emotes/YahooAdv/
                pack (22 px, smoother animation); optional. Emoticons the
                advanced pack lacks (:ar! and [..]) keep their classic art.

Requires Pillow. MAPPING below is the single source of truth for code <-> image.
The codes and the visible/hidden split come from a Yahoo emoticon table and a
chart of the hidden emoticons; each GIF was matched to its code by looking at it.
Names are English only.
"""
import math
import os
import sys
from PIL import Image

STYLES = [
    {"name": "classic",  "dir": "Yahoo",    "display_h": 18, "max_cells": 48},
    {"name": "advanced", "dir": "YahooAdv", "display_h": 22, "max_cells": 64},
]
MAX_SHEET_W = 256

# (gif name, code, English name)
MAPPING = [('1', ':)', 'happy'),
 ('2', ':(', 'sad'),
 ('3', ';)', 'winking'),
 ('4', ':D', 'big grin'),
 ('5', ';;)', 'batting eyelashes'),
 ('6', '>:D<', 'big hug'),
 ('7', ':-/', 'confused'),
 ('8', ':x', 'love struck'),
 ('9', ':">', 'blushing'),
 ('10', ':P', 'tongue'),
 ('11', ':-*', 'kiss'),
 ('12', '=((', 'broken heart'),
 ('13', ':-O', 'surprise'),
 ('14', 'X(', 'angry'),
 ('15', ':>', 'smug'),
 ('16', 'B-)', 'cool'),
 ('17', ':-S', 'worried'),
 ('18', '#:-S', 'whew'),
 ('19', '>:)', 'devil'),
 ('20', ':((', 'crying'),
 ('21', ':))', 'laughing'),
 ('22', ':|', 'straight face'),
 ('23', '/:)', 'raised eyebrows'),
 ('24', '=))', 'rolling on the floor'),
 ('25', 'O:-)', 'angel'),
 ('26', ':-B', 'nerd'),
 ('27', '=;', 'talk to the hand'),
 ('28', 'I-)', 'sleepy'),
 ('29', '8-|', 'rolling eyes'),
 ('30', 'L-)', 'loser'),
 ('31', ':-&', 'sick'),
 ('32', ':-$', "don't tell anyone"),
 ('33', '[-(', 'no talking'),
 ('34', ':O)', 'clown'),
 ('35', '8-}', 'silly'),
 ('36', '<:-P', 'party'),
 ('37', '(:|', 'yawn'),
 ('38', '=P~', 'drooling'),
 ('39', ':-?', 'thinking'),
 ('40', '#-o', "d'oh"),
 ('41', '=D>', 'applause'),
 ('42', ':-SS', 'nail biting'),
 ('43', '@-)', 'hypnotized'),
 ('44', ':^o', 'liar'),
 ('45', ':-w', 'waiting'),
 ('46', ':-<', 'sigh'),
 ('47', '>:P', 'phbbbbt'),
 ('48', '<):)', 'cowboy'),
 ('49', ':@)', 'pig'),
 ('50', '3:-O', 'cow'),
 ('51', ':(|)', 'monkey'),
 ('52', '~:>', 'chicken'),
 ('53', '@};-', 'rose'),
 ('54', '%%-', 'good luck'),
 ('55', '**==', 'flag'),
 ('56', '(~~)', 'pumpkin'),
 ('57', '~O)', 'coffee'),
 ('58', '*-:)', 'idea'),
 ('59', '8-X', 'skull'),
 ('60', '=:)', 'bug'),
 ('61', '>-)', 'alien'),
 ('62', ':-L', 'frustrated'),
 ('63', '[-O<', 'praying'),
 ('64', '$-)', 'money eyes'),
 ('65', ':-"', 'whistling'),
 ('66', 'b-(', 'feeling beat up'),
 ('67', ':)>-', 'peace sign'),
 ('68', '[-X', 'shame on you'),
 ('69', '\\:D/', 'dancing'),
 ('70', '>:/', 'bring it on'),
 ('71', ';))', 'hee hee'),
 ('72', 'o->', 'hiro'),
 ('73', 'o=>', 'billy'),
 ('74', 'o-+', 'april'),
 ('75', '(%)', 'yin yang'),
 ('76', ':-@', 'chatterbox'),
 ('77', '^:)^', 'not worthy'),
 ('78', ':-j', 'oh go on'),
 ('79', '(*)', 'star'),
 ('100', ':)]', 'on the phone'),
 ('101', ':-c', 'call me'),
 ('102', '~X(', "at wits' end"),
 ('103', ':-h', 'wave'),
 ('104', ':-t', 'time out'),
 ('105', '8->', 'day dreaming'),
 ('106', ':-??', "i don't know"),
 ('107', '%-(', 'not listening'),
 ('108', ':o3', 'puppy dog eyes'),
 ('109', 'X_X', "i don't want to see"),
 ('110', ':!!', 'hurry up'),
 ('111', '\\m/', 'rock on'),
 ('112', ':-q', 'thumbs down'),
 ('113', ':-bd', 'thumbs up'),
 ('114', '^#(^', "it wasn't me"),
 ('115', ':bz', 'bee'),
 ('pirate_2', ':ar!', 'pirate'),
 ('transformer', '[..]', 'transformer')]

TABLE = [':)',
 ':(',
 ';)',
 ':D',
 ';;)',
 '>:D<',
 ':-/',
 ':x',
 ':">',
 ':P',
 ':-*',
 '=((',
 ':-O',
 'X(',
 ':>',
 'B-)',
 ':-S',
 '#:-S',
 '>:)',
 ':((',
 ':))',
 ':|',
 '/:)',
 '=))',
 'O:-)',
 ':-B',
 '=;',
 ':-c',
 ':)]',
 '~X(',
 ':-h',
 ':-t',
 '8->',
 'I-)',
 '8-|',
 'L-)',
 ':-&',
 ':-$',
 '[-(',
 ':O)',
 '8-}',
 '<:-P',
 '(:|',
 '=P~',
 ':-?',
 '#-o',
 '=D>',
 ':-SS',
 '@-)',
 ':^o',
 ':-w',
 ':-<',
 '>:P',
 '<):)',
 'X_X',
 ':!!',
 '\\m/',
 ':-q',
 ':-bd',
 '^#(^',
 ':ar!']

THEMES = [('Happy and laughing',
  [':)', ';)', ':D', ':>', 'B-)', ':))', '=))', ';))', '\\:D/', '=D>', ':-j', '^:)^', 'O:-)']),
 ('Love and kisses', [';;)', '>:D<', ':x', ':">', ':-*', '=((', ':o3']),
 ('Sad, hurt and sick', [':(', ':((', ':-S', '#:-S', ':-<', 'L-)', ':-&', 'b-(', '[-(', ':-L', '~X(', 'X_X']),
 ('Angry and mischievous', ['X(', '>:)', '>:P', '>:/', '[-X']),
 ('Thinking and doubt',
  [':-/', ':-?', ':-??', '#-o', '@-)', ':^o', ':-w', '8-|', '/:)', ':|', ':-O', ':-$', ':-SS', ':-B', '8->']),
 ('Attitude and reactions', ['=;', '%-(', ':!!', ':-@', '^#(^', 'I-)', '(:|']),
 ('Silly and party', [':P', ':O)', '8-}', '<:-P', '=P~', '$-)', ':-"']),
 ('Characters', ['<):)', 'o->', 'o=>', 'o-+', '[..]', ':ar!']),
 ('Animals and creatures', [':@)', '3:-O', ':(|)', '~:>', '=:)', '>-)', ':bz']),
 ('Objects and symbols', ['@};-', '%%-', '**==', '(~~)', '~O)', '*-:)', '8-X', '(%)', '(*)']),
 ('Hands and gestures', [':-c', ':)]', ':-h', ':-t', '\\m/', ':-q', ':-bd', ':)>-', '[-O<'])]

THEME_OF = {c: name for name, codes in THEMES for c in codes}
_all = [m[1] for m in MAPPING]
assert sorted(THEME_OF) == sorted(_all) and len(THEME_OF) == len(_all) == 97, "every code needs exactly one theme"
assert len(TABLE) == 61 and all(c in _all for c in TABLE), "table list must be 61 known codes"
assert all(m[2] and m[2].isascii() for m in MAPPING), "names must be English (ASCII) only"


def pow2(n):
    p = 1
    while p < n:
        p *= 2
    return p


def slug(s):
    out = "".join(c if c.isalnum() else "_" for c in s.lower())
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


def load_frames(path):
    im = Image.open(path)
    n = getattr(im, "n_frames", 1)
    frames, durs = [], []
    for k in range(n):
        im.seek(k)
        frames.append(im.convert("RGBA").copy())
        durs.append(im.info.get("duration", 0))
    return frames, durs


def plan_cells(durs, max_cells):
    """Return (source frame index per sheet cell, frames per second).

    A sheet plays at one rate, so a frame held longer in the GIF is repeated;
    long holds are capped and the tick coarsened until the sheet fits
    max_cells. A delay of 0 means "default" (100 ms), as in browsers. If even
    one cell per frame is too many, every k-th frame is kept and the rate is
    chosen so the loop keeps its original length.
    """
    durs = [d if d and d > 0 else 100 for d in durs]
    if len(durs) == 1:
        return [0], 1.0
    base = max(40, min(100, min(durs)))
    for mult in (1, 1.25, 1.5, 2, 3, 4):
        tick = base * mult
        for cap in (12, 8, 5, 3, 2, 1):
            cells = []
            for i, d in enumerate(durs):
                cells += [i] * max(1, min(cap, int(round(d / float(tick)))))
            if len(cells) <= max_cells:
                return cells, round(1000.0 / tick, 2)
    k = int(math.ceil(len(durs) / float(max_cells)))
    cells = list(range(0, len(durs), k))
    fps = round(len(cells) / (sum(durs) / 1000.0), 2)
    return cells, max(4.0, min(30.0, fps))


def convert(gif, out_dir, base, style):
    frames, durs = load_frames(gif)
    cells, fps = plan_cells(durs, style["max_cells"])
    fw, fh = frames[0].size
    n = len(cells)
    cols = max(1, min(n, MAX_SHEET_W // fw))
    rows = (n + cols - 1) // cols
    iw, ih = pow2(cols * fw), pow2(rows * fh)
    sheet = Image.new("RGBA", (iw, ih), (0, 0, 0, 0))
    for ci, fi in enumerate(cells):
        sheet.paste(frames[fi], ((ci % cols) * fw, (ci // cols) * fh))
    sheet.save(os.path.join(out_dir, base + ".tga"))  # uncompressed 32-bit
    dw = int(round(style["display_h"] * fw / float(fh)))
    return dict(file=base, fw=fw, fh=fh, iw=iw, ih=ih, n=n, fps=fps, dw=dw)


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def img_lua(d):
    return "{ %s, %d, %d, %d, %d, %d, %s, %d }" % (
        lua_str(d["file"]), d["fw"], d["fh"], d["iw"], d["ih"], d["n"], repr(d["fps"]), d["dw"])


def main(classic_dir, advanced_dir, root):
    dirs = {}
    for st in STYLES:
        dirs[st["name"]] = os.path.join(root, "Emotes", st["dir"])
        os.makedirs(dirs[st["name"]], exist_ok=True)
        for f in os.listdir(dirs[st["name"]]):
            if f.endswith(".tga"):
                os.remove(os.path.join(dirs[st["name"]], f))
    entries = []
    fallback = []
    for gid, code, en in MAPPING:
        base = "ym_%s_%s" % (gid.zfill(3) if gid.isdigit() else gid, slug(en))
        classic_gif = os.path.join(classic_dir, gid + ".gif")
        assert os.path.exists(classic_gif), "classic GIF missing: " + gid
        classic = convert(classic_gif, dirs["classic"], base, STYLES[0])
        advanced = None
        if advanced_dir:
            adv_gif = os.path.join(advanced_dir, gid + ".gif")
            if os.path.exists(adv_gif):
                advanced = convert(adv_gif, dirs["advanced"], base, STYLES[1])
            else:
                fallback.append((gid, code))
        hay = " ".join((code.lower(), en.lower(), THEME_OF[code].lower()))
        entries.append(dict(code=code, en=en, hay=hay, classic=classic, advanced=advanced))

    by_code = {e["code"]: e for e in entries}
    containers = [
        ("Standard list", [by_code[c] for c in TABLE]),
        ("Hidden emoticons", [e for e in entries if e["code"] not in TABLE]),
    ] + [(name, [by_code[c] for c in codes]) for name, codes in THEMES]
    lines = []
    for name, group in containers:
        lines.append("\t{ name = %s, items = {" % lua_str(name))
        for e in group:
            adv = img_lua(e["advanced"]) if e["advanced"] else '"="'
            lines.append("\t\t{ %s, %s, %s, %s, %s }," % (
                lua_str(e["code"]), lua_str(e["en"]), lua_str(e["hay"]), img_lua(e["classic"]), adv))
        lines.append("\t} },")
    with open(os.path.join(root, "Data", "Yahoo.lua"), "w", encoding="utf-8") as fh:
        fh.write(HEADER + "\nlocal CATEGORIES = {\n" + "\n".join(lines) + "\n}\n" + FOOTER)
    for st in STYLES:
        d = dirs[st["name"]]
        total = sum(os.path.getsize(os.path.join(d, f)) for f in os.listdir(d))
        print("%-9s %3d sheets  %5.1f MB" % (st["name"], len(os.listdir(d)), total / 1e6))
    print("emoticons: %d   advanced art missing (classic used): %s" % (len(entries), fallback))


HEADER = '''-- TwitchEmotes+ : Data/Yahoo.lua   (GENERATED by tools/build_yahoo_pack.py - do not edit by hand)
-- Yahoo Messenger's classic emoticons: text code, English name, container, and
-- the sprite-sheet layout of the converted image for each art style.
--
-- Row: { code, name, search text, classic sheet, advanced sheet }
-- Sheet: { file, frameW, frameH, sheetW, sheetH, cells, fps, displayW }
-- An advanced sheet of "=" means "same as classic" (the advanced pack lacks it).
--
-- Art styles: "classic" (18 px) and "advanced" (the Yahoo Messenger 9.0 beta pack,
-- 22 px, smoother animation). SetStyle() switches every item's `img`.
--
-- A Yahoo code that is also a Twitch emote code is removed from the picker and
-- skipped by the chat filter (Twitch emotes take priority).
--
-- Replace or extend with
--   TwitchEmotesPlus.Container:Override("yahooSource", function() ... end)
-- returning { Get = ..., SetStyle = ..., GetStyle = ... }; items need text, label, hay, ascii and img.

local TEP = TwitchEmotesPlus
local C = TEP.Container

local STYLE = {
	classic  = { dir = "Interface\\\\AddOns\\\\TwitchEmotesPlus\\\\Emotes\\\\Yahoo\\\\",    key = "Yahoo",    dh = 18 },
	advanced = { dir = "Interface\\\\AddOns\\\\TwitchEmotesPlus\\\\Emotes\\\\YahooAdv\\\\", key = "YahooAdv", dh = 22 },
}
local current = "advanced"
'''

FOOTER = '''
local function makeImg(style, a)
	local s = STYLE[style]
	local file, fw, fh, iw, ih, n, fps, dw = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8]
	local img = {
		file = file, key = s.key .. "/" .. file, path = s.dir .. file .. ".tga",
		fw = fw, fh = fh, iw = iw, ih = ih, n = n, dw = dw, dh = s.dh,
		l = 0, r = fw / iw, t = 0, b = fh / ih,
	}
	if n > 1 then
		img.anim = { nFrames = n, frameWidth = fw, frameHeight = fh,
		             imageWidth = iw, imageHeight = ih, framerate = fps }
	end
	return img
end

C:Register("yahooSource", function()
	local built
	local all = {}
	local function apply()
		for _, it in ipairs(all) do it.img = it.imgs[current] end
	end
	local function build()
		local out = {}
		for _, cat in ipairs(CATEGORIES) do
			local items = {}
			for _, r in ipairs(cat.items) do
				local imgs = { classic = makeImg("classic", r[4]) }
				imgs.advanced = (r[5] == "=") and imgs.classic or makeImg("advanced", r[5])
				local it = { text = r[1], label = r[2], ascii = true, hay = r[3], imgs = imgs }
				all[#all + 1] = it
				items[#items + 1] = it
			end
			out[#out + 1] = { name = cat.name, items = items }
		end
		apply()
		return out
	end
	return {
		Styles = { "classic", "advanced" },
		Get = function()
			if not built then built = build() end
			return built
		end,
		GetStyle = function() return current end,
		SetStyle = function(name)
			if not STYLE[name] then return false end
			current = name
			apply()
			return true
		end,
	}
end)
'''

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None,
         os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
